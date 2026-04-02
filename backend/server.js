require('dotenv').config();

const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  if (process.env.FIREBASE_CONFIG_B64) {
    const serviceAccount = JSON.parse(
      Buffer.from(process.env.FIREBASE_CONFIG_B64, 'base64').toString('utf8')
    );
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    console.log('[Firebase Admin] Initialised from FIREBASE_CONFIG_B64');
  } else {
    console.warn('[Firebase Admin] FIREBASE_CONFIG_B64 not set — push notifications disabled');
  }
}

async function getFcmToken(uid) {
  const doc = await admin.firestore().collection(uid).doc('profile').get();
  if (!doc.exists) throw new Error(`No profile document for uid ${uid}`);
  const token = doc.data().fcmToken;
  if (!token) throw new Error(`No FCM token stored for uid ${uid}`);
  return token;
}

const app = express();

app.use(cors());
app.use(express.json());

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

// POST /notifications/send — generic single-user push
// Body: { uid, title, body, data? }
app.post('/notifications/send', async (req, res) => {
  if (!admin.apps.length) return res.status(503).json({ error: 'Firebase Admin not initialised' });
  const { uid, title, body, data = {} } = req.body;
  if (!uid || !title || !body) return res.status(400).json({ error: 'uid, title, and body are required' });
  try {
    const token = await getFcmToken(uid);
    const messageId = await admin.messaging().send({
      token,
      notification: { title, body },
      data: { ...data, type: data.type || 'general' },
      android: { notification: { channelId: 'peepl_high_importance', priority: 'high', color: '#1565C0' } },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    });
    console.log(`[FCM] Sent to ${uid}: ${messageId}`);
    res.json({ success: true, messageId });
  } catch (err) {
    console.error(`[FCM] Send error for ${uid}:`, err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST /notifications/like — triggered when a user likes a post
// Body: { postOwnerUid, likerUsername, postId, locationName }
app.post('/notifications/like', async (req, res) => {
  if (!admin.apps.length) return res.status(503).json({ error: 'Firebase Admin not initialised' });
  const { postOwnerUid, likerUsername, postId, locationName } = req.body;
  if (!postOwnerUid || !likerUsername || !postId) return res.status(400).json({ error: 'postOwnerUid, likerUsername, and postId are required' });
  try {
    const token = await getFcmToken(postOwnerUid);
    const messageId = await admin.messaging().send({
      token,
      notification: {
        title: '❤️ New Like',
        body: `${likerUsername} liked your post${locationName ? ` at ${locationName}` : ''}`,
      },
      data: { type: 'post_liked', postId, locationName: locationName || '' },
      android: { notification: { channelId: 'peepl_high_importance', priority: 'high', color: '#1565C0' } },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    });
    console.log(`[FCM] Like notification sent to ${postOwnerUid}: ${messageId}`);
    res.json({ success: true, messageId });
  } catch (err) {
    if (err.message.includes('No FCM token')) return res.json({ success: false, reason: 'no_token' });
    console.error('[FCM] Like notification error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST /notifications/proximity — triggered when a new post is within 5 miles of a user
// Body: { targetUid, posterUsername, locationName, postId }
app.post('/notifications/proximity', async (req, res) => {
  if (!admin.apps.length) return res.status(503).json({ error: 'Firebase Admin not initialised' });
  const { targetUid, posterUsername, locationName, postId } = req.body;
  if (!targetUid || !locationName || !postId) return res.status(400).json({ error: 'targetUid, locationName, and postId are required' });
  try {
    const token = await getFcmToken(targetUid);
    const messageId = await admin.messaging().send({
      token,
      notification: {
        title: '📍 New Crowd Report Nearby',
        body: `${posterUsername || 'Someone'} just posted from ${locationName}`,
      },
      data: { type: 'new_post', postId, locationName },
      android: { notification: { channelId: 'peepl_high_importance', priority: 'high', color: '#1565C0' } },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    });
    res.json({ success: true, messageId });
  } catch (err) {
    if (err.message.includes('No FCM token')) return res.json({ success: false, reason: 'no_token' });
    console.error('[FCM] Proximity notification error:', err.message);
    res.status(500).json({ error: err.message });
  }
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
