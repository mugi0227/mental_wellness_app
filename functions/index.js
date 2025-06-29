require('dotenv').config();
const functions = require("firebase-functions"); // Added a comment to force redeploy
const admin = require("firebase-admin");
const {GoogleGenerativeAI} = require("@google/generative-ai");
const {AI_PERSONA, buildContextFromDiaryLogs} = require("./aiPersona");

/**
 * このファイルはFirebase Genkitを使用してCloud Functionを定義します。
 * 必要なパッケージ:
 * npm install firebase-functions firebase-admin genkit @genkit-ai/googleai @genkit-ai/firebase zod
 */

//const { defineFlow, run } = require("genkit");
//const { onFlow } = require("@genkit-ai/firebase/functions");
//const { gemini15Flash } = require("@genkit-ai/googleai"); // Genkit推奨のモデルインポート
//const { z } = require("zod");
//const admin = require("firebase-admin");

// Genkitの設定ファイルを読み込みます (プロジェクトルートにgenkit.jsがあると仮定)
//require("./genkit.js");


admin.initializeApp();
const db = admin.firestore();

// Firebase Admin SDKの初期化
/** 
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();

// フローの入力データ型をZodで定義
const MindForecastInputSchema = z.object({
    sleepDurationHours: z.number().optional(),
    currentWeather: z.object({
        description: z.string().optional(),
        temperatureCelsius: z.number().optional(),
        pressurehPa: z.number().optional(),
    }).optional(),
});

// フローの出力データ型をZodで定義
const MindForecastOutputSchema = z.object({
    text: z.string(),
    emoji: z.string(),
    advice: z.string(),
});*/

/**
 * ユーザーの最近の気分ログに基づいて「ココロの天気予報」を生成します。
 * Genkitのフローとして定義され、Firebase Callable Functionとしてデプロイされます。
 */
/** exports.generateMindForecast = onFlow(
    {
        name: "generateMindForecast",
        inputSchema: MindForecastInputSchema,
        outputSchema: MindForecastOutputSchema,
        authPolicy: (auth, input) => {
            // 認証されていないユーザーからの呼び出しをここで弾きます。
            if (!auth) {
                throw new Error("The function must be called while authenticated.");
            }
        },
    },
    async (data, { auth }) => {
        console.log("--- generateMindForecast START (Genkit) ---");

        const userId = auth.uid;
        const { sleepDurationHours, currentWeather } = data;
        console.log(`generateMindForecast for user: ${userId}`, { sleepDurationHours, currentWeather });

        // 1. Firestoreから直近7件の日記ログを取得
        const logsSnapshot = await db.collection("users").doc(userId).collection("aiDiaryLogs")
            .orderBy("timestamp", "desc")
            .limit(7)
            .get();

        if (logsSnapshot.empty) {
            console.log(`No diary logs found for user ${userId} for forecast.`);
            return {
                text: "記録がまだありません。日記を書いてみましょう。",
                emoji: "✏️",
                advice: "あなたの最初の記録をお待ちしています。"
            };
        }

        // 2. AIへのプロンプト用にログを整形
        const logsForPrompt = [];
        logsSnapshot.forEach(doc => {
            const log = doc.data();
            const logEntry = {
                date: log.timestamp.toDate().toISOString().split("T")[0],
                overallMoodScore: log.overallMoodScore !== undefined ? log.overallMoodScore : log.selfReportedMoodScore,
                diaryTextSnippet: log.diaryText ? log.diaryText.substring(0, 100) : ""
            };
            logsForPrompt.push(logEntry);
        });
        logsForPrompt.reverse(); // 時系列順（古い→新しい）に並べ替え

        console.log(`Fetched ${logsForPrompt.length} logs for prompt generation.`);

        // 3. プロンプト本体の組み立て
        const today = new Date().toISOString().split("T")[0]; // 今日の日付（YYYY-MM-DD形式）
        let promptLogSummary = `今日の日付: ${today}\\n\\n直近の記録：\\n`;
        logsForPrompt.forEach(log => {
            promptLogSummary += `日付: ${log.date}, 気分スコア: ${log.overallMoodScore}/5 ${log.diaryTextSnippet ? ", 日記抜粋: 「" + log.diaryTextSnippet + "」" : ""}\\n`;
        });

        let contextText = "";
        if (currentWeather && currentWeather.description) {
            contextText += `今日の天気は「${currentWeather.description}」`;
            if (currentWeather.temperatureCelsius !== undefined) {
                contextText += `、気温は約${currentWeather.temperatureCelsius}度`;
            }
            if (currentWeather.pressurehPa !== undefined) {
                contextText += `、気圧は約${currentWeather.pressurehPa}hPa`;
            }
            contextText += "です。";
        }
        if (sleepDurationHours !== undefined) {
            contextText += ` 昨晩の睡眠時間は約${sleepDurationHours}時間でした。`;
        }
        if (contextText) {
            promptLogSummary += `\\n現在の状況: ${contextText}\\n`;
        }

        // ココロンのペルソナを使用
        const systemPrompt = AI_PERSONA.systemPrompts.mindForecast;
        const userPrompt = `${promptLogSummary}\\n上記の記録と状況を踏まえ、今日のココロの天気予報とアドバイスをJSON形式で生成してください。`;

        console.log("Generated prompt for mind forecast for user:", userId);

        // 4. Genkitを使ってGeminiモデルを呼び出す
        const llmResponse = await run("call-gemini-for-forecast", async () => {
            return await gemini15Flash.generate({
                system: systemPrompt,
                prompt: userPrompt,
                config: {
                    // AIにJSON形式で出力するように指示
                    responseMimeType: "application/json",
                },
            });
        });

        // 5. AIからのレスポンスをパースして返す
        try {
            const forecastResponse = llmResponse.json();
            // 返ってきたJSONに必要なキーが含まれているかチェック
            if (!forecastResponse.text || !forecastResponse.emoji || !forecastResponse.advice) {
                console.warn("AI response JSON is missing required fields. Response:", llmResponse.text());
                throw new Error("AI response missing required fields.");
            }
            console.log("--- generateMindForecast END (Success) ---");
            return forecastResponse;
        } catch (parseError) {
            console.error("Failed to parse AI response as JSON:", parseError, "Raw response:", llmResponse.text());
            // パースに失敗した場合は、固定のフォールバックメッセージを返す
            return {
                text: "AI応答の解析に失敗しました。",
                emoji: "⚙️",
                advice: "開発者にご連絡ください。"
            };
        }
    }
);




/**
 * 日記更新時に自動実行される分析メッセージ生成関数
 * 要件仕様に基づき、日別・週別・月別の3期間の分析を実行
 */
exports.generateAnalysisMessages = functions.region("asia-northeast1")
    .firestore.document("users/{userId}/aiDiaryLogs/{logId}")
    .onCreate(async (snap, context) => {
    functions.logger.log("--- generateAnalysisMessages START (diary trigger) ---");
    
    const userId = context.params.userId;
    const logId = context.params.logId;
    functions.logger.log(`Analysis triggered by new diary log: ${logId} for user: ${userId}`);

    try {
        // 分析開始の状態をFirestoreに保存
        await db.collection('users').doc(userId)
            .collection('analysisMessages').doc('messages')
            .set({
                isUpdating: true,
                lastUpdated: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });

        functions.logger.log(`Analysis loading state set for user: ${userId}`);

        // 3期間（日別・週別・月別）の分析を並行実行
        const periods = [
            { name: 'daily', days: 30, description: '過去30日間' },
            { name: 'weekly', days: 84, description: '過去12週間' }, // 12週 = 84日
            { name: 'monthly', days: 365, description: '過去12ヶ月' } // 12ヶ月 = 365日
        ];
        
        const analysisPromises = periods.map(period => 
            generatePeriodAnalysis(userId, period)
        );
        
        const results = await Promise.allSettled(analysisPromises);
        
        // 結果を統合してFirestoreに保存
        const analysisMessages = {};
        results.forEach((result, index) => {
            const periodName = periods[index].name;
            if (result.status === 'fulfilled' && result.value) {
                analysisMessages[`${periodName}Message`] = result.value;
            } else {
                functions.logger.error(`Failed to generate ${periodName} analysis:`, result.reason);
                analysisMessages[`${periodName}Message`] = "日記を書いて、あなたのことをもっと教えてね！";
            }
        });
        
        // 要件仕様のパスに保存: users/{userId}/analysisMessages/messages
        await db.collection("users").doc(userId).collection("analysisMessages").doc("messages").set({
            ...analysisMessages,
            isUpdating: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        functions.logger.log(`Analysis messages saved for user ${userId}:`, analysisMessages);
        functions.logger.log("--- generateAnalysisMessages END (Success) ---");
        
        return null; // Firestore trigger function

    } catch (error) {
        functions.logger.error(`Error in generateAnalysisMessages for user ${userId}:`, error);
        
        // エラー時も最低限のメッセージを保存
        try {
            await db.collection("users").doc(userId).collection("analysisMessages").doc("messages").set({
                dailyMessage: "日記を書いて、あなたのことをもっと教えてね！",
                weeklyMessage: "日記を書いて、あなたのことをもっと教えてね！",
                monthlyMessage: "日記を書いて、あなたのことをもっと教えてね！",
                isUpdating: false,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        } catch (saveError) {
            functions.logger.error("Failed to save fallback messages:", saveError);
        }
        
        return null;
    }
});

// 期間別分析を実行する関数
async function generatePeriodAnalysis(userId, period) {
    try {
        functions.logger.log(`Generating ${period.name} analysis for user: ${userId}`);
        
        // 期間に応じたデータ取得
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
        
        // データを集計
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
            
            // 気分分類
            if (moodScore >= 4) totalPositive++;
            else if (moodScore >= 3) totalNeutral++;
            else totalNegative++;
            
            // キーワード抽出（簡易版）
            if (data.diaryText) {
                const text = data.diaryText;
                if (text.includes("嬉しい") || text.includes("楽しい") || text.includes("良い")) keywords.push("楽しい");
                if (text.includes("仕事") || text.includes("働")) keywords.push("仕事");
                if (text.includes("散歩") || text.includes("歩")) keywords.push("散歩");
                if (text.includes("疲れ") || text.includes("つかれ")) keywords.push("疲れた");
                if (text.includes("美味しい") || text.includes("おいしい")) keywords.push("美味しい");
            }
        });
        
        // 要件仕様のプロンプト構築
        const today = new Date().toISOString().split("T")[0];
        const summary = {
            period: period.description,
            positive_days: totalPositive,
            neutral_days: totalNeutral,
            negative_days: totalNegative,
            top_keywords: [...new Set(keywords)].slice(0, 5)
        };
        
        // ココロンのペルソナ使用
        const systemPrompt = `${AI_PERSONA.systemPrompts.mindForecast}

重要：応答は100文字以内のテキスト形式のメッセージのみを返してください。JSON形式ではありません。分析期間（「${period.description}」など）を自然に文章に含めてください。`;
        
        const userPrompt = `これは、あるユーザーの${period.description}の日記データです。

データ要約:
- ポジティブな日: ${summary.positive_days}日
- 普通の日: ${summary.neutral_days}日
- ネガティブな日: ${summary.negative_days}日
- よく出るキーワード: ${summary.top_keywords.join("、")}

このデータから、ユーザーの気分の主な傾向を分析し、ユーザーを励ますような、温かいメッセージを100文字以内で生成してください。分析期間を文章に含めてください。`;
        
        // Gemini API呼び出し
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
            
            // 100文字制限チェック
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

// 薬剤師機能は共感チャット（getEmpatheticResponse）に統合されました

exports.getEmpatheticResponse = functions.region("asia-northeast1")
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
      functions.logger.log(`Empathetic response requested by user: ${userId}, Message: \"${userMessage}\"`);

      // ココロンのペルソナを使用
      let systemPrompt = AI_PERSONA.systemPrompts.empatheticChat;
      
      // 薬に関する質問かどうかを判定
      const medicineKeywords = ["薬", "くすり", "クスリ", "medication", "副作用", "飲み合わせ", "服用", "錠剤", "カプセル"];
      const isMedicineRelated = medicineKeywords.some(keyword => userMessage.includes(keyword));
      
      // 過去の日記を取得して文脈を構築
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
      
      // 薬の文脈情報を追加（もし薬関連の質問の場合）
      let medicationContext = "";
      if (isMedicineRelated && data.medicationContext) {
        medicationContext = `\n\nユーザーが服用中の薬: ${data.medicationContext.join("、")}`;
      }

      functions.logger.log("getEmpatheticResponse - Processing chat history:", JSON.stringify(chatHistory));
      
      const contents = [];
      if (chatHistory && Array.isArray(chatHistory)) {
        chatHistory.forEach((msg) => {
          if (msg.role && msg.parts) {
            contents.push({role: msg.role, parts: msg.parts});
          }
        });
      }
      // ユーザーメッセージに文脈情報を追加
      const enrichedMessage = `${userMessage}${contextInfo}${medicationContext}`;
      contents.push({role: "user", parts: [{text: enrichedMessage}]});
      
      functions.logger.log("getEmpatheticResponse - Contents for Vertex AI:", JSON.stringify(contents));

      try {
        const googleApiKey = functions.config().google?.api_key || process.env.GOOGLE_API_KEY;
        if (!googleApiKey) {
          throw new Error("Google AI API key is not configured");
        }
        
        const genAI = new GoogleGenerativeAI(googleApiKey);
        const generativeModel = genAI.getGenerativeModel({
          model: "gemini-2.5-flash",
          systemInstruction: systemPrompt,
        });

        let aiResponseText = "";
        try {
          const resp = await generativeModel.generateContent({contents, generationConfig: {temperature: 0.7}});
          if (resp?.response?.candidates?.[0]?.content?.parts?.[0]?.text) {
            aiResponseText = resp.response.candidates[0].content.parts[0].text;
          } else {
            functions.logger.warn("Invalid or empty response structure from Google AI for empathetic chat. Full response:", JSON.stringify(resp));
            throw new Error("AIからの共感応答が無効か空です。");
          }
          functions.logger.log("Empathetic response from Google AI:", aiResponseText);
        } catch (aiError) {
          functions.logger.error("Error calling Google AI for empathetic chat:", aiError);
          functions.logger.error("Error details:", {
            message: aiError.message,
            stack: aiError.stack,
            name: aiError.name
          });
          aiResponseText = "ごめんねワン...うまく言葉にできないけど、ココロンはずっとそばにいるワン。なでなでするワン。";
        }

        return {aiResponse: aiResponseText};
      } catch (error) {
        functions.logger.error("Error in getEmpatheticResponse function for user", userId, ":", error);
        return {aiResponse: "ごめんねワン...今ちょっと調子が悪いみたいだワン。でもココロンはここにいるワン！"};
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
        throw new functions.https.HttpsError("invalid-argument", "Required field \'situation\' is missing or not a non-empty string.");
      }
      if (partnerQuery && typeof partnerQuery !== "string") {
        throw new functions.https.HttpsError("invalid-argument", "Optional field \'partnerQuery\' must be a string if provided.");
      }

      functions.logger.log(`Communication advice requested by partner user: ${userId}`, {situation: situation, query: partnerQuery});

      const systemPrompt = "あなたは、精���疾患を持つ方のパートナーを支援する専門家AIカウンセラーです。ユーザー（パートナー）から提供される「状況」と「具体的な悩みや質問」に基づき、建設的で共感的、かつ実用的なコミュニケーション方法や心構えについてアドバイスをしてください。アドバイスには、具体的な会話例や行動提案をいくつか含めてください。パートナーが、困難な状況でも希望を持ち、前向きに関係性を築いていけるような、温かく実践的なサポートを提供することを心がけてください。専門用語は避け、分かりやすい言葉で説明してください。回答は「アドバイス：」で始まり、その後に本文を続けてください。具体的な会話例や行動提案は「会話例・行動提案：」で始め、各提案を「- 」で箇条書きにしてください。";

      let userPrompt = `状況：${situation}`;
      if (partnerQuery && partnerQuery.trim() !== "") {
        userPrompt += `\\n具体的な悩みや質問：${partnerQuery}`;
      }
      userPrompt += `\\n\\n上記の状況と悩みを踏まえて、アドバイスと具体的な会話例・行動提案をください。`;

      try {
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
            adviceText: "申し訳ありません、現在AIによるアドバイスを提供できません。一般的な情報源を参考にするか、専門家にご相���ください。",
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
          examplePhrases = examplesString.split("\\n")
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

/**
 * Analyzes a new diary log, generates AI insights, and updates the log.
 * Triggered when a new document is created in users/{userId}/aiDiaryLogs/{logId}.
 */
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
            throw new Error("Google API key is not configured");
          }
          const genAI = new GoogleGenerativeAI(googleApiKey);
          const generativeModel = genAI.getGenerativeModel({model: "gemini-2.5-flash"});

          const positivityPrompt = `以下の日記の内容を分析し、その感情的なポジティブ度を0.0（非常にネガティブ）から1.0（非常にポジティブ）の間の数値でスコアリングしてください。数値のみを返してください。\\n\\n日記：\\n「${diaryText}」`;
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

          const commentPrompt = `以下の日記の内容を読み、評価や批判をせず、ただユーザーに寄り添い、感情を認めるような短い（50～100字程度）AIからの優しい感想コメントを生成してください。\\n例：「今日はそんなことがあったのですね。つらい気持ちを書き出してくれて��ありがとうございます」\\n\\n日記：\\n「${diaryText}」`;
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

/**
 * Generates personal insights based on a user\'s diary logs over a period.
 * This is an HTTP Callable function for initial development and testing.
 * It can be later triggered by Cloud Scheduler.
 */
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
          logsConcatenated += `- ${log.date} (気分: ${log.moodScore}/5): ${log.diaryText}\\n`;
        });
        
        const aiPrompt = `あなたはユーザーのメンタルヘルスジャーニーをサポートする、洞察力に優れたAIアシスタントです。
提供された以下のユーザーの日記ログ（過去約${insightPeriodDays}日分）を分析し、ユーザーが自分自身をより深く理解し、ポジティブな気持ちになれるような「パーソナルな気づき」を生成してください。

# 分析対象の日記ログ:
${logsConcatenated}

# 指示:
1.  **気づきの要約 (summaryText):**
    ログ全体を通して見られるユーザーの気分の傾向、特徴的なパターン、または重要な感情の動きについて、1つか2つの最も重要な「気づき」を、150字以内の優しい言葉で記述してください。
    例: 「最近の日記からは、自然の中で過ごす時間があなたの心に良い影響を与えているようですね。特に週末にそのような時間を持つと、週明けの気分も安定する傾向が見られるかもしれません。」

2.  **キー観察ポイント (keyObservations):**
    上記の「気づきの要約」を裏付ける、具体的な観察結果やログからの引用（もしあれば短い引用）を3つ、箇条書きで記述してください。各ポイントは100字以内でお願いします。
    例:
    - 「『公園を散歩した』『リフレッシュできた』など、自然に関するポジティブな記述が複数見られます。」
    - 「週末に気分スコアが平均的に高く、特に日曜日に活動的な日は月曜のスコアも良い傾向があります。」
    - 「一方で、仕事のプレッシャーを感じた日は、睡眠の質にも影響が出ている可能性が示唆されています。」

3.  **ポジティブなアファメーション (positiveAffirmation):**
    ユーザーを励まし、自己肯定感を高めるような、70字以内の短い前向きなメッセージを生成してください。
    例: 「あなたは自分自身の気持ちに正直に向き合っていますね。その一つ一つの感情が、あなたを形作る大切な一部です。」

# 出力形式:
必ず以下のJSON形式で、キー名も指示通りに返してください。
{
  "summaryText": "ここに「気づきの要約」を記述",
  "keyObservations": [
    "ここに1つ目の「キー観察ポイント」を記述",
    "ここに2つ目の「キー観察ポイント」を記述",
    "ここに3つ目の「キー観察ポイント」を記述"
  ],
  "positiveAffirmation": "ここに「ポジティブなアファメーション」を記述"
}

# 注意事項:
- 常にユーザーに寄り添い、共感的で、非批判的な言葉を選んでください。
- 断定的な表現や医学的な診断と誤解されるような表現は避けてください。「～のようです」「～かもしれませんね」「～傾向が見られます」といった、可能性を示唆する言葉遣いを心がけてください。
- 生成する内容は、ユーザーが提供したログデータのみに基づいてください。
`;
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
                    category: "PERSONAL_INSIGHT_CATEGORY", // Ensure this category is handled on iOS
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

/**
 * Sends medication reminders to users via FCM.
 * Triggered by Cloud Scheduler (e.g., every 5 minutes) via a Pub/Sub topic.
 * Function name for Pub/Sub trigger: sendMedicationReminders
 */
exports.sendMedicationReminders = functions.region("asia-northeast1")
    .pubsub.topic("medication-reminders") // Ensure this topic exists or is created
    .onPublish(async (message) => {
      functions.logger.log("Executing sendMedicationReminders due to Pub/Sub trigger.");

      const now = new Date(); // Current time in UTC on the server
      // Get current time in minutes since midnight UTC
      const currentMinutesSinceMidnight = now.getUTCHours() * 60 + now.getUTCMinutes();
      // Define a window for reminders (e.g., medication due in the next 5 minutes)
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

          // Fetch medications for the user that have reminders enabled
          const medicationsSnapshot = await db
              .collection("users")
              .doc(userId)
              .collection("medications")
              .where("reminderEnabled", "==", true)
              .get();

          if (medicationsSnapshot.empty) {
            // functions.logger.log(`No medications requiring reminders found for user ${userId}.`);
            continue;
          }

          medicationsSnapshot.forEach((medDoc) => {
            const medication = medDoc.data();
            const medId = medDoc.id;

            if (!medication.name || !medication.times || !Array.isArray(medication.times) || medication.times.length === 0) {
              functions.logger.warn(`Medication ${medId} for user ${userId} has invalid name or 'times' field. Skipping.`);
              return; // skip this medication\'s time
            }

            medication.times.forEach((timeStr) => { // timeStr is "HH:mm"
              const timeParts = timeStr.split(":");
              if (timeParts.length !== 2) {
                functions.logger.warn(`Invalid time format \"${timeStr}\" for med ${medId}, user ${userId}. Skipping.`);
                return; // skip this specific time string
              }
              const medicationHour = parseInt(timeParts[0], 10);
              const medicationMinute = parseInt(timeParts[1], 10);

              if (isNaN(medicationHour) || isNaN(medicationMinute) || medicationHour < 0 || medicationHour > 23 || medicationMinute < 0 || medicationMinute > 59) {
                functions.logger.warn(`Could not parse time or time out of range \"${timeStr}\" for med ${medId}, user ${userId}. Skipping.`);
                return; // skip this specific time string
              }
              
              const medicationTimeInMinutesUTC = medicationHour * 60 + medicationMinute;

              // Check if the medication time falls within the reminder window
              if (
                medicationTimeInMinutesUTC >= currentMinutesSinceMidnight &&
                medicationTimeInMinutesUTC < currentMinutesSinceMidnight + reminderWindowMinutes
              ) {
                functions.logger.log(`Medication ${medication.name} (ID: ${medId}) for user ${userId} is due at ${timeStr} (UTC). Current server time (UTC minutes): ${currentMinutesSinceMidnight}, Med time (UTC minutes): ${medicationTimeInMinutesUTC}`);
                
                // Construct a precise timestamp for this specific intake today (UTC)
                const scheduledIntakeDate = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), medicationHour, medicationMinute, 0, 0));
                const scheduledIntakeTimestamp = admin.firestore.Timestamp.fromDate(scheduledIntakeDate);

                const p = (async () => {
                  // Check if a log entry for this specific medication and scheduled time already exists
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

                  // If log exists and status is \'taken\' or \'skipped\', or reminderSentAt is already set, don\'t send reminder.
                  if (logData && (logData.status === "taken" || logData.status === "skipped")) {
                    functions.logger.log(`User ${userId} already logged medication ${medication.name} for ${timeStr} as ${logData.status}. No reminder needed.`);
                    return;
                  }
                  if (logData && logData.reminderSentAt) {
                    functions.logger.log(`Reminder for ${medication.name} at ${timeStr} for user ${userId} already sent at ${logData.reminderSentAt.toDate().toISOString()}. Skipping.`);
                    return;
                  }

                  // Send FCM Notification
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
                    
                    if (logDoc) { // If log entry exists (but reminder wasn\'t sent and status is not final)
                       await logDoc.ref.update({ reminderSentAt: reminderSentTimestampFirestore, status: "pending_reminder_sent" });
                    } else { // Create a new log entry
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
        return null; // Important to return null or a Promise for Pub/Sub functions
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
      
      // ココロンのペルソナを使用
      const systemPrompt = AI_PERSONA.systemPrompts.diaryComment;
      
      // 過去の日記を取得して文脈を構築（オプション）
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
      
      const prompt = `
        以下の日記に対して、ココロン（相棒のワンちゃん）として優しくコメントしてください。
        ${contextInfo}
        
        今日の日記:
        「${diaryText}」
        ${selectedEvents && selectedEvents.length > 0 ? `今日したこと: ${selectedEvents.join("、")}` : ""}
        ${sleepDurationHours ? `睡眠時間: ${sleepDurationHours}時間` : ""}

        ココロンのコメント:
      `;

      try {
        // Vertex AI Clientの初期化 (Function内で都度)
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
      selectedEvents: selectedEvents || [], // 選択されたイベントIDの配列を保存
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      overallMoodScore: selfReportedMoodScore, // 一旦自己申告スコアを入れておく
      aiAnalyzedPositivityScore: null, // analyzeAiDiaryLog で設定される想定
    };

    // 睡眠時間データを追加
    if (sleepDurationHours !== undefined && sleepDurationHours !== null) {
      newLogEntry.sleepDurationHours = sleepDurationHours;
      functions.logger.log(`Sleep duration recorded: ${sleepDurationHours} hours`);
    }

    // 天気データを追加
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
      
      // バックグラウンドで心のヒントを更新（非同期処理でレスポンスをブロックしない）
      updateMentalHintsInBackground(userId).catch(error => {
        functions.logger.error("Background mental hints update failed:", error);
        // エラーがあってもメインの処理には影響しない
      });
      
      // 注意：分析メッセージはgenerateAnalysisMessages関数（Firestore trigger）で自動更新されるため、
      // ここでの手動呼び出しは不要です。
      
      return {
        success: true,
        logId: docRef.id,
        aiComment: aiComment,
        // 保存したドキュメントの内容を返すことも可能
        // newLog: { ...newLogEntry, timestamp: new Date().toISOString() } // timestampはサーバー側で設定されるので近似値
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

    const userId = context.auth.uid;
    
    try {
      functions.logger.log(`Mental hints requested by user: ${userId}`);
      
      // Firestoreから保存済みの心のヒントを取得
      const hintsDoc = await db
        .collection("users")
        .doc(userId)
        .collection("mentalHints")
        .doc("current")
        .get();
      
      if (hintsDoc.exists) {
        const hintsData = hintsDoc.data();
        functions.logger.log(`Retrieved mental hints from Firestore for user ${userId}`);
        return {
          hints: hintsData.hints || [],
          message: hintsData.message,
          analyzedPeriod: hintsData.analyzedPeriod,
          totalLogs: hintsData.totalLogs,
          updatedAt: hintsData.updatedAt
        };
      } else {
        // 初回アクセス時は空のヒントを返し、バックグラウンドで更新を開始
        functions.logger.log(`No mental hints found for user ${userId}, triggering background update`);
        
        // バックグラウンドで更新（非同期）
        updateMentalHintsInBackground(userId).catch(error => {
          functions.logger.error("Background mental hints update failed:", error);
        });
        
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
      functions.logger.error(`Error in getMentalHints for user ${userId}:`, error);
      throw new functions.https.HttpsError(
        "internal",
        "心のヒントの取得中にエラーが発生しました。",
        error.message
      );
    }
  });

// バックグラウンドで心のヒントを更新する関数
async function updateMentalHintsInBackground(userId) {
  try {
    functions.logger.log(`Background mental hints update started for user: ${userId}`);
    
    // 心のヒント更新開始の状態をFirestoreに保存
    await db.collection('users').doc(userId)
        .collection('mentalHints').doc('current')
        .set({
            isUpdating: true,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

    functions.logger.log(`Mental hints loading state set for user: ${userId}`);
    
    // 過去30日間の日記ログを取得
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
      // 空のヒントデータを保存
      await saveMentalHints(userId, [], "まだ分析に必要なデータが集まっていません。", 0);
      return;
    }

    // データを収集（睡眠・天気データも含む）
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

    // ココロンのペルソナを使用
    const systemPrompt = AI_PERSONA.systemPrompts.mentalHints + `

分析結果は以下のJSON形式で最大5つのヒントを返してください：
{
  "hints": [
    {
      "title": "ヒントのタイトル（例：お散歩と気分の関係だワン）",
      "content": "具体的な内容（例：お散歩した日は気分スコアが平均で+1.5ポイント高いみたいだワン！）",
      "icon": "関連する絵文字1つ",
      "type": "positive/warning/neutral"
    }
  ]
}`;

    const dataForAnalysis = logs.map(log => ({
      date: log.date.toISOString().split('T')[0],
      moodScore: log.moodScore,
      events: log.events,
      diaryPreview: log.diaryText.substring(0, 100),
      sleepHours: log.sleepDurationHours,
      weather: log.weather
    }));

    const prompt = `以下のユーザーの日記データを分析し、行動・睡眠・天気と気分の関係についての具体的なヒントを生成してください。

データ：
${JSON.stringify(dataForAnalysis, null, 2)}

注意事項：
- イベント名は日本語で記載されています
- 気分スコアは1（最低）から5（最高）の5段階評価です
- sleepHours は睡眠時間（時間単位、null の場合はデータなし）
- weather は天気データ（null の場合はデータなし）
- 統計的に有意な傾向や繰り返しパターンを見つけてください
- 睡眠時間、天気条件、行動の組み合わせによる気分への影響を分析してください
- ユーザーが実際に生活習慣を改善できるような具体的なアドバイスを含めてください
- 活動や行動を言及する時は必ず日本語で表現してください（例：「よく眠れた日」「散歩」「運動」など）
- 英語のイベント名（good_sleep, exerciseなど）は使用しないでください
- 文章はシンプルで分かりやすく、読みやすいものにしてください
- 「しっぽブンブン」「ワンワン」などの過度な犬の表現は控えめにしてください
- データに基づいた客観的な分析結果を中心に伝えてください`;

    // Google AI Gemini APIを呼び出し
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
        // レスポンスからJSON部分を抽出
        let jsonString = '';
        const jsonMatch = rawResponse.match(/```json\s*([\s\S]*?)\s*```/);
        if (jsonMatch) {
          jsonString = jsonMatch[1].trim();
        } else {
          // ```json```が見つからない場合は、{で始まる部分を探す
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

    // Firestoreに保存
    await saveMentalHints(userId, hints, null, logs.length);
    
    functions.logger.log(`Background mental hints update completed for user: ${userId}`);
    
  } catch (error) {
    functions.logger.error(`Error in background mental hints update for user ${userId}:`, error);
    
    // エラー時のフォールバック処理：最低限のヒントをFirestoreに保存
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
    
    // エラーを再スローしないことで、呼び出し元の処理を続行
    return;
  }
}

// 心のヒントをFirestoreに保存する関数
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

  // ユーザーの心のヒントドキュメントを上書き保存（1つのドキュメントで管理）
  await db
    .collection("users")
    .doc(userId)
    .collection("mentalHints")
    .doc("current")
    .set(hintsData, { merge: false }); // 完全上書き

  functions.logger.log(`Mental hints saved for user ${userId}`);
}
