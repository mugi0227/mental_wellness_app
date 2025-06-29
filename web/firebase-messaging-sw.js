// このファイルは変更しないでください
// Firebase SDKのスクリプトをインポートします
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// ★★★ ここにあなたのFirebase設定を貼り付けます ★★★
const firebaseConfig = {
  apiKey: "AIzaSyAbjhCCwakzWtuL3QH4epun4l4PxsSKgwk",
  authDomain: "mental-wellness-app-f9de6.firebaseapp.com",
  projectId: "mental-wellness-app-f9de6",
  storageBucket: "mental-wellness-app-f9de6.firebasestorage.app",
  messagingSenderId: "799464802692",
  appId: "1:799464802692:web:3b8507b24ffcf7e00db5d1",
  measurementId: "G-S262ZN8SYD"
};

// 上記の設定を使ってFirebaseを初期化します
firebase.initializeApp(firebaseConfig);

// Firebase Messagingのインスタンスを取得します
const messaging = firebase.messaging();

// バックグラウンドでメッセージを受信したときの処理
messaging.onBackgroundMessage(function(payload) {
  console.log('Received background message ', payload);
  
  // 通知のタイトルと本文を取得します
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png' // 通知に表示するアイコン（任意）
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
