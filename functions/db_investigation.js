const admin = require("firebase-admin");

// Firebase Admin SDKの初期化
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();

async function investigateDatabase() {
    const userId = "Pottmmh13iOSNnzIyIn7BPiGx222";
    
    console.log("=== Firebase Firestore データベース調査開始 ===");
    console.log(`対象ユーザー: ${userId}`);
    console.log();

    try {
        // 1. mindForecast コレクションの存在確認
        console.log("1. mindForecast コレクションの調査");
        const mindForecastRef = db.collection("users").doc(userId).collection("mindForecast");
        const mindForecastSnapshot = await mindForecastRef.get();
        
        if (mindForecastSnapshot.empty) {
            console.log("❌ mindForecast コレクションが存在しません");
        } else {
            console.log(`✅ mindForecast コレクション存在: ${mindForecastSnapshot.size} ドキュメント`);
            
            // 各期間のドキュメントを調査
            const periods = ['daily', 'weekly', 'monthly'];
            for (const period of periods) {
                const periodDoc = await mindForecastRef.doc(period).get();
                if (periodDoc.exists) {
                    const data = periodDoc.data();
                    console.log(`  ✅ ${period} ドキュメント存在:`);
                    console.log(`    - text: ${data.text ? data.text.substring(0, 50) + "..." : "なし"}`);
                    console.log(`    - emoji: ${data.emoji || "なし"}`);
                    console.log(`    - advice: ${data.advice ? data.advice.substring(0, 50) + "..." : "なし"}`);
                    console.log(`    - totalLogs: ${data.totalLogs || "なし"}`);
                    console.log(`    - updatedAt: ${data.updatedAt ? data.updatedAt.toDate().toISOString() : "なし"}`);
                } else {
                    console.log(`  ❌ ${period} ドキュメントが存在しません`);
                }
            }
        }
        
        console.log();
        
        // 2. aiDiaryLogs コレクションの調査
        console.log("2. aiDiaryLogs コレクションの調査");
        const diaryLogsRef = db.collection("users").doc(userId).collection("aiDiaryLogs");
        const diaryLogsSnapshot = await diaryLogsRef.orderBy("timestamp", "desc").limit(10).get();
        
        if (diaryLogsSnapshot.empty) {
            console.log("❌ aiDiaryLogs コレクションにデータがありません");
        } else {
            console.log(`✅ aiDiaryLogs コレクション存在: 最新10件を表示`);
            
            diaryLogsSnapshot.forEach((doc, index) => {
                const data = doc.data();
                const timestamp = data.timestamp ? data.timestamp.toDate() : new Date();
                console.log(`  ${index + 1}. ドキュメントID: ${doc.id}`);
                console.log(`     - 日時: ${timestamp.toISOString()}`);
                console.log(`     - overallMoodScore: ${data.overallMoodScore || "なし"}`);
                console.log(`     - selfReportedMoodScore: ${data.selfReportedMoodScore || "なし"}`);
                console.log(`     - diaryText: ${data.diaryText ? data.diaryText.substring(0, 30) + "..." : "なし"}`);
                console.log(`     - aiComment: ${data.aiComment ? "あり" : "なし"}`);
                console.log();
            });
        }
        
        // 3. ユーザードキュメントの確認
        console.log("3. ユーザードキュメントの調査");
        const userDoc = await db.collection("users").doc(userId).get();
        
        if (userDoc.exists) {
            const userData = userDoc.data();
            console.log("✅ ユーザードキュメント存在:");
            console.log(`  - email: ${userData.email || "なし"}`);
            console.log(`  - name: ${userData.name || "なし"}`);
            console.log(`  - fcmToken: ${userData.fcmToken ? "設定済み" : "なし"}`);
            console.log(`  - createdAt: ${userData.createdAt ? userData.createdAt.toDate().toISOString() : "なし"}`);
        } else {
            console.log("❌ ユーザードキュメントが存在しません");
        }
        
        // 4. 最新のmindForecast更新状況の詳細確認
        console.log();
        console.log("4. mindForecast 詳細分析");
        for (const period of ['daily', 'weekly', 'monthly']) {
            const periodDoc = await mindForecastRef.doc(period).get();
            if (periodDoc.exists) {
                const data = periodDoc.data();
                console.log(`--- ${period} forecast ---`);
                console.log(`完全なtext: ${data.text || "なし"}`);
                console.log(`完全なadvice: ${data.advice || "なし"}`);
                console.log(`analyzedPeriod: ${JSON.stringify(data.analyzedPeriod) || "なし"}`);
                console.log();
            }
        }

    } catch (error) {
        console.error("データベース調査中にエラーが発生:", error);
    }
    
    console.log("=== データベース調査完了 ===");
}

// スクリプト実行
investigateDatabase().then(() => {
    console.log("調査が完了しました。");
    process.exit(0);
}).catch((error) => {
    console.error("調査中にエラーが発生しました:", error);
    process.exit(1);
});