require('dotenv').config();

const express = require('express');
const cors = require('cors');

/**
 * Optional Firebase Admin — only loads when FIREBASE_CONFIG_B64 is set
 * (base64-encoded service account JSON). Missing or invalid config must not crash the process.
 */
function tryInitFirebaseAdmin() {
  const b64 = process.env.FIREBASE_CONFIG_B64;
  if (!b64 || !String(b64).trim()) {
    console.warn(
      '[Peepl Backend] FIREBASE_CONFIG_B64 is not set; Firebase Admin is disabled. ' +
        'Server will start without Firebase.',
    );
    return false;
  }
  try {
    const admin = require('firebase-admin');
    const json = JSON.parse(
      Buffer.from(String(b64).trim(), 'base64').toString('utf8'),
    );
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(json),
      });
    }
    console.log('[Peepl Backend] Firebase Admin initialized.');
    return true;
  } catch (err) {
    console.warn(
      '[Peepl Backend] Firebase Admin could not be initialized:',
      err?.message || err,
    );
    return false;
  }
}

tryInitFirebaseAdmin();

const app = express();
const PORT = process.env.PORT || 3000;

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

app.listen(PORT, () => {
  console.log(`Peepl Backend listening on port ${PORT}`);
});
