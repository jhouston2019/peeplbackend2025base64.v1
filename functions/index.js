const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

admin.initializeApp();

const db = getFirestore();
const messaging = getMessaging();
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
// Fires when a client writes to crowdsource_requests/{requestId}.
// Finds nearby users via haversine on lastKnown* or lastLocation coords.
// Sends FCM to each matched user (excluding the requester).
function getUserCoords(userData) {
  if (userData.lastKnownLatitude != null && userData.lastKnownLongitude != null) {
    return {
      latitude: userData.lastKnownLatitude,
      longitude: userData.lastKnownLongitude,
    };
  }
  const lastLoc = userData.lastLocation;
  if (lastLoc?.latitude != null && lastLoc?.longitude != null) {
    return {
      latitude: lastLoc.latitude,
      longitude: lastLoc.longitude,
    };
  }
  return null;
}

exports.onCrowdsourceRequest = functions.firestore
  .document('crowdsource_requests/{requestId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const {
      requestedBy,
      locationName,
      latitude,
      longitude,
      radiusKm = 0.2,
      message,
    } = data;

    if (latitude == null || longitude == null || !locationName) {
      console.log('Missing required fields, skipping.');
      return null;
    }

    const latDelta = radiusKm / 111;
    const body =
      message ||
      `Someone is curious about ${locationName}, would you mind sharing a peep?`;

    let usersSnap;
    let lastKnownSnap;
    try {
      [usersSnap, lastKnownSnap] = await Promise.all([
        db
          .collection(USERS_COLLECTION)
          .where('lastLocation.latitude', '>=', latitude - latDelta)
          .where('lastLocation.latitude', '<=', latitude + latDelta)
          .limit(200)
          .get(),
        db
          .collection(USERS_COLLECTION)
          .where('lastKnownLatitude', '>=', latitude - latDelta)
          .where('lastKnownLatitude', '<=', latitude + latDelta)
          .limit(200)
          .get(),
      ]);
    } catch (e) {
      console.error('User query error:', e);
      return null;
    }

    const candidateDocs = new Map();
    for (const doc of [...usersSnap.docs, ...lastKnownSnap.docs]) {
      candidateDocs.set(doc.id, doc);
    }

    const targets = [...candidateDocs.values()].filter((doc) => {
      if (doc.id === requestedBy) return false;

      const coords = getUserCoords(doc.data());
      if (!coords) return false;

      const dist = haversineKm(
        latitude,
        longitude,
        coords.latitude,
        coords.longitude,
      );
      return dist <= radiusKm;
    });

    if (targets.length === 0) {
      console.log('No nearby users found for', locationName);
      await snap.ref.update({ status: 'no_targets' });
      return null;
    }

    const sends = targets.map(async (doc) => {
      const token = doc.data().fcmToken || (await getFcmToken(doc.id));
      if (!token) return;
      await sendFcm(
        token,
        'Peep Request Nearby',
        body,
        {
          type: 'crowdsource_request',
          locationName,
          latitude: String(latitude),
          longitude: String(longitude),
          requestId: context.params.requestId,
        },
      );
    });

    await Promise.all(sends);

    await snap.ref.update({
      status: 'sent',
      targetCount: targets.length,
      sentAt: FieldValue.serverTimestamp(),
    });

    console.log(
      `Sent crowdsource request for ${locationName} to ${targets.length} users.`,
    );
    return null;
  });

// ─── FUNCTION 2: onPresenceCreated ─────────────────────────────────────────
// Fires when a user checks in (presence doc created). Fulfills waiting
// crowdsource_requests with status=waiting and notifyOnArrival=true nearby.
//
// FIRESTORE INDEX REQUIRED (create in Firebase Console if not auto-suggested):
//   Collection: crowdsource_requests
//   Fields: status ASC, notifyOnArrival ASC, latitude ASC
exports.onPresenceCreated = functions.firestore
  .document('presence/{presenceId}')
  .onCreate(async (snap, context) => {
    const presence = snap.data();
    const { latitude, longitude, locationName, userId, uid } = presence;
    const arrivedUserId = userId || uid || context.params.presenceId;

    if (!latitude || !longitude) {
      console.log('onPresenceCreated: missing coords, skipping');
      return null;
    }

    // Find waiting crowdsource requests near this location
    // within ~150 meters (0.00135 degrees)
    const delta = 0.00135;
    let waitingSnap;
    try {
      waitingSnap = await db.collection('crowdsource_requests')
        .where('status', '==', 'waiting')
        .where('notifyOnArrival', '==', true)
        .where('latitude', '>=', latitude - delta)
        .where('latitude', '<=', latitude + delta)
        .get();
    } catch (e) {
      console.error('onPresenceCreated waiting query error:', e);
      return null;
    }

    if (waitingSnap.empty) {
      console.log('onPresenceCreated: no waiting requests near', locationName);
      return null;
    }

    const batch = db.batch();
    const fcmPromises = [];

    for (const doc of waitingSnap.docs) {
      const request = doc.data();

      // Longitude check client-side (Firestore only allows one range filter)
      const lngDiff = Math.abs((request.longitude || 0) - longitude);
      if (lngDiff > delta) continue;

      const requesterId = request.requesterId || request.requestedBy;
      if (!requesterId) continue;

      const fcmToken = await getFcmToken(requesterId);
      if (!fcmToken) continue;

      // Send FCM notification to requester
      fcmPromises.push(
        messaging.send({
          token: fcmToken,
          notification: {
            title: '📍 Someone just arrived!',
            body: `A user just checked in at ${locationName || request.locationName}. ` +
                  'Tap to get a live crowd update.',
          },
          data: {
            type: 'arrival_fulfilled',
            locationName: locationName || request.locationName || '',
            latitude: String(latitude),
            longitude: String(longitude),
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        }).catch((err) =>
          console.error('FCM send error for', requesterId, err),
        ),
      );

      // Mark request as fulfilled
      batch.update(doc.ref, {
        status: 'fulfilled',
        fulfilledAt: FieldValue.serverTimestamp(),
        fulfilledByUserId: arrivedUserId || null,
      });
    }

    await Promise.all(fcmPromises);
    if (fcmPromises.length > 0) {
      await batch.commit();
    }

    console.log(
      `onPresenceCreated: fulfilled ${fcmPromises.length} waiting requests near`,
      locationName,
    );
    return null;
  });

// ─── FUNCTION 3: onLikeCreated ──────────────────────────────────────────────
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

// ─── FUNCTION 4: onNewPost ─────────────────────────────────────────────────
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
