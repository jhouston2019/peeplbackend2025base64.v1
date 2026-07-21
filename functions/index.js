const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();
const USERS_COLLECTION = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

// ─── HELPER: get FCM token for a uid ───────────────────────────────────────
async function getFcmToken(uid) {
  try {
    const userSnap = await db.collection(USERS_COLLECTION).doc(uid).get();
    if (userSnap.exists && userSnap.data()?.fcmToken) {
      return userSnap.data().fcmToken;
    }
    const snap = await db.collection(uid).doc('profile').get();
    return snap.exists ? (snap.data()?.fcmToken ?? null) : null;
  } catch (e) {
    console.error(`getFcmToken error for ${uid}:`, e);
    return null;
  }
}

// ─── HELPER: send a single FCM message ─────────────────────────────────────
async function sendFcm(token, title, body, data = {}) {
  if (!token) return;
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data,
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
      android: {
        priority: 'high',
        notification: { sound: 'default' },
      },
    });
  } catch (e) {
    console.error('sendFcm error:', e);
  }
}

// ─── FUNCTION 1: onCrowdsourceRequest ──────────────────────────────────────
// Fires when User A writes to crowdsource_requests.
// Finds all presence docs within ~150m with expiresAt > now.
// Sends FCM to each matched user (excluding the requester).
exports.onCrowdsourceRequest = functions.firestore
  .document('crowdsource_requests/{requestId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const { requestedBy, locationName, latitude, longitude } = data;

    if (!latitude || !longitude || !locationName) {
      console.log('Missing required fields, skipping.');
      return null;
    }

    const DELTA = 0.00135; // ~150m in degrees
    const now = admin.firestore.Timestamp.now();

    let presenceSnap;
    try {
      presenceSnap = await db.collection('presence')
        .where('latitude', '>=', latitude - DELTA)
        .where('latitude', '<=', latitude + DELTA)
        .where('expiresAt', '>', now)
        .limit(50)
        .get();
    } catch (e) {
      console.error('Presence query error:', e);
      return null;
    }

    if (presenceSnap.empty) {
      console.log('No active presence found near', locationName);
      await snap.ref.update({ status: 'no_targets' });
      return null;
    }

    // Filter longitude in-memory + exclude requester
    const targets = presenceSnap.docs.filter(doc => {
      const d = doc.data();
      const lngOk = d.longitude >= longitude - DELTA &&
                    d.longitude <= longitude + DELTA;
      const notSelf = doc.id !== requestedBy;
      return lngOk && notSelf;
    });

    if (targets.length === 0) {
      console.log('No targets after filtering for', locationName);
      await snap.ref.update({ status: 'no_targets' });
      return null;
    }

    // Send FCM to each target
    const sends = targets.map(async (doc) => {
      const uid = doc.id;
      const token = await getFcmToken(uid);
      if (!token) return;
      await sendFcm(
        token,
        `How crowded is ${locationName}?`,
        'Someone nearby wants to know — tap to report crowd levels.',
        {
          type: 'crowdsource_request',
          locationName,
          latitude: String(latitude),
          longitude: String(longitude),
          requestId: context.params.requestId,
        }
      );
    });

    await Promise.all(sends);

    await snap.ref.update({
      status: 'sent',
      targetCount: targets.length,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Sent crowdsource request for ${locationName} to ${targets.length} users.`);
    return null;
  });

// ─── FUNCTION 2: onLikeCreated ──────────────────────────────────────────────
// Fires when someone likes a post.
// Notifies the post owner (unless they liked their own post).
exports.onLikeCreated = functions.firestore
  .document('location_posts/{postId}/likes/{likerId}')
  .onCreate(async (snap, context) => {
    const { postId, likerId } = context.params;

    let postSnap;
    try {
      postSnap = await db.collection('location_posts').doc(postId).get();
    } catch (e) {
      console.error('Post fetch error:', e);
      return null;
    }

    if (!postSnap.exists) return null;

    const post = postSnap.data();
    const postOwnerId = post.userId;
    const locationName = post.locationName ?? 'your post';

    // Don't notify if user liked their own post
    if (postOwnerId === likerId) return null;

    const token = await getFcmToken(postOwnerId);
    if (!token) return null;

    await sendFcm(
      token,
      'Someone liked your Peepl',
      `Your crowd report at ${locationName} got a like!`,
      {
        type: 'post_liked',
        postId,
        locationName,
      }
    );

    return null;
  });

// ─── FUNCTION 3: onNewPost ─────────────────────────────────────────────────
// Fires when a client writes notification_triggers/{postId} after submitting a post.
// Notifies users within 1 km (excluding the poster).
function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

exports.onNewPost = functions.firestore
  .document('notification_triggers/{postId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const { latitude, longitude, locationName, posterId } = data;
    const postId = context.params.postId;

    if (latitude == null || longitude == null || !locationName || !posterId) {
      console.log('onNewPost: missing required fields, skipping.');
      return null;
    }

    const KM_DELTA = 0.009; // ~1 km latitude band

    let usersSnap;
    try {
      usersSnap = await db
        .collection(USERS_COLLECTION)
        .where('lastLocation.latitude', '>=', latitude - KM_DELTA)
        .where('lastLocation.latitude', '<=', latitude + KM_DELTA)
        .limit(200)
        .get();
    } catch (e) {
      console.error('onNewPost user query error:', e);
      return null;
    }

    const sends = [];
    for (const doc of usersSnap.docs) {
      if (doc.id === posterId) continue;

      const lastLoc = doc.data().lastLocation;
      if (!lastLoc || lastLoc.latitude == null || lastLoc.longitude == null) {
        continue;
      }

      const dist = haversineKm(
        latitude,
        longitude,
        lastLoc.latitude,
        lastLoc.longitude,
      );
      if (dist > 1) continue;

      const token = doc.data().fcmToken || (await getFcmToken(doc.id));
      if (!token) continue;

      sends.push(
        sendFcm(
          token,
          'New post nearby',
          `Someone just posted about ${locationName} near you — check it out!`,
          {
            type: 'new_post_nearby',
            postId,
            locationName,
          },
        ),
      );
    }

    await Promise.all(sends);
    console.log(`onNewPost: sent ${sends.length} notifications for ${locationName}`);
    return null;
  });
