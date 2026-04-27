importScripts("https://www.gstatic.com/firebasejs/12.12.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/12.12.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: 'AIzaSyC40iVPmoeZmVwxlu_vQZzni6_vXpnEsZc',
  appId: '1:401946278556:web:ab7659bea1ccd4178b0b59',
  messagingSenderId: '401946278556',
  projectId: 'dclub-32718',
  authDomain: 'dclub-32718.firebaseapp.com',
  databaseURL: 'https://dclub-32718-default-rtdb.firebaseio.com',
  storageBucket: 'dclub-32718.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
