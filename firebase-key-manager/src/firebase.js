import { initializeApp } from 'firebase/app';

const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "fukuoka",
  databaseURL: "https://fukuoka-f4318-default-rtdb.firebaseio.com",
  projectId: "fukuoka",
  storageBucket: "YOUR_STORAGE_BUCKET",
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
  appId: "YOUR_APP_ID"
};

const app = initializeApp(firebaseConfig);

export { app };

