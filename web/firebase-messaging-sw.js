// firebase-messaging-sw.js
importScripts('https://www.gstatic.com/firebasejs/9.22.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey:            "AIzaSyDRULs-S5ZLE7-d03JYF88i2H5Jol6Q1HU",
  authDomain:        "pawpoints-298c1.firebaseapp.com",
  projectId:         "pawpoints-298c1",
  messagingSenderId: "229712878962",
  appId:             "1:229712878962:web:99ac8525697a3fcad691eb"
});

const messaging = firebase.messaging();
messaging.onBackgroundMessage(payload => {
  console.log('[firebase-messaging-sw.js] BG Message', payload);
});
