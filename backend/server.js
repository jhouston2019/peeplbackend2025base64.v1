require('dotenv').config();

const express = require('express');
const cors = require('cors');

let adminApp = null;
if (process.env.FIREBASE_CONFIG_B64) {
  try {
    const admin = require('firebase-admin');
    const serviceAccount = JSON.parse(
      Buffer.from(process.env.FIREBASE_CONFIG_B64, 'base64').toString('utf8'),
    );
    adminApp = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: process.env.FIREBASE_PROJECT_ID || 'crowd-checker-7bd94',
    });
    console.log('Firebase Admin initialized');
  } catch (e) {
    console.warn('Firebase Admin init failed:', e.message);
  }
} else {
  console.warn('FIREBASE_CONFIG_B64 not set — Firebase Admin disabled');
}

const app = express();

app.use(cors());

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    app: 'Peepl Backend',
    timestamp: new Date(),
  });
});

app.get('/', (req, res) => {
  res.json({ message: 'Peepl API is running' });
});

app.use((req, res) => {
  res.status(404).json({ error: 'Not Found' });
});

app.use((err, req, res, next) => {
  console.error(err);
  const status = err.status || err.statusCode || 500;
  res.status(status).json({
    error: err.message || 'Internal Server Error',
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});

// deploy trigger
