require('dotenv').config();
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const { AI_PERSONA, buildContextFromDiaryLogs } = require("./aiPersona");
const { defineTools, executeTool } = require("./tools.js");

// Initialize Firebase Admin
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();

// Initialize Google AI
const googleApiKey = functions.config().google?.api_key || process.env.GOOGLE_API_KEY;
if (!googleApiKey) {
  console.error("FATAL ERROR: Google API key is not configured. Please set GOOGLE_API_KEY in .env or Firebase config.");
}
const genAI = new GoogleGenerativeAI(googleApiKey);

// Define the tools using the new format
const { getMedicationInfoTool, getSupporterInfoTool, searchDrugInfoTool } = defineTools();


// New Agent-based Empathetic Chat Function
// =========================================
exports.getEmpatheticResponse = functions.region("asia-northeast1").https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }
    const userId = context.auth.uid;
    const { userMessage, chatHistory = [] } = data;

    if (!userMessage || typeof userMessage !== "string") {
        throw new functions.https.HttpsError("invalid-argument", "The 'userMessage' field is required and must be a string.");
    }

    functions.logger.log(`[Agent] Starting for user: ${userId}, Message: "${userMessage}"`);

    try {
        let diaryContext = "";
        try {
            const recentLogsSnapshot = await db.collection("users").doc(userId).collection("aiDiaryLogs")
                .orderBy("timestamp", "desc").limit(3).get();
            if (!recentLogsSnapshot.empty) {
                const recentLogs = recentLogsSnapshot.docs.map(doc => doc.data());
                diaryContext = buildContextFromDiaryLogs(recentLogs);
            }
        } catch (error) {
            functions.logger.warn(`[Agent] Failed to fetch recent logs for context:`, error);
        }

        const model = genAI.getGenerativeModel({
            model: "gemini-1.5-flash",
            systemInstruction: `${AI_PERSONA.systemPrompts.empatheticChat}

### 重要な行動ルール
- ユーザーの質問に答えるために、必要であればためらわずにツール（Function Calling）を積極的に使用してください。
- **思考プロセスやツールの使用計画を絶対にユーザーに話してはいけません。**
- ツールを使うと決めたら、まず黙ってツールを実行し、その結果が得られるまで待ってください。
- そして、ツールから得られた情報だけを使って、最終的な応答を一度で生成してください。
- ユーザーから「私の薬について教えて」と尋ねられたら、まず getMedicationInfoTool を呼び出し、その結果を使って回答してください。
- 憶測で答えるのではなく、ツールで得た事実に基づいて応答することが重要です。

${diaryContext}`,
            tools: [getMedicationInfoTool, getSupporterInfoTool, searchDrugInfoTool],
        });

        let sanitizedHistory = chatHistory || [];
        if (sanitizedHistory.length > 0 && sanitizedHistory[0].role === 'model') {
            sanitizedHistory = sanitizedHistory.slice(1);
        }

        const generativeChat = model.startChat({
            history: sanitizedHistory,
            generationConfig: { temperature: 0.8 },
        });

        // Start the conversation loop
        let currentMessage = [{ text: userMessage }];
        const MAX_LOOPS = 5;

        for (let i = 0; i < MAX_LOOPS; i++) {
            functions.logger.log(`[Agent Loop ${i + 1}] Sending message to model.`);
            const result = await generativeChat.sendMessage(currentMessage);
            const response = result.response;
            const functionCalls = response.functionCalls();

            if (functionCalls && functionCalls.length > 0) {
                functions.logger.log(`[Agent Loop ${i + 1}] Function call(s) requested:`, JSON.stringify(functionCalls));
                
                const toolExecutionPromises = functionCalls.map(call => executeTool(call, userId));
                const toolResults = await Promise.all(toolExecutionPromises);
                functions.logger.log(`[Agent Loop ${i + 1}] Tool execution results:`, JSON.stringify(toolResults));

                currentMessage = toolResults.map(toolResult => ({
                    functionResponse: {
                        name: toolResult.toolCall.name,
                        response: toolResult.result,
                    }
                }));
            } else {
                const aiResponseText = response.text();
                functions.logger.log(`[Agent Loop ${i + 1}] Final response from AI:`, aiResponseText);
                return { aiResponse: aiResponseText };
            }
        }

        functions.logger.warn(`[Agent] Reached max loop count for user ${userId}. Returning fallback response.`);
        return { aiResponse: "うーん、ちょっと考え込んじゃったワン。もう一度、少し違う聞き方で質問してくれる？" };

    } catch (error) {
        functions.logger.error(`[Agent] Error in getEmpatheticResponse for user ${userId}:`, error);
        if (error.message && error.message.includes('SAFETY')) {
             return { aiResponse: "ごめんねワン...そのお話はちょっと難しいみたいだワン。他の話題でお話ししようワン！" };
        }
        throw new functions.https.HttpsError("internal", "An error occurred while getting a response.", error.message);
    }
});

// ALL OTHER EXISTING FUNCTIONS
// ============================

// Note: The original `getEmpatheticResponse` is now replaced by the Genkit flow above.
// All other functions are preserved below.

exports.generateAnalysisMessages = functions.region("asia-northeast1")
    .firestore.document("users/{userId}/aiDiaryLogs/{logId}")
    .onCreate(async (snap, context) => {
    functions.logger.log("--- generateAnalysisMessages START (diary trigger) ---");
    
    const userId = context.params.userId;
    const logId = context.params.logId;
    functions.logger.log(`Analysis triggered by new diary log: ${logId} for user: ${userId}`);

    try {
        await db.collection('users').doc(userId)
            .collection('analysisMessages').doc('messages')
            .set({ isUpdating: true, lastUpdated: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });

        const periods = [
            { name: 'daily', days: 30, description: '過去30日間' },
            { name: 'weekly', days: 84, description: '過去12週間' },
            { name: 'monthly', days: 365, description: '過去12ヶ月' }
        ];
        
        const analysisPromises = periods.map(period => generatePeriodAnalysis(userId, period));
        const results = await Promise.allSettled(analysisPromises);
        
        const analysisMessages = {};
        results.forEach((result, index) => {
            const periodName = periods[index].name;
            if (result.status === 'fulfilled' && result.value) {
                analysisMessages[`${periodName}Message`] = result.value;
            } else {
                analysisMessages[`${periodName}Message`] = "日記を書いて、あなたのことをもっと教えてね！";
            }
        });
        
        await db.collection("users").doc(userId).collection("analysisMessages").doc("messages").set({
            ...analysisMessages,
            isUpdating: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        functions.logger.log("--- generateAnalysisMessages END (Success) ---");
        return null;

    } catch (error) {
        functions.logger.error(`Error in generateAnalysisMessages for user ${userId}:`, error);
        await db.collection("users").doc(userId).collection("analysisMessages").doc("messages").set({
            dailyMessage: "日記を書いて、あなたのことをもっと教えてね！",
            weeklyMessage: "日記を書いて、あなたのことをもっと教えてね！",
            monthlyMessage: "日記を書いて、あなたのことをもっと教えてね！",
            isUpdating: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return null;
    }
});

async function generatePeriodAnalysis(userId, period) {
    try {
        functions.logger.log(`Generating ${period.name} analysis for user: ${userId}`);
        
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - period.days);
        
        const logsSnapshot = await db
            .collection("users")
            .doc(userId)
            .collection("aiDiaryLogs")
            .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(startDate))
            .orderBy("timestamp", "desc")
            .get();
        
        if (logsSnapshot.empty) {
            functions.logger.log(`No logs found for ${period.name} analysis`);
            return "まだ分析に必要なデータが集まっていません。日記を書いてみましょう！";
        }
        
        const logs = [];
        let totalPositive = 0;
        let totalNeutral = 0;
        let totalNegative = 0;
        const keywords = [];
        
        logsSnapshot.forEach(doc => {
            const data = doc.data();
            const moodScore = data.overallMoodScore || data.selfReportedMoodScore || 3;
            
            logs.push({
                date: data.timestamp.toDate().toISOString().split('T')[0],
                moodScore: moodScore,
                diaryText: data.diaryText || ""
            });
            
            if (moodScore >= 4) totalPositive++;
            else if (moodScore >= 3) totalNeutral++;
            else totalNegative++;
            
            if (data.diaryText) {
                const text = data.diaryText;
                if (text.includes("嬉しい") || text.includes("楽しい") || text.includes("良い")) keywords.push("楽しい");
                if (text.includes("仕事") || text.includes("働")) keywords.push("仕事");
                if (text.includes("散歩") || text.includes("歩")) keywords.push("散歩");
                if (text.includes("疲れ") || text.includes("つかれ")) keywords.push("疲れた");
                if (text.includes("美味しい") || text.includes("おいしい")) keywords.push("美味しい");
            }
        });
        
        const today = new Date().toISOString().split("T")[0];
        const summary = {
            period: period.description,
            positive_days: totalPositive,
            neutral_days: totalNeutral,
            negative_days: totalNegative,
            top_keywords: [...new Set(keywords)].slice(0, 5)
        };
        
        const systemPrompt = `${AI_PERSONA.systemPrompts.mindForecast}\n\n重要：応答は100文字以内のテキスト形式のメッセージのみを返してください。JSON形式ではありません。分析期間（「${period.description}」など）を自然に文章に含めてください。`;
        
        const userPrompt = `これは、あるユーザーの${period.description}の日記データです。\n\nデータ要約:\n- ポジティブな日: ${summary.positive_days}日\n- 普通の日: ${summary.neutral_days}日\n- ネガティブな日: ${summary.negative_days}日\n- よく出るキーワード: ${summary.top_keywords.join("、")}\n\nこのデータから、ユーザーの気分の主な傾向を分析し、ユーザーを励ますような、温かいメッセージを100文字以内で生成してください。分析期間を文章に含めてください。`;
        
        const googleApiKey = functions.config().google?.api_key || process.env.GOOGLE_API_KEY;
        if (!googleApiKey) {
            throw new Error("Google API key is not configured");
        }
        
        const genAI = new GoogleGenerativeAI(googleApiKey);
        const model = genAI.getGenerativeModel({
            model: "gemini-2.5-flash",
            systemInstruction: systemPrompt,
        });
        
        const result = await model.generateContent({
            contents: [{ role: "user", parts: [{ text: userPrompt }] }]
        });
        
        const response = result.response;
        if (response?.candidates?.[0]?.content?.parts?.[0]?.text) {
            const message = response.candidates[0].content.parts[0].text.trim();
            const finalMessage = message.length > 100 ? message.substring(0, 97) + "..." : message;
            functions.logger.log(`Generated ${period.name} message: ${finalMessage}`);
            return finalMessage;
        } else {
            throw new Error(`Invalid AI response for ${period.name}`);
        }
        
    } catch (error) {
        functions.logger.error(`Error generating ${period.name} analysis:`, error);
        return "今はココロンがちょっと考え中...また後で覗いてみてワン！";
    }
}

exports.getPartnerChatAdvice = functions.region("asia-northeast1")
    .https.onCall(async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
      }
      const userId = context.auth.uid;
      const userMessage = data.userMessage;
      const chatHistory = data.chatHistory || [];

      if (!userMessage || typeof userMessage !== "string" || userMessage.trim() === "") {
        throw new functions.https.HttpsError("invalid-argument", "User message is required and must be a non-empty string.");
      }
      functions.logger.log(`Partner chat advice requested by user: ${userId}`, {userMessage: userMessage, historyLength: chatHistory.length});

      const systemPrompt = "あなたは、精神疾患を持つ方のパートナーを親身にサポートするAIチャット相談員です。ユーザー（パートナー）からの連続した対話形式での相談に対し、共感的かつ実践的なアドバイスを提供してください。会話の流れを汲み取り、具体的で分かりやすい言葉で、パートナーが前向きになれるような応答を心がけてください。時には具体的な行動を提案したり、気持ちの整理を手伝ったりすることも重要です。ただし、医学的な診断や治療法に関する断定的な指示は避け、必要に応じて専門家への相談を促すことも忘れないでください。あなたの応答は、常に温かく、相手に寄り添うものであるべきです。";

      const contents = [];
      chatHistory.forEach((msg) => {
        if (msg.role && msg.parts) {
          contents.push({role: msg.role, parts: msg.parts});
        }
      });
      contents.push({role: "user", parts: [{text: userMessage}]});

      try {
        const googleApiKey = functions.config().google?.api_key || process.env.GOOGLE_API_KEY;
        if (!googleApiKey) {
          throw new Error("Google AI API key is not configured");
        }
        
        const genAI = new GoogleGenerativeAI(googleApiKey);
        const model = genAI.getGenerativeModel({
          model: "gemini-2.5-flash",
          systemInstruction: systemPrompt,
        });

        let aiResponseText = "";
        try {
          const resp = await model.generateContent({contents, generationConfig: {temperature: 0.7}});
          if (resp?.response?.candidates?.[0]?.content?.parts?.[0]?.text) {
            aiResponseText = resp.response.candidates[0].content.parts[0].text;
          } else {
            functions.logger.warn("Invalid or empty response structure from Google AI for partner chat advice. Full response:", JSON.stringify(resp));
            throw new Error("AIからのパートナーチャットアドバイスが無効か空です。");
          }
          functions.logger.log("Partner chat advice response from Google AI:", aiResponseText);
        } catch (aiError) {
          functions.logger.error("Error calling Google AI for partner chat advice:", aiError);
          aiResponseText = "申し訳ありません、現在AIチャットアドバイスを提供できません。少し時間をおいて再度お試しください。";
        }

        return {aiResponse: aiResponseText};
      } catch (error) {
        functions.logger.error("Error in getPartnerChatAdvice function for user", userId, ":", error);
        throw new functions.https.HttpsError("internal", "An error occurred while fetching partner chat advice.", error.message);
      }
    });

exports.suggestSelfCareAction = functions.region("asia-northeast1")
    .firestore.document("users/{userId}/aiDiaryLogs/{logId}") // ★ Updated path
    .onCreate(async (snap, context) => {
      const newLog = snap.data();
      const userId = context.params.userId;
      const logId = context.params.logId;

      functions.logger.log(`New AI Diary Log [${logId}] for user [${userId}] for self-care suggestion:`, newLog);

      const moodLevel = newLog.selfReportedMoodScore; // ★ Updated field name
      if (moodLevel > 2) {
        functions.logger.log(`Mood level ${moodLevel} is not considered negative enough for a self-care suggestion.`);
        return null;
      }

      functions.logger.log(`Negative mood (level ${moodLevel}) detected. Generating self-care suggestion.`);
      let userContextInfo = "";
      if (newLog.diaryText && newLog.diaryText.trim() !== "") {
        userContextInfo = `ユーザーの日記には「${newLog.diaryText.substring(0, 100)}」と書かれています。`;
      }

      const prompt = `ユーザーは気分が「${moodLevel}」(1が最も悪く5が最も良い)と記録しました。${userContextInfo}このユーザーに、具体的ですぐに実行でき、短いポジティブなセルフケア行動を一つ提案してください。提案は簡潔に50文字以内でお願いします。例：温かい飲み物で一息つきませんか？`;
      functions.logger.log("Generated prompt for self-care suggestion:", prompt);

      try {
        const googleApiKey = functions.config().google?.api_key || process.env.GOOGLE_API_KEY;
        if (!googleApiKey) {
          throw new Error("Google AI API key is not configured");
        }
        
        const genAI = new GoogleGenerativeAI(googleApiKey);
        const generativeModel = genAI.getGenerativeModel({model: "gemini-2.5-flash"});

        let suggestionTextFromAI = "";
        try {
          const resp = await generativeModel.generateContent(prompt);
          if (resp?.response?.candidates?.[0]?.content?.parts?.[0]?.text) {
            suggestionTextFromAI = resp.response.candidates[0].content.parts[0].text;
          } else {
            functions.logger.warn("Invalid or empty response structure from Google AI for self-care. Full response:", JSON.stringify(resp));
            throw new Error("AIからのセルフケア提案が無効か空です。");
          }
          functions.logger.log("Self-care suggestion from Google AI:", suggestionTextFromAI);
        } catch (aiError) {
          functions.logger.error("Error calling Google AI for self-care suggestion:", aiError);
          suggestionTextFromAI = "温かい飲み物で一息つきませんか？"; // Fallback suggestion
        }

        try {
          const userDocSnap = await db.collection("users").doc(userId).get(); // Renamed to userDocSnap
          if (!userDocSnap.exists) {
            throw new Error("User document not found for FCM token");
          }
          const fcmToken = userDocSnap.data().fcmToken; // Used userDocSnap
          if (!fcmToken) {
            throw new Error("FCM token not found for user");
          }
          functions.logger.log(`FCM token for user ${userId}: ${fcmToken}`);
          const message = {
            notification: {title: "セルフケアのご提案🌿", body: suggestionTextFromAI},
            token: fcmToken,
            android: {notification: {channel_id: "self_care_suggestions"}},
            apns: {payload: {aps: {sound: "default", category: "SELF_CARE_SUGGESTION"}}},
          };

          const response = await admin.messaging().send(message);
          functions.logger.log("Successfully sent self-care message:", response, "to user:", userId);
          await db.collection("users").doc(userId).collection("selfCareSuggestions").add({
            originalLogId: logId, moodLevel: moodLevel, suggestion: suggestionTextFromAI,
            isPushSent: true, pushMessageId: response,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (fcmError) {
          functions.logger.error("Error sending self-care message via FCM:", fcmError, "for user:", userId);
          await db.collection("users").doc(userId).collection("selfCareSuggestions").add({
            originalLogId: logId, moodLevel: moodLevel, suggestion: suggestionTextFromAI,
            isPushSent: false, error: fcmError.message,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        return null;
      } catch (error) {
        functions.logger.error("Error in suggestSelfCareAction function for user", userId, ":", error);
        return null;
      }
    });

exports.getCommunicationAdvice = functions.region("asia-northeast1")
    .https.onCall(async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
      }
      const userId = context.auth.uid;
      const situation = data.situation;
      const partnerQuery = data.partnerQuery;

      if (!situation || typeof situation !== "string" || situation.trim() === "") {
        throw new functions.https.HttpsError("invalid-argument", "Required field 'situation' is missing or not a non-empty string.");
      }
      if (partnerQuery && typeof partnerQuery !== "string") {
        throw new functions.https.HttpsError("invalid-argument", "Optional field 'partnerQuery' must be a string if provided.");
      }

      functions.logger.log(`Communication advice requested by partner user: ${userId}`, {situation: situation, query: partnerQuery});

      const systemPrompt = "あなたは、精神疾患を持つ方のパートナーを親身にサポートするAIチャット相談員です。ユーザー（パートナー）からの連続した対話形式での相談に対し、共感的かつ実践的なアドバイスを提供してください。会話の流れを汲み取り、具体的で分かりやすい言葉で、パートナーが前向きになれるような応答を心がけてください。時には具体的な行動を提案したり、気持ちの整理を手伝ったりすることも重要です。ただし、医学的な診断や治療法に関する断定的な指示は避け、必要に応じて専門家への相談を促すことも忘れないでください。あなたの応答は、常に温かく、相手に寄り添うものであるべきです。";

      const contents = [];
      chatHistory.forEach((msg) => {
        if (msg.role && msg.parts) {
          contents.push({role: msg.role, parts: msg.parts});
        }
      });
      contents.push({role: "user", parts: [{text: userMessage}]});

      try {
        const googleApiKey = functions.config().google?.api_key || process.env.GOOGLE_API_KEY;
        if (!googleApiKey) {
          throw new Error("Google AI API key is not configured");
        }
        
        const genAI = new GoogleGenerativeAI(googleApiKey);
        const generativeModel = genAI.getGenerativeModel({model: "gemini-2.5-flash"});
        const request = {
          contents: [{role: "user", parts: [{text: userPrompt}]}],
          systemInstruction: systemPrompt,
        };

        let aiRawResponse = "";
        try {
          const resp = await generativeModel.generateContent(request);
          if (resp?.response?.candidates?.[0]?.content?.parts?.[0]?.text) {
            aiRawResponse = resp.response.candidates[0].content.parts[0].text;
          } else {
            functions.logger.warn("Invalid or empty response structure from Vertex AI for communication advice. Full response:", JSON.stringify(resp));
            throw new Error("AIからのコミュニケーションアドバイスが無効か空です。");
          }
          functions.logger.log("Raw communication advice from Vertex AI:", aiRawResponse);
        } catch (aiError) {
          functions.logger.error("Error calling Vertex AI for communication advice:", aiError);
          return {
            adviceText: "申し訳ありません、現在AIによるアドバイスを提供できません。一般的な情報源を参考にするか、専門家にご相ください。",
            examplePhrases: [],
          };
        }

        let adviceText = "アドバイスが見つかりませんでした。";
        let examplePhrases = [];
        const adviceMatch = aiRawResponse.match(/アドバイス：([\s\S]*?)会話例・行動提案：/);
        const examplesMatch = aiRawResponse.match(/会話例・行動提案：([\s\S]*)/);

        if (adviceMatch && adviceMatch[1]) {
          adviceText = adviceMatch[1].trim();
        } else {
          const adviceOnlyMatch = aiRawResponse.match(/アドバイス：([\s\S]*)/);
          if (adviceOnlyMatch && adviceOnlyMatch[1]) {
            adviceText = adviceOnlyMatch[1].trim();
          } else if (!examplesMatch) { // If no examples, the whole response might be advice
            adviceText = aiRawResponse.trim();
          }
        }

        if (examplesMatch && examplesMatch[1]) {
          const examplesString = examplesMatch[1].trim();
          examplePhrases = examplesString.split("\n")
              .map((line) => line.trim())
              .filter((line) => line.startsWith("- "))
              .map((line) => line.substring(2).trim())
              .filter((phrase) => phrase.length > 0);
        }
        // Fallback if parsing failed but response exists
        if (adviceText === "アドバイスが見つかりませんでした。" && aiRawResponse.length > 0 && !aiRawResponse.startsWith("申し訳ありません")) {
          adviceText = aiRawResponse;
        }

        functions.logger.log("Parsed Communication Advice:", {adviceText, examplePhrases});

        return {adviceText: adviceText, examplePhrases: examplePhrases};
      } catch (error) {
        functions.logger.error("Error in getCommunicationAdvice function for partner user", userId, ":", error);
        throw new functions.https.HttpsError("internal", "An error occurred while fetching communication advice.", error.message);
      }
    });

exports.analyzeAiDiaryLog = functions.region("asia-northeast1")
    .firestore.document("users/{userId}/aiDiaryLogs/{logId}")
    .onCreate(async (snap, context) => {
      const logData = snap.data();
      const userId = context.params.userId;
      const logId = context.params.logId;

      functions.logger.log(`New AI Diary Log [${logId}] for user [${userId}]. Data:`, logData);

      if (logData.aiComment !== undefined && logData.overallMoodScore !== undefined) {
           functions.logger.log(`Log [${logId}] seems to have been processed already. Skipping.`);
           return null;
      }

      const selfReportedMoodScore = logData.selfReportedMoodScore;
      const diaryText = logData.diaryText;

      let aiAnalyzedPositivityScore = null;
      let aiComment = null;
      let overallMoodScore = parseFloat(selfReportedMoodScore.toFixed(2));

      if (diaryText && diaryText.trim() !== "") {
        try {
          const googleApiKey = process.env.GOOGLE_API_KEY || functions.config().google?.api_key;
          if (!googleApiKey) {
            throw new Error("Google AI API key is not configured");
          }
          const genAI = new GoogleGenerativeAI(googleApiKey);
          const generativeModel = genAI.getGenerativeModel({model: "gemini-2.5-flash"});

          const positivityPrompt = `以下の日記の内容を分析し、その感情的なポジティブ度を0.0（非常にネガティブ）から1.0（非常にポジティブ）の間の数値でスコアリングしてください。数値のみを返してください。\n\n日記：\n「${diaryText}」`;
          functions.logger.log("Positivity prompt for Vertex AI:", positivityPrompt);
          try {
            const positivityResp = await generativeModel.generateContent({
              contents: [{ role: "user", parts: [{ text: positivityPrompt }] }],
              systemInstruction: { parts: [{ text: AI_PERSONA.systemPrompts.positivityScore }] },
            });
            if (positivityResp?.response?.candidates?.[0]?.content?.parts?.[0]?.text) {
              const scoreText = positivityResp.response.candidates[0].content.parts[0].text.trim();
              const score = parseFloat(scoreText);
              if (!isNaN(score) && score >= 0.0 && score <= 1.0) {
                aiAnalyzedPositivityScore = parseFloat(score.toFixed(2));
                functions.logger.log("AI Positivity Score:", aiAnalyzedPositivityScore);
              } else {
                functions.logger.warn("Failed to parse positivity score or score out of range:", scoreText);
              }
            } else {
               functions.logger.warn("Invalid or empty response structure from Vertex AI for positivity. Full response:", JSON.stringify(positivityResp));
            }
          } catch (e) {
            functions.logger.error("Error getting positivity score from Vertex AI:", e);
          }

          const commentPrompt = `以下の日記の内容を読み、評価や批判をせず、ただユーザーに寄り添い、感情を認めるような短い（50～100字程度）AIからの優しい感想コメントを生成してください。\n例：「今日はそんなことがあったのですね。つらい気持ちを書き出してくれてありがとうございます」\n\n日記：\n「${diaryText}」`;
          functions.logger.log("Comment prompt for Vertex AI:", commentPrompt);
          try {
            const commentResp = await generativeModel.generateContent({
              contents: [{ role: "user", parts: [{ text: commentPrompt }] }],
              systemInstruction: { parts: [{ text: AI_PERSONA.systemPrompts.diaryComment }] },
            });
            if (commentResp?.response?.candidates?.[0]?.content?.parts?.[0]?.text) {
              aiComment = commentResp.response.candidates[0].content.parts[0].text.trim();
              functions.logger.log("AI Comment:", aiComment);
            } else {
               functions.logger.warn("Invalid or empty response structure from Vertex AI for comment. Full response:", JSON.stringify(commentResp));
            }
          } catch (e) {
            functions.logger.error("Error getting comment from Vertex AI:", e);
          }

          if (aiAnalyzedPositivityScore !== null) {
            const scaledAiScore = (aiAnalyzedPositivityScore * 4) + 1;
            overallMoodScore = (selfReportedMoodScore + scaledAiScore) / 2;
            overallMoodScore = Math.max(1.0, Math.min(5.0, overallMoodScore));
            overallMoodScore = parseFloat(overallMoodScore.toFixed(2));
            functions.logger.log("Calculated Overall Mood Score:", overallMoodScore);
          } else {
            functions.logger.log("AI Positivity Score not available, Overall Mood Score defaults to Self-Reported:", overallMoodScore);
          }
        } catch (aiError) {
          functions.logger.error("Error initializing Google AI or during AI processing:", aiError);
        }
      } else {
        functions.logger.log("Diary text is empty. Skipping AI analysis. Overall score will be self-reported score.");
      }

      const updateData = {};
      if (aiAnalyzedPositivityScore !== null) updateData.aiAnalyzedPositivityScore = aiAnalyzedPositivityScore;
      if (aiComment !== null) updateData.aiComment = aiComment;
      // Only update overallMoodScore if it changed OR if AI analysis was attempted (even if it defaulted)
      if (overallMoodScore !== parseFloat(selfReportedMoodScore.toFixed(2)) || aiAnalyzedPositivityScore !== null) {
          updateData.overallMoodScore = overallMoodScore;
      }

      if (Object.keys(updateData).length > 0) {
        updateData.lastUpdatedByFunction = admin.firestore.FieldValue.serverTimestamp();
        try {
          await snap.ref.update(updateData);
          functions.logger.log(`Successfully updated AiDiaryLog [${logId}] for user [${userId}] with AI insights:`, updateData);
        } catch (updateError) {
          functions.logger.error(`Error updating AiDiaryLog [${logId}] for user [${userId}]:`, updateError);
        }
      } else {
        functions.logger.log(`No new AI insights to update for AiDiaryLog [${logId}].`);
      }
      return null;
    });

exports.generatePersonalInsight = functions.region("asia-northeast1")
    .https.onCall(async (data, context) => {
      // 1. Authentication Check
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "The function must be called while authenticated.",
        );
      }
      const userId = context.auth.uid;
      functions.logger.log(`Personal insight generation requested for user: ${userId}`);

      // Optional: Input validation for data (e.g., specific date range if provided)
      // const { startDate, endDate } = data; // Example if client can specify range

      try {
        // 2. Fetch Diary Logs
        const insightPeriodDays = 30; // Example: 30 days
        const minLogCount = 10;     // Example: 10 logs minimum

        const periodEndDate = new Date();
        const periodStartDate = new Date();
        periodStartDate.setDate(periodEndDate.getDate() - insightPeriodDays);

        const diaryLogsSnapshot = await db
            .collection("users")
            .doc(userId)
            .collection("aiDiaryLogs")
            .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(periodStartDate))
            .where("timestamp", "<=", admin.firestore.Timestamp.fromDate(periodEndDate))
            .orderBy("timestamp", "desc")
            .get();

        if (diaryLogsSnapshot.empty || diaryLogsSnapshot.size < minLogCount) {
          functions.logger.log(
              `Not enough diary logs (${diaryLogsSnapshot.size}) found for user ${userId} in the last ${insightPeriodDays} days. Minimum ${minLogCount} required.`,
          );
          return {
            success: false,
            message: "分析に必要な日記ログの数が不足しています。",
            insightId: null,
          };
        }

        const diaryLogs = [];
        diaryLogsSnapshot.forEach((doc) => {
          const log = doc.data();
          diaryLogs.push({
            date: log.timestamp.toDate().toISOString().split("T")[0],
            moodScore: log.overallMoodScore !== undefined ? log.overallMoodScore : log.selfReportedMoodScore,
            diaryText: log.diaryText ? log.diaryText.substring(0, 300) : "", // Truncate for prompt
          });
        });
        functions.logger.log(`Fetched ${diaryLogs.length} diary logs for insight generation.`);

        // 3. Generate AI Prompt
        let logsConcatenated = "";
        diaryLogs.forEach((log) => {
          logsConcatenated += `- ${log.date} (気分: ${log.moodScore}/5): ${log.diaryText}\n`;
        });
        
        const aiPrompt = `あなたはユーザーのメンタルヘルスジャーニーをサポートする、洞察力に優れたAIアシスタントです。\n提供された以下のユーザーの日記ログ（過去約${insightPeriodDays}日分）を分析し、ユーザーが自分自身をより深く理解し、ポジティブな気持ちになれるような「パーソナルな気づき」を生成してください。\n\n# 分析対象の日記ログ:\n${logsConcatenated}\n\n# 指示:\n1.  **気づきの要約 (summaryText):**\n    ログ全体を通して見られるユーザーの気分の傾向、特徴的なパターン、または重要な感情の動きについて、1つか2つの最も重要な「気づき」を、150字以内の優しい言葉で記述してください。\n    例: 「最近の日記からは、自然の中で過ごす時間があなたの心に良い影響を与えているようですね。特に週末にそのような時間を持つと、週明けの気分も安定する傾向が見られるかもしれません。」\n\n2.  **キー観察ポイント (keyObservations):**\n    上記の「気づきの要約」を裏付ける、具体的な観察結果やログからの引用（もしあれば短い引用）を3つ、箇条書きで記述してください。各ポイントは100字以内でお願いします。\n    例:\n    - 「『公園を散歩した』『リフレッシュできた』など、自然に関するポジティブな記述が複数見られます。」\n    - 「週末に気分スコアが平均的に高く、特に日曜日に活動的な日は月曜のスコアも良い傾向があります。」\n    - 「一方で、仕事のプレッシャーを感じた日は、睡眠の質にも影響が出ている可能性が示唆されています。」\n\n3.  **ポジティブなアファメーション (positiveAffirmation):**\n    ユーザーを励まし、自己肯定感を高めるような、70字以内の短い前向きなメッセージを生成してください。\n    例: 「あなたは自分自身の気持ちに正直に向き合っていますね。その一つ一つの感情が、あなたを形作る大切な一部です。」\n\n# 出力形式:\n必ず以下のJSON形式で、キー名も指示通りに返してください。\n{\n  "summaryText": "ここに「気づきの要約」を記述",\n  "keyObservations": [\n    "ここに1つ目の「キー観察ポイント」を記述",\n    "ここに2つ目の「キー観察ポイント」を記述",\n    "ここに3つ目の「キー観察ポイント」を記述"\n  ],\n  "positiveAffirmation": "ここに「ポジティブなアファメーション」を記述"\n}\n\n# 注意事項:\n- 常にユーザーに寄り添い、共感的で、非批判的な言葉を選んでください。\n- 断定的な表現や医学的な診断と誤解されるような表現は避けてください。「～のようです」「～かもしれませんね」「～傾向が見られます」といった、可能性を示唆する言葉遣いを心がけてください。\n- 生成する内容は、ユーザーが提供したログデータのみに基づいてください。\n`;
        functions.logger.log("Generated AI prompt for personal insight for user:", userId);

        // 4. Call Vertex AI (Gemini)
        const genAI = new GoogleGenerativeAI(googleApiKey);
        const generativeModel = genAI.getGenerativeModel({model: "gemini-2.5-flash"});

        let aiResponseJson = null;
        try {
          const resp = await generativeModel.generateContent({
            contents: [{ role: "user", parts: [{ text: aiPrompt }] }],
            systemInstruction: { parts: [{ text: AI_PERSONA.systemPrompts.personalInsight }] },
          });
          if (resp?.response?.candidates?.[0]?.content?.parts?.[0]?.text) {
            const rawResponse = resp.response.candidates[0].content.parts[0].text;
            functions.logger.log("Raw response from Vertex AI for personal insight:", rawResponse);
             try {
                // Strip markdown code block fences if they exist
                const cleanedResponse = rawResponse.trim().replace(/^```json\n|```$/g, '');
                aiResponseJson = JSON.parse(cleanedResponse);
             } catch (parseError) {
                functions.logger.error("Failed to parse AI response as JSON:", parseError, "Raw response:", rawResponse);
                throw new Error("AIからの応答をJSONとして解析できませんでした。");
             }
          } else {
            functions.logger.warn("Invalid or empty response structure from Vertex AI for personal insight. Full response:", JSON.stringify(resp));
            throw new Error("AIからの応答が無効か空です。");
          }
        } catch (aiError) {
          functions.logger.error("Error calling Vertex AI for personal insight:", aiError);
          throw new functions.https.HttpsError(
              "internal",
              "AIによる気づきの生成中にエラーが発生しました。",
              aiError.message,
          );
        }

        if (!aiResponseJson || !aiResponseJson.summaryText || !aiResponseJson.keyObservations || !aiResponseJson.positiveAffirmation) {
             functions.logger.error("AI response JSON is missing required fields. Parsed JSON:", aiResponseJson);
             throw new Error("AIの応答に必要なフィールドが含まれていません。");
        }
        
        // 5. Save Insight to Firestore
        const newInsightRef = db.collection("users").doc(userId).collection("personalInsights").doc();
        const insightData = {
          insightId: newInsightRef.id,
          userId: userId,
          generatedDate: admin.firestore.FieldValue.serverTimestamp(),
          periodCoveredStart: admin.firestore.Timestamp.fromDate(periodStartDate),
          periodCoveredEnd: admin.firestore.Timestamp.fromDate(periodEndDate),
          summaryText: aiResponseJson.summaryText,
          keyObservations: aiResponseJson.keyObservations,
          positiveAffirmation: aiResponseJson.positiveAffirmation,
          rawAIResponse: aiResponseJson, 
        };

        await newInsightRef.set(insightData);
        functions.logger.log(`Personal insight [${newInsightRef.id}] saved for user ${userId}.`);

        // 6. Send FCM Notification
        try {
          const userDocSnap = await db.collection("users").doc(userId).get();
          if (userDocSnap.exists && userDocSnap.data().fcmToken) {
            const fcmToken = userDocSnap.data().fcmToken;
            const message = {
              notification: {
                title: "ココロの振り返り🌿",
                body: "新しい「パーソナルな気づき」が届きました。あなたのパターンを見てみましょう。",
              },
              token: fcmToken,
              data: { // Optional data payload for client-side handling (e.g., navigation)
                type: "personal_insight",
                insightId: newInsightRef.id,
              },
              android: {
                notification: {
                  channel_id: "personal_insights_channel", // Ensure this channel is created on the client
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    category: "PERSONAL_INSIGHT_CATEGORY", 
                  },
                },
              },
            };
            await admin.messaging().send(message);
            functions.logger.log(`Successfully sent personal insight notification to user ${userId}`);
          } else {
            functions.logger.warn(`FCM token not found for user ${userId}. Cannot send insight notification.`);
          }
        } catch (fcmError) {
          functions.logger.error(`Error sending personal insight FCM notification to user ${userId}:`, fcmError);
          // Do not throw an error here to allow the main function to return success for insight generation
        }

        // 7. Return success response
        return {
          success: true,
          message: "パーソナルな気づきが生成されました。",
          insightId: newInsightRef.id,
          insight: insightData, 
        };
      } catch (error) {
        functions.logger.error(`Error in generatePersonalInsight for user ${userId}:`, error);
        if (error instanceof functions.https.HttpsError) {
          throw error; // Re-throw HttpsError directly
        }
        throw new functions.https.HttpsError(
            "internal",
            "パーソナルな気づきの生成中に予期せぬエラーが発生しました。",
            error.message,
        );
      }
    });

exports.sendMedicationReminders = functions.region("asia-northeast1")
    .pubsub.topic("medication-reminders") 
    .onPublish(async (message) => {
      functions.logger.log("Executing sendMedicationReminders due to Pub/Sub trigger.");

      const now = new Date(); 
      const currentMinutesSinceMidnight = now.getUTCHours() * 60 + now.getUTCMinutes();
      const reminderWindowMinutes = 5; 

      try {
        const usersSnapshot = await db.collection("users").get();
        if (usersSnapshot.empty) {
          functions.logger.log("No users found.");
          return null;
        }

        const promises = [];

        for (const userDoc of usersSnapshot.docs) {
          const userId = userDoc.id;
          const userData = userDoc.data();
          const fcmToken = userData.fcmToken;

          if (!fcmToken) {
            functions.logger.log(`User ${userId} has no FCM token. Skipping.`);
            continue;
          }

          const medicationsSnapshot = await db
              .collection("users")
              .doc(userId)
              .collection("medications")
              .where("reminderEnabled", "==", true)
              .get();

          if (medicationsSnapshot.empty) {
            continue;
          }

          medicationsSnapshot.forEach((medDoc) => {
            const medication = medDoc.data();
            const medId = medDoc.id;

            if (!medication.name || !medication.times || !Array.isArray(medication.times) || medication.times.length === 0) {
              functions.logger.warn(`Medication ${medId} for user ${userId} has invalid name or 'times' field. Skipping.`);
              return; 
            }

            medication.times.forEach((timeStr) => { 
              const timeParts = timeStr.split(":");
              if (timeParts.length !== 2) {
                functions.logger.warn(`Invalid time format "${timeStr}" for med ${medId}, user ${userId}. Skipping.`);
                return; 
              }
              const medicationHour = parseInt(timeParts[0], 10);
              const medicationMinute = parseInt(timeParts[1], 10);

              if (isNaN(medicationHour) || isNaN(medicationMinute) || medicationHour < 0 || medicationHour > 23 || medicationMinute < 0 || medicationMinute > 59) {
                functions.logger.warn(`Could not parse time or time out of range "${timeStr}" for med ${medId}, user ${userId}. Skipping.`);
                return; 
              }
              
              const medicationTimeInMinutesUTC = medicationHour * 60 + medicationMinute;

              if (
                medicationTimeInMinutesUTC >= currentMinutesSinceMidnight &&
                medicationTimeInMinutesUTC < currentMinutesSinceMidnight + reminderWindowMinutes
              ) {
                functions.logger.log(`Medication ${medication.name} (ID: ${medId}) for user ${userId} is due at ${timeStr} (UTC). Current server time (UTC minutes): ${currentMinutesSinceMidnight}, Med time (UTC minutes): ${medicationTimeInMinutesUTC}`);
                
                const scheduledIntakeDate = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), medicationHour, medicationMinute, 0, 0));
                const scheduledIntakeTimestamp = admin.firestore.Timestamp.fromDate(scheduledIntakeDate);

                const p = (async () => {
                  const logsQuery = await db.collection("users").doc(userId).collection("medicationLogs")
                      .where("medicationId", "==", medId)
                      .where("scheduledIntakeTime", "==", scheduledIntakeTimestamp)
                      .limit(1)
                      .get();

                  let logDoc = null;
                  let logData = null;
                  if (!logsQuery.empty) {
                    logDoc = logsQuery.docs[0];
                    logData = logDoc.data();
                  }

                  if (logData && (logData.status === "taken" || logData.status === "skipped")) {
                    functions.logger.log(`User ${userId} already logged medication ${medication.name} for ${timeStr} as ${logData.status}. No reminder needed.`);
                    return;
                  }
                  if (logData && logData.reminderSentAt) {
                    functions.logger.log(`Reminder for ${medication.name} at ${timeStr} for user ${userId} already sent at ${logData.reminderSentAt.toDate().toISOString()}. Skipping.`);
                    return;
                  }

                  const fcmMessage = {
                    notification: {
                      title: `お薬の時間です - ${medication.name}`,
                      body: `「${medication.name}」の服用時間になりました。忘れずに服用しましょう。`,
                    },
                    token: fcmToken,
                    data: {
                      type: "medication_reminder",
                      medicationId: medId,
                      medicationName: medication.name,
                      scheduledAt: scheduledIntakeTimestamp.toDate().toISOString(),
                    },
                    android: {
                      notification: {
                        channel_id: "medication_reminders_channel",
                        sound: "default",
                      },
                    },
                    apns: {
                      payload: {
                        aps: {
                          sound: "default",
                          category: "MEDICATION_REMINDER_CATEGORY", 
                        },
                      },
                    },
                  };

                  try {
                    await admin.messaging().send(fcmMessage);
                    functions.logger.log(`Successfully sent reminder for ${medication.name} to user ${userId} for time ${timeStr}.`);
                    
                    const reminderSentTimestampFirestore = admin.firestore.FieldValue.serverTimestamp();
                    
                    if (logDoc) { 
                       await logDoc.ref.update({ reminderSentAt: reminderSentTimestampFirestore, status: "pending_reminder_sent" });
                    } else { 
                       await db.collection("users").doc(userId).collection("medicationLogs").add({
                           userId: userId,
                           medicationId: medId,
                           medicationName: medication.name,
                           medicationForm: medication.form || null,
                           dosage: medication.dosage || null, 
                           scheduledIntakeTime: scheduledIntakeTimestamp,
                           actualIntakeTime: null,
                           status: "pending_reminder_sent", 
                           notes: "リマインダー自動送信済み",
                           loggedAt: admin.firestore.FieldValue.serverTimestamp(),
                           reminderSentAt: reminderSentTimestampFirestore,
                       });
                    }
                  } catch (error) {
                    functions.logger.error("Error sending FCM for medication reminder:", error, "User:", userId, "Med:", medication.name);
                  }
                })();
                promises.push(p);
              }
            });
          });
        }

        await Promise.all(promises);
        functions.logger.log("Finished processing medication reminders for all users.");
        return null;
      } catch (error) {
        functions.logger.error("Error in sendMedicationReminders function:", error);
        return null; 
      }
    });

exports.helloWorld = functions.region("asia-northeast1")
    .https.onCall((data, context) => {
    functions.logger.log("--- helloWorld Test Function START ---");
    functions.logger.log("helloWorld context:", context);
    if (context.auth && context.auth.token) {
        functions.logger.log("helloWorld auth UID:", context.auth.uid);
        functions.logger.log("helloWorld auth token details:", {
            uid: context.auth.token.uid,
            email: context.auth.token.email,
            firebase_provider: context.auth.token.firebase?.sign_in_provider,
        });
        functions.logger.log("--- helloWorld Test Function END ---");
        return { message: `Hello ${context.auth.uid}, your email is ${context.auth.token.email}` };
    } else {
        functions.logger.log("helloWorld: No auth context. Throwing unauthenticated.");
        functions.logger.log("--- helloWorld Test Function END ---");
        throw new functions.https.HttpsError(
            "unauthenticated",
            "The helloWorld function must be called while authenticated."
        );
    }
});

exports.generateEmpatheticCommentAndRecord = functions
  .region("asia-northeast1")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "この機能を利用するには認証が必要です。"
      );
    }

    const userId = context.auth.uid;
    const { selfReportedMoodScore, diaryText, selectedEvents, sleepDurationHours, weatherData } = data;

    if (
      typeof selfReportedMoodScore !== "number" ||
      selfReportedMoodScore < 1 ||
      selfReportedMoodScore > 5
    ) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "selfReportedMoodScore は1から5の数値である必要があります。"
      );
    }
    if (diaryText !== null && typeof diaryText !== "string") {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "diaryText は文字列またはnullである必要があります。"
        );
    }

    let aiComment = null;

    if (diaryText && diaryText.trim() !== "") {
      functions.logger.log(`Generating AI comment for diaryText: "${diaryText}"`);
      
      const systemPrompt = AI_PERSONA.systemPrompts.diaryComment;
      
      let contextInfo = "";
      try {
        const recentLogsSnapshot = await db.collection("users").doc(userId).collection("aiDiaryLogs")
          .orderBy("timestamp", "desc")
          .limit(3)
          .get();
        
        if (!recentLogsSnapshot.empty) {
          const recentLogs = [];
          recentLogsSnapshot.forEach(doc => {
            const data = doc.data();
            if (data.timestamp) {
              recentLogs.push({
                date: data.timestamp.toDate().toISOString().split("T")[0],
                moodScore: data.overallMoodScore || data.selfReportedMoodScore,
                diaryText: data.diaryText,
                selectedEvents: data.selectedEvents
              });
            }
          });
          contextInfo = buildContextFromDiaryLogs(recentLogs);
        }
      } catch (error) {
        functions.logger.warn("Failed to fetch recent logs for context:", error);
      }
      
      const prompt = `\n        以下の日記に対して、ココロン（相棒のワンちゃん）として優しくコメントしてください。\n        ${contextInfo}\n        \n        今日の日記:\n        「${diaryText}」\n        ${selectedEvents && selectedEvents.length > 0 ? `今日したこと: ${selectedEvents.join("、")}` : ""}\n        ${sleepDurationHours ? `睡眠時間: ${sleepDurationHours}時間` : ""}\n\n        ココロンのコメント:\n      `;

      try {
        const googleApiKey = functions.config().google?.api_key || process.env.GOOGLE_API_KEY;
        if (!googleApiKey) {
          throw new Error("Google API key is not configured");
        }
        const genAI = new GoogleGenerativeAI(googleApiKey);
        const generativeModel = genAI.getGenerativeModel({
          model: "gemini-2.5-flash", 
        });

        const resp = await generativeModel.generateContent({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          systemInstruction: { parts: [{ text: systemPrompt }] },
        });

        if (
          resp.response &&
          resp.response.candidates &&
          resp.response.candidates.length > 0 &&
          resp.response.candidates[0].content &&
          resp.response.candidates[0].content.parts &&
          resp.response.candidates[0].content.parts.length > 0 &&
          resp.response.candidates[0].content.parts[0].text
        ) {
          aiComment = resp.response.candidates[0].content.parts[0].text.trim();
          functions.logger.log("Generated AI comment:", aiComment);
        } else {
          functions.logger.warn("AI comment generation returned no content, proceeding without AI comment.", resp.response);
        }
      } catch (error) {
        functions.logger.error("Error calling Gemini API, proceeding without AI comment:", error);
      }
    } else {
      functions.logger.log("No diary text provided, skipping AI comment generation.");
    }

    const newLogEntry = {
      userId: userId,
      selfReportedMoodScore: selfReportedMoodScore,
      diaryText: diaryText || null, 
      aiComment: aiComment, 
      selectedEvents: selectedEvents || [], 
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      overallMoodScore: selfReportedMoodScore, 
      aiAnalyzedPositivityScore: null, 
    };

    if (sleepDurationHours !== undefined && sleepDurationHours !== null) {
      newLogEntry.sleepDurationHours = sleepDurationHours;
      functions.logger.log(`Sleep duration recorded: ${sleepDurationHours} hours`);
    }

    if (weatherData !== undefined && weatherData !== null) {
      newLogEntry.weatherData = weatherData;
      functions.logger.log(`Weather data recorded:`, weatherData);
    }

    try {
      const docRef = await db
        .collection("users")
        .doc(userId)
        .collection("aiDiaryLogs")
        .add(newLogEntry);
      
      functions.logger.log("Diary log successfully recorded with ID:", docRef.id);
      
      updateMentalHintsInBackground(userId).catch(error => {
        functions.logger.error("Background mental hints update failed:", error);
      });
      
      return {
        success: true,
        logId: docRef.id,
        aiComment: aiComment,
      };
    } catch (error) {
      functions.logger.error("Error recording diary log to Firestore:", error);
      throw new functions.https.HttpsError(
        "internal",
        "日記の記録中にエラーが発生しました。"
      );
    }
  });

exports.getMentalHints = functions
  .region("asia-northeast1")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "この機能を利用するには認証が必要です。"
      );
    }

    const requesterId = context.auth.uid;
    const targetUserId = data.userId || requesterId;

    // If a supporter is requesting data for another user, verify permissions
    if (requesterId !== targetUserId) {
      try {
        const linkSnapshot = await db.collection('supporterLinks')
          .where('userId', '==', targetUserId)
          .where('supporterId', '==', requesterId)
          .where('status', '==', 'accepted')
          .limit(1)
          .get();

        if (linkSnapshot.empty) {
          throw new functions.https.HttpsError('permission-denied', 'あなたはこのユーザーのサポーターとして登録されていません。');
        }

        const linkData = linkSnapshot.docs[0].data();
        if (linkData.permissions?.canViewMentalHints !== true) {
          throw new functions.https.HttpsError('permission-denied', 'あなたにはこのユーザーの「心のヒント」を閲覧する権限がありません。');
        }
      } catch (error) {
        functions.logger.error(`Permission check failed for requester ${requesterId} on target ${targetUserId}:`, error);
        if (error instanceof functions.https.HttpsError) {
          throw error;
        }
        throw new functions.https.HttpsError('permission-denied', '権限の確認中にエラーが発生しました。');
      }
    }
    
    try {
      functions.logger.log(`Mental hints requested by ${requesterId} for user: ${targetUserId}`);
      
      const hintsDoc = await db
        .collection("users")
        .doc(targetUserId)
        .collection("mentalHints")
        .doc("current")
        .get();
      
      if (hintsDoc.exists) {
        const hintsData = hintsDoc.data();
        functions.logger.log(`Retrieved mental hints from Firestore for user ${targetUserId}`);
        return {
          hints: hintsData.hints || [],
          message: hintsData.message,
          analyzedPeriod: hintsData.analyzedPeriod,
          totalLogs: hintsData.totalLogs,
          updatedAt: hintsData.updatedAt
        };
      } else {
        functions.logger.log(`No mental hints found for user ${targetUserId}, triggering background update`);
        
        if (requesterId === targetUserId) {
            updateMentalHintsInBackground(targetUserId).catch(error => {
              functions.logger.error("Background mental hints update failed:", error);
            });
        }
        
        return {
          hints: [],
          message: "心のヒントを準備中です。しばらくお待ちください。",
          analyzedPeriod: {
            start: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
            end: new Date().toISOString()
          },
          totalLogs: 0
        };
      }
      
    } catch (error) {
      functions.logger.error(`Error in getMentalHints for user ${targetUserId}:`, error);
      throw new functions.https.HttpsError(
        "internal",
        "心のヒントの取得中にエラーが発生しました。",
        error.message
      );
    }
  });

async function updateMentalHintsInBackground(userId) {
  try {
    functions.logger.log(`Background mental hints update started for user: ${userId}`);
    
    await db.collection('users').doc(userId)
        .collection('mentalHints').doc('current')
        .set({ isUpdating: true, lastUpdated: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });

    functions.logger.log(`Mental hints loading state set for user: ${userId}`);
    
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const logsSnapshot = await db
      .collection("users")
      .doc(userId)
      .collection("aiDiaryLogs")
      .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .orderBy("timestamp", "desc")
      .get();
    
    if (logsSnapshot.empty) {
      functions.logger.log(`No diary logs found for user ${userId} in the last 30 days`);
      await saveMentalHints(userId, [], "まだ分析に必要なデータが集まっていません。", 0);
      return;
    }

    const logs = [];
    logsSnapshot.forEach(doc => {
      const data = doc.data();
      logs.push({
        date: data.timestamp.toDate(),
        moodScore: data.selfReportedMoodScore || 3,
        events: data.selectedEvents || [],
        diaryText: data.diaryText || "",
        sleepDurationHours: data.sleepDurationHours || null,
        weather: data.weatherData ? {
          description: data.weatherData.description,
          temperature: data.weatherData.temperatureCelsius,
          pressure: data.weatherData.pressureHPa,
          humidity: data.weatherData.humidity
        } : null
      });
    });

    functions.logger.log(`Found ${logs.length} diary logs for background analysis`);

    const systemPrompt = AI_PERSONA.systemPrompts.mentalHints + `\n\n分析結果は以下のJSON形式で最大5つのヒントを返してください：\n{\n  "hints": [\n    {\n      "title": "ヒントのタイトル（例：お散歩と気分の関係だワン）",\n      "content": "具体的な内容（例：お散歩した日は気分スコアが平均で+1.5ポイント高いみたいだワン！）",\n      "icon": "関連する絵文字1つ",\n      "type": "positive/warning/neutral"\n    }\n  ]\n}`;

    const dataForAnalysis = logs.map(log => ({
      date: log.date.toISOString().split('T')[0],
      moodScore: log.moodScore,
      events: log.events,
      diaryPreview: log.diaryText.substring(0, 100),
      sleepHours: log.sleepDurationHours,
      weather: log.weather
    }));

    const prompt = `以下のユーザーの日記データを分析し、行動・睡眠・天気と気分の関係についての具体的なヒントを生成してください。\n\nデータ：\n${JSON.stringify(dataForAnalysis, null, 2)}\n\n注意事項：\n- イベント名は日本語で記載されています\n- 気分スコアは1（最低）から5（最高）の5段階評価です\n- sleepHours は睡眠時間（時間単位、null の場合はデータなし）\n- weather は天気データ（null の場合はデータなし）\n- 統計的に有意な傾向や繰り返しパターンを見つけてください\n- 睡眠時間、天気条件、行動の組み合わせによる気分への影響を分析してください\n- ユーザーが実際に生活習慣を改善できるような具体的なアドバイスを含めてください\n- 活動や行動を言及する時は必ず日本語で表現してください（例：「よく眠れた日」「散歩」「運動」など）\n- 英語のイベント名（good_sleep, exerciseなど）は使用しないでください\n- 文章はシンプルで分かりやすく、読みやすいものにしてください\n- 「しっぽブンブン」「ワンワン」などの過度な犬の表現は控えめにしてください\n- データに基づいた客観的な分析結果を中心に伝えてください`;

    const googleApiKey = process.env.GOOGLE_API_KEY || functions.config().google?.api_key;
    if (!googleApiKey) {
      throw new Error("Google AI API key is not configured");
    }
    
    functions.logger.log(`Attempting to call Gemini API with ${logs.length} logs for mental hints analysis`);
    
    const genAI = new GoogleGenerativeAI(googleApiKey);
    const model = genAI.getGenerativeModel({
      model: "gemini-2.5-flash",
      systemInstruction: systemPrompt,
    });

    const resp = await model.generateContent(prompt);
    functions.logger.log("Gemini API call completed for mental hints");

    let hints = [];
    
    if (resp?.response?.text) {
      const rawResponse = resp.response.text();
      functions.logger.log("Raw AI response for background mental hints:", rawResponse);
      
      try {
        let jsonString = '';
        const jsonMatch = rawResponse.match(/```json\s*([\s\S]*?)\s*```/);
        if (jsonMatch) {
          jsonString = jsonMatch[1].trim();
        } else {
          const jsonStartIndex = rawResponse.indexOf('{');
          const jsonEndIndex = rawResponse.lastIndexOf('}');
          if (jsonStartIndex !== -1 && jsonEndIndex !== -1 && jsonEndIndex > jsonStartIndex) {
            jsonString = rawResponse.substring(jsonStartIndex, jsonEndIndex + 1);
          } else {
            throw new Error("No valid JSON found in response");
          }
        }
        
        functions.logger.log("Extracted JSON string:", jsonString);
        const parsedResponse = JSON.parse(jsonString);
        hints = parsedResponse.hints || [];
        
        functions.logger.log(`Successfully parsed ${hints.length} mental hints in background`);
      } catch (parseError) {
        functions.logger.error("Failed to parse AI response as JSON in background:", parseError);
        functions.logger.error("Original response that failed to parse:", rawResponse);
        hints = [{
          title: "データ分析中",
          content: "現在、あなたの気分パターンを分析しています。もう少しデータが集まると、より具体的なアドバイスを提供できます。",
          icon: "🔍",
          type: "neutral",
          events: []
        }];
      }
    }

    await saveMentalHints(userId, hints, null, logs.length);
    
    functions.logger.log(`Background mental hints update completed for user: ${userId}`);
    
  } catch (error) {
    functions.logger.error(`Error in background mental hints update for user ${userId}:`, error);
    
    try {
      const fallbackHints = [{
        title: "データ分析エラー",
        content: "心のヒントの分析中に問題が発生しました。しばらく時間をおいて再度お試しください。",
        icon: "⚠️",
        type: "warning",
        events: []
      }];
      
      await saveMentalHints(userId, fallbackHints, "分析中にエラーが発生しました。", 0);
      functions.logger.log(`Fallback mental hints saved for user: ${userId}`);
    } catch (fallbackError) {
      functions.logger.error(`Failed to save fallback mental hints for user ${userId}:`, fallbackError);
    }
    
    return;
  }
}

async function saveMentalHints(userId, hints, message, totalLogs) {
  const hintsData = {
    hints: hints,
    message: message,
    analyzedPeriod: {
      start: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
      end: new Date().toISOString()
    },
    totalLogs: totalLogs,
    isUpdating: false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db
    .collection("users")
    .doc(userId)
    .collection("mentalHints")
    .doc("current")
    .set(hintsData, { merge: false }); 

  functions.logger.log(`Mental hints saved for user ${userId}`);
}

exports.onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const userId = user.uid;
  functions.logger.log(`User account deleted, cleaning up data for user: ${userId}`);

  const userDocRef = db.collection("users").doc(userId);

  const batch = db.batch();

  async function deleteCollection(collectionRef, batch) {
    const snapshot = await collectionRef.get();
    if (snapshot.size === 0) {
      return;
    }
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
  }

  const subcollections = [
    "aiDiaryLogs",
    "analysisMessages",
    "medicationLogs",
    "medications",
    "personalInsights",
    "selfCareSuggestions",
    "supporterLinks",
    "supporterInvitations",
    "mentalHints"
  ];

  for (const subcollection of subcollections) {
    const collectionRef = userDocRef.collection(subcollection);
    await deleteCollection(collectionRef, batch);
  }

  batch.delete(userDocRef);

  try {
    await batch.commit();
    functions.logger.log(`Successfully cleaned up all data for deleted user: ${userId}`);
  } catch (error) {
    functions.logger.error(`Error cleaning up data for deleted user ${userId}:`, error);
  }
});