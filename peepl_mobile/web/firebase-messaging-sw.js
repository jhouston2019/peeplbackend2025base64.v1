/* eslint-disable no-undef */
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyD1cbXZCQS_Bcu7kmJOcHlUZm4TxLKucJA",
  authDomain: "crowd-checker-7bd94.firebaseapp.com",
  projectId: "crowd-checker-7bd94",
  storageBucket: "crowd-checker-7bd94.firebasestorage.app",
  messagingSenderId: "651814138260",
  appId: "1:651814138260:web:ee88fe618dd5d409f8df81"
});

const messaging = firebase.messaging();
