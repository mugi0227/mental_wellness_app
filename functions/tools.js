const admin = require("firebase-admin");
const functions = require("firebase-functions");
const axios = require("axios"); // For making HTTP requests

/**
 * Generates the tool definition for use with Google's Generative AI.
 */
function defineTools() {
  // 1. Tool for getting medication information
  const getMedicationInfoTool = {
    functionDeclarations: [
      {
        name: "getMedicationInfo",
        description: "ユーザーが現在服用している薬やサプリメントの名前を取得します。この関数を呼び出すと、現在ログインしているユーザーの薬のリストが返されます。",
        parameters: {
          type: "OBJECT",
          properties: {}, // No properties for the model to fill
        },
      },
    ],
  };

  // 2. Tool for getting supporter information
  const getSupporterInfoTool = {
    functionDeclarations: [
      {
        name: "getSupporterInfo",
        description: "ユーザーをサポートしている人（サポーター）に関する情報を取得します。この関数を呼び出すと、現在ログインしているユーザーのサポーターのリストが返されます。",
        parameters: {
          type: "OBJECT",
          properties: {}, // No properties for the model to fill
        },
      },
    ],
  };

  // 3. NEW Tool for searching drug information
  const searchDrugInfoTool = {
    functionDeclarations: [
        {
            name: "searchDrugInfo",
            description: "特定の薬の名前（一般名または商品名）について、その効果、副作用、注意事項などの一般的な情報をウェブで検索して概要を返します。",
            parameters: {
                type: "OBJECT",
                properties: {
                    drugName: {
                        type: "STRING",
                        description: "検索する薬の名前。"
                    }
                },
                required: ["drugName"]
            }
        }
    ]
  };

  return {
    getMedicationInfoTool,
    getSupporterInfoTool,
    searchDrugInfoTool, // Export the new tool
  };
}


/**
 * Executes the requested tool based on the AI's function call.
 */
async function executeTool(toolCall, userId) {
    const functionName = toolCall.name;
    const args = toolCall.args;
    let result;

    functions.logger.log(`[Tool Executor] Attempting to execute tool: ${functionName} for user: ${userId}`, { args });

    try {
        switch (functionName) {
            case "getMedicationInfo":
                result = await getMedicationInfo(userId);
                break;
            case "getSupporterInfo":
                result = await getSupporterInfo(userId);
                break;
            case "searchDrugInfo":
                result = await searchDrugInfo(args.drugName);
                break;
            default:
                functions.logger.warn(`[Tool Executor] Unknown tool called: ${functionName}`);
                result = { error: `The tool '${functionName}' is not available.` };
        }
    } catch (error) {
        functions.logger.error(`[Tool Executor] Error executing tool '${functionName}':`, error);
        result = { error: `An error occurred while executing the tool: ${error.message}` };
    }

    return {
        toolCall,
        result
    };
}


// --- Tool Implementation Functions ---

async function getMedicationInfo(userId) {
  const db = admin.firestore();
  functions.logger.log(`[Tool] getMedicationInfo called for user: ${userId}`);
  const snapshot = await db.collection("users").doc(userId).collection("medications").get();
  if (snapshot.empty) {
    return { info: "現在、登録されているお薬の情報はありません。" };
  }
  const medications = snapshot.docs.map(doc => {
      const data = doc.data();
      return `${data.name}（${data.dosage || '用法記載なし'}）を${data.reminderEnabled ? 'リマインダー設定あり' : 'リマインダー設定なし'}で服用中。`;
  });
  return { medications: medications.join(" ") };
}

async function getSupporterInfo(userId) {
  const db = admin.firestore();
  functions.logger.log(`[Tool] getSupporterInfo called for user: ${userId}`);
  const snapshot = await db.collection("users").doc(userId).collection("supporterLinks").get();
  if (snapshot.empty) {
    return { info: "現在、登録されているサポーターの情報はありません。" };
  }
  const supporters = snapshot.docs.map(doc => {
      const data = doc.data();
      return `${data.supporterName}さん（${data.relationship || '関係性未設定'}）がサポーターです。`;
  });
  return { supporters: supporters.join(" ") };
}

async function searchDrugInfo(drugName) {
    functions.logger.log(`[Tool] Starting web search for: ${drugName}`);
    try {
        // Use a public search API endpoint as a proxy for Google Search
        const response = await axios.get(`https://duckduckgo.com/html/?q=${encodeURIComponent(drugName + " 効果 副作用")}`, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
        });
        
        // Extract a snippet of the search result. This is a very simplified parser.
        const snippetMatch = response.data.match(/<a class="result__snippet"[^>]*>([^<]+)/);
        const snippet = snippetMatch ? snippetMatch[1] : "検索結果の要約を取得できませんでした。";

        functions.logger.log(`[Tool] Web search for "${drugName}" successful. Snippet: ${snippet}`);
        return {
            summary: snippet
        };
    } catch (error) {
        functions.logger.error(`[Tool] Web search for "${drugName}" failed:`, error);
        return {
            error: `「${drugName}」についての情報をウェブで検索中にエラーが発生しました。`
        };
    }
}


module.exports = {
  defineTools,
  executeTool,
};
