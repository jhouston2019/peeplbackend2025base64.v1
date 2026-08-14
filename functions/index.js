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

function normalizeLocationName(name) {
  return (name || '').trim().toLowerCase();
}

function locationNamesMatch(a, b) {
  const left = normalizeLocationName(a);
  const right = normalizeLocationName(b);
  return left.length > 0 && left === right;
}

function isValidCoord(lat, lng) {
  if (lat == null || lng == null) return false;
  if (lat === 0 && lng === 0) return false;
  if (Math.abs(lat) > 90 || Math.abs(lng) > 180) return false;
  return true;
}

async function resolveCoordsForLocationName(locationName) {
  try {
    const postsSnap = await db
      .collection('location_posts')
      .where('locationName', '==', locationName)
      .orderBy('timestamp', 'desc')
      .limit(1)
      .get();
    if (!postsSnap.empty) {
      const post = postsSnap.docs[0].data();
      if (isValidCoord(post.latitude, post.longitude)) {
        return { latitude: post.latitude, longitude: post.longitude };
      }
    }
  } catch (e) {
    console.error('resolveCoords posts query error:', e);
  }

  try {
    const locSnap = await db
      .collection('locations')
      .where('locationName', '==', locationName)
      .limit(1)
      .get();
    if (!locSnap.empty) {
      const loc = locSnap.docs[0].data();
      const lat = loc.latitude ?? loc.lat;
      const lng = loc.longitude ?? loc.lng;
      if (isValidCoord(lat, lng)) {
        return { latitude: lat, longitude: lng };
      }
    }
  } catch (e) {
    console.error('resolveCoords locations query error:', e);
  }

  return null;
}

async function findActiveCrowdsourceRequests(locationName, latitude, longitude) {
  const active = [];
  const seen = new Set();

  try {
    const byName = await db
      .collection('crowdsource_requests')
      .where('locationName', '==', locationName)
      .where('fulfilled', '==', false)
      .where('expiresAt', '>', Timestamp.now())
      .limit(25)
      .get();

    for (const doc of byName.docs) {
      const data = doc.data();
      const status = data.status;
      if (
        status === 'pending' ||
        status === 'sent' ||
        status === 'no_targets' ||
        status === 'no_fcm_tokens'
      ) {
        seen.add(doc.id);
        active.push({ id: doc.id, ...data });
      }
    }
  } catch (e) {
    console.error('findActiveCrowdsourceRequests byName error:', e);
  }

  if (isValidCoord(latitude, longitude)) {
    const radiusKm = 1;
    const latDelta = radiusKm / 111;
    try {
      const byGeo = await db
        .collection('crowdsource_requests')
        .where('fulfilled', '==', false)
        .where('expiresAt', '>', Timestamp.now())
        .where('latitude', '>=', latitude - latDelta)
        .where('latitude', '<=', latitude + latDelta)
        .limit(50)
        .get();

      for (const doc of byGeo.docs) {
        if (seen.has(doc.id)) continue;
        const data = doc.data();
        const status = data.status;
        if (
          status !== 'pending' &&
          status !== 'sent' &&
          status !== 'no_targets' &&
          status !== 'no_fcm_tokens'
        ) {
          continue;
        }
        const dist = haversineKm(
          latitude,
          longitude,
          data.latitude,
          data.longitude,
        );
        if (dist <= radiusKm) {
          seen.add(doc.id);
          active.push({ id: doc.id, ...data });
        }
      }
    } catch (e) {
      console.error('findActiveCrowdsourceRequests byGeo error:', e);
    }
  }

  return active;
}

async function notifyUserOfCrowdsourceRequest(uid, request, requestDocId) {
  if (!uid) return false;
  const token = await getFcmToken(uid);
  if (!token) return false;

  const locationName = request.locationName || 'this location';
  const body =
    request.message ||
    `Someone is curious about ${locationName}, would you mind sharing a peep?`;

  await sendFcm(token, 'Peep Request Nearby', body, {
    type: 'crowdsource_request',
    locationName,
    latitude: String(request.latitude),
    longitude: String(request.longitude),
    requestId: request.requestId || requestDocId,
  });
  return true;
}

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

// ─── FUNCTION 1: onCrowdsourceRequest ──────────────────────────────────────
// Fires when a client writes to crowdsource_requests/{requestId}.
// Notifies postAuthorId directly (Explore Live), active presence check-ins,
// and nearby users via lastKnown* or lastLocation coords.
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
      postAuthorId,
      locationName,
      latitude,
      longitude,
      radiusKm = 1,
      message,
      expiresAt,
      source,
    } = data;

    if (expiresAt) {
      const expiresMs =
        typeof expiresAt.toMillis === 'function'
          ? expiresAt.toMillis()
          : expiresAt._seconds * 1000;
      if (Date.now() > expiresMs) {
        await snap.ref.update({ status: 'expired' });
        await db.collection('growth_events').add({
          eventName: 'growth_peep_request_expired',
          properties: {
            requestId: context.params.requestId,
            locationName: locationName || '',
            userId: requestedBy || '',
            timestamp: new Date().toISOString(),
          },
          userId: requestedBy || null,
          timestamp: FieldValue.serverTimestamp(),
          appVersion: 'cloud_function',
          platform: 'server',
        });
        console.log('Crowdsource request expired:', context.params.requestId);
        return null;
      }
    }

    if (source) {
      console.log('Crowdsource request source:', source);
    }

    if (latitude == null || longitude == null || !locationName) {
      console.log('Missing required fields, skipping.');
      return null;
    }

    let lat = latitude;
    let lng = longitude;
    if (!isValidCoord(lat, lng)) {
      const resolved = await resolveCoordsForLocationName(locationName);
      if (resolved) {
        lat = resolved.latitude;
        lng = resolved.longitude;
        await snap.ref.update({
          latitude: lat,
          longitude: lng,
          coordsResolved: true,
        });
      } else {
        await snap.ref.update({ status: 'error', error: 'invalid_coordinates' });
        return null;
      }
    }

    const latDelta = radiusKm / 111;
    const lngDelta = radiusKm / (111 * Math.cos((lat * Math.PI) / 180));
    const body =
      message ||
      `Someone is curious about ${locationName}, would you mind sharing a peep?`;
    const requestId = context.params.requestId;
    const fcmData = {
      type: 'crowdsource_request',
      locationName,
      latitude: String(lat),
      longitude: String(lng),
      requestId,
    };

    const targetIds = new Set();
    if (postAuthorId && postAuthorId !== requestedBy) {
      targetIds.add(postAuthorId);
    }

    let usersSnap;
    let lastKnownSnap;
    let presenceSnap;
    let presenceByNameSnap;
    let recentPostsSnap;
    try {
      [usersSnap, lastKnownSnap, presenceSnap, presenceByNameSnap, recentPostsSnap] =
        await Promise.all([
        db
          .collection(USERS_COLLECTION)
          .where('lastLocation.latitude', '>=', lat - latDelta)
          .where('lastLocation.latitude', '<=', lat + latDelta)
          .limit(200)
          .get(),
        db
          .collection(USERS_COLLECTION)
          .where('lastKnownLatitude', '>=', lat - latDelta)
          .where('lastKnownLatitude', '<=', lat + latDelta)
          .limit(200)
          .get(),
        db
          .collection('presence')
          .where('latitude', '>=', lat - latDelta)
          .where('latitude', '<=', lat + latDelta)
          .where('expiresAt', '>', Timestamp.now())
          .limit(100)
          .get(),
        db
          .collection('presence')
          .where('locationName', '==', locationName)
          .where('expiresAt', '>', Timestamp.now())
          .limit(50)
          .get(),
        db
          .collection('location_posts')
          .where('locationName', '==', locationName)
          .orderBy('timestamp', 'desc')
          .limit(25)
          .get(),
      ]);
    } catch (e) {
      console.error('Target query error:', e);
      if (targetIds.size === 0) {
        await snap.ref.update({ status: 'error', error: 'target_query_failed' });
        return null;
      }
      usersSnap = { docs: [] };
      lastKnownSnap = { docs: [] };
      presenceSnap = { docs: [] };
      presenceByNameSnap = { docs: [] };
      recentPostsSnap = { docs: [] };
    }

    for (const doc of [...usersSnap.docs, ...lastKnownSnap.docs]) {
      if (doc.id === requestedBy) continue;

      const coords = getUserCoords(doc.data());
      if (!coords) continue;

      const dist = haversineKm(lat, lng, coords.latitude, coords.longitude);
      if (dist <= radiusKm) {
        targetIds.add(doc.id);
      }
    }

    for (const doc of [...presenceSnap.docs, ...presenceByNameSnap.docs]) {
      const presence = doc.data();
      const uid = presence.uid || presence.userId || doc.id;
      if (!uid || uid === requestedBy) continue;

      const pLat = presence.latitude;
      const pLng = presence.longitude;
      const nameMatch = locationNamesMatch(presence.locationName, locationName);
      let withinRadius = false;
      if (pLat != null && pLng != null) {
        if (pLng >= lng - lngDelta && pLng <= lng + lngDelta) {
          withinRadius = haversineKm(lat, lng, pLat, pLng) <= radiusKm;
        }
      }
      if (nameMatch || withinRadius) {
        targetIds.add(uid);
      }
    }

    for (const doc of recentPostsSnap.docs) {
      const posterId = doc.data().userId;
      if (posterId && posterId !== requestedBy) {
        targetIds.add(posterId);
      }
    }

    if (targetIds.size === 0) {
      console.log('No targets found for', locationName);
      await snap.ref.update({ status: 'no_targets' });
      return null;
    }

    const sends = [...targetIds].map(async (uid) => {
      const userSnap = await db.collection(USERS_COLLECTION).doc(uid).get();
      const token =
        (userSnap.exists && userSnap.data()?.fcmToken) ||
        (await getFcmToken(uid));
      if (!token) return false;
      await sendFcm(token, 'Peep Request Nearby', body, fcmData);
      return true;
    });

    const sendResults = await Promise.all(sends);
    const sentCount = sendResults.filter(Boolean).length;

    await snap.ref.update({
      status: sentCount > 0 ? 'sent' : 'no_fcm_tokens',
      targetCount: targetIds.size,
      sentCount,
      sentAt: FieldValue.serverTimestamp(),
    });

    console.log(
      `Crowdsource request for ${locationName}: ${sentCount}/${targetIds.size} notified.`,
    );
    return null;
  });

// ─── FUNCTION 2: onPresenceCreated ─────────────────────────────────────────
// Fires when a user checks in or refreshes presence.
// 1) Notifies the checked-in user about active peep requests at that venue.
// 2) Legacy: fulfills waiting crowdsource_requests with notifyOnArrival.
exports.onPresenceCreated = functions.firestore
  .document('presence/{presenceId}')
  .onWrite(async (change, context) => {
    if (!change.after.exists) return null;

    const presence = change.after.data();
    const { latitude, longitude, locationName, userId, uid } = presence;
    const arrivedUserId = userId || uid || context.params.presenceId;

    if (!latitude || !longitude) {
      console.log('onPresenceCreated: missing coords, skipping');
      return null;
    }

    const expiresAt = presence.expiresAt;
    if (expiresAt) {
      const expiresMs =
        typeof expiresAt.toMillis === 'function'
          ? expiresAt.toMillis()
          : expiresAt._seconds * 1000;
      if (Date.now() > expiresMs) {
        return null;
      }
    }

    const isFreshCheckIn =
      !change.before.exists ||
      !locationNamesMatch(change.before.data()?.locationName, locationName);

    if (isFreshCheckIn && arrivedUserId && locationName) {
      try {
        const activeRequests = await findActiveCrowdsourceRequests(
          locationName,
          latitude,
          longitude,
        );
        let notified = 0;
        for (const request of activeRequests) {
          if (request.requestedBy === arrivedUserId) continue;
          const sent = await notifyUserOfCrowdsourceRequest(
            arrivedUserId,
            request,
            request.id,
          );
          if (sent) notified += 1;
        }
        if (notified > 0) {
          console.log(
            `onPresenceCreated: notified ${arrivedUserId} of ${notified} active requests at ${locationName}`,
          );
        }
      } catch (e) {
        console.error('onPresenceCreated active request notify error:', e);
      }
    }

    // Legacy waiting-request fulfillment (notify requester on arrival).
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
      return null;
    }

    const batch = db.batch();
    const fcmPromises = [];

    for (const doc of waitingSnap.docs) {
      const request = doc.data();

      const lngDiff = Math.abs((request.longitude || 0) - longitude);
      if (lngDiff > delta) continue;

      const requesterId = request.requesterId || request.requestedBy;
      if (!requesterId) continue;

      const fcmToken = await getFcmToken(requesterId);
      if (!fcmToken) continue;

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

    await fulfillCrowdsourceRequests({
      postId,
      posterId,
      locationName,
      latitude,
      longitude,
    });

    return null;
  });

async function fulfillCrowdsourceRequests({
  postId,
  posterId,
  locationName,
  latitude,
  longitude,
}) {
  let postSnap;
  try {
    postSnap = await db.collection('location_posts').doc(postId).get();
  } catch (e) {
    console.error('fulfillCrowdsourceRequests post lookup error:', e);
    return;
  }

  const post = postSnap.exists ? postSnap.data() : {};
  const crowdingLevel = post?.crowdingLevel ?? 0;
  const username =
    post?.username || post?.displayName || post?.authorName || 'Someone';

  let pendingSnap;
  try {
    pendingSnap = await db
      .collection('crowdsource_requests')
      .where('locationName', '==', locationName)
      .where('fulfilled', '==', false)
      .where('status', 'in', ['pending', 'sent'])
      .get();
  } catch (e) {
    console.error('fulfillCrowdsourceRequests query error:', e);
    return;
  }

  for (const doc of pendingSnap.docs) {
    const req = doc.data();
    const requesterId = req.requestedBy || req.requesterId;
    if (!requesterId || requesterId === posterId) continue;

    try {
      await db.collection('crowdsource_responses').doc(doc.id).set({
        requestId: doc.id,
        requesterId,
        responderId: posterId,
        responderUsername: username,
        postId,
        locationName,
        latitude,
        longitude,
        crowdingLevel,
        timestamp: FieldValue.serverTimestamp(),
      });

      await doc.ref.update({
        fulfilled: true,
        status: 'fulfilled',
      });

      const levelLabel =
        crowdingLevel <= 4
          ? 'not crowded'
          : crowdingLevel <= 6
            ? 'moderately crowded'
            : 'very crowded';

      const token = await getFcmToken(requesterId);
      if (token) {
        await sendFcm(
          token,
          'Crowd update',
          `${username} just posted about ${locationName} — it's ${levelLabel}! Tap to see.`,
          {
            type: 'crowdsource_response',
            postId,
            requestId: doc.id,
            locationName,
          },
        );
      }
    } catch (e) {
      console.error('fulfillCrowdsourceRequests doc error:', doc.id, e);
    }
  }
}

// ─── HELPER: derive locations doc id from venue name ───────────────────────
function generateLocationId(locationName) {
  return locationName
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '_')
    .substring(0, 100);
}

// ─── CALLABLE: seedLocation ───────────────────────────────────────────────
// Authenticated clients seed the geofence registry after Prompt A locked
// direct `locations` writes. Same schema as PlacesVenueDetector / admin seed.
exports.seedLocation = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required.',
    );
  }

  const payload = data || {};
  const locationName = typeof payload.locationName === 'string'
    ? payload.locationName.trim()
    : '';
  const latitude = payload.latitude;
  const longitude = payload.longitude;
  const crowdingLevel = payload.crowdingLevel;

  if (!locationName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'locationName is required.',
    );
  }
  if (typeof latitude !== 'number' || Number.isNaN(latitude)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'latitude is required.',
    );
  }
  if (typeof longitude !== 'number' || Number.isNaN(longitude)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'longitude is required.',
    );
  }
  if (typeof crowdingLevel !== 'number' || Number.isNaN(crowdingLevel)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'crowdingLevel is required.',
    );
  }

  const locationId = generateLocationId(locationName);
  if (!locationId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Could not derive locationId from locationName.',
    );
  }

  const venueId = payload.venueId != null
    ? String(payload.venueId).trim()
    : '';
  const geofenceRadiusMeters = typeof payload.geofenceRadiusMeters === 'number'
    && !Number.isNaN(payload.geofenceRadiusMeters)
    ? payload.geofenceRadiusMeters
    : 150;
  const isActive = payload.isActive !== false;
  const venueType = typeof payload.venueType === 'string'
    && payload.venueType.trim()
    ? payload.venueType.trim()
    : null;

  const locationRef = db.collection('locations').doc(locationId);
  const locationDoc = await locationRef.get();

  const docData = {
    locationName,
    latitude,
    longitude,
    geofenceRadiusMeters,
    isActive,
    lastPeeped: FieldValue.serverTimestamp(),
    createdBy: context.auth.uid,
    ...(venueId ? { placeId: venueId } : {}),
    ...(venueType ? { venueType } : {}),
  };

  if (!locationDoc.exists) {
    await locationRef.set({
      ...docData,
      createdAt: FieldValue.serverTimestamp(),
      peepCount: 0,
    });
  } else {
    await locationRef.set(docData, { merge: true });
  }

  return { success: true, locationId };
});

// ─── HELPER: upsert locations collection from a location_posts document ────
async function upsertLocationFromPost(postData) {
  const locationName = postData.locationName;
  const latitude = postData.latitude;
  const longitude = postData.longitude;

  if (!locationName || !latitude || !longitude) {
    return { created: false, updated: false };
  }

  const locationId = generateLocationId(locationName);
  if (!locationId) {
    return { created: false, updated: false };
  }

  const locationRef = db.collection('locations').doc(locationId);
  const locationDoc = await locationRef.get();

  if (!locationDoc.exists) {
    await locationRef.set({
      locationName,
      latitude,
      longitude,
      geofenceRadiusMeters: 150,
      isActive: true,
      createdAt: FieldValue.serverTimestamp(),
      lastPeeped: FieldValue.serverTimestamp(),
      peepCount: 1,
    });
    return { created: true, updated: false };
  }

  await locationRef.update({
    lastPeeped: FieldValue.serverTimestamp(),
    peepCount: FieldValue.increment(1),
  });
  return { created: false, updated: true };
}

// ─── HELPER: crowd anomaly detection for onPostCreated ─────────────────────
async function detectCrowdAnomaly(data, postId) {
  const { latitude, longitude, crowdingLevel, locationName, userId } = data;

  const venueKey = `${Math.round(latitude * 1000) / 1000}_${Math.round(longitude * 1000) / 1000}`;
  const venueRef = db.collection('venue_intelligence').doc(venueKey);
  const venueDoc = await venueRef.get();

  if (!venueDoc.exists) return;

  const venueData = venueDoc.data();
  const totalReports = venueData.totalReports || 0;
  if (totalReports < 5) return;

  const hour = new Date().getHours().toString();
  const hourlyAggregates = venueData.hourlyAggregates || {};
  const hourEntry = hourlyAggregates[hour];
  if (!hourEntry || hourEntry.count < 3) return;

  const hourlyAvg = hourEntry.sum / hourEntry.count;
  const deviation = Math.abs(crowdingLevel - hourlyAvg);

  if (deviation > 3) {
    await db.collection('crowd_anomalies').add({
      postId,
      venueKey,
      locationName,
      latitude,
      longitude,
      reportedScore: crowdingLevel,
      expectedScore: hourlyAvg,
      deviation,
      userId,
      detectedAt: FieldValue.serverTimestamp(),
    });
  }
}

// ─── FUNCTION 5: onPostCreated ────────────────────────────────────────────
// Fires on every new location_posts document. Detects anomalous crowd scores
// against venue hourly baseline and writes to crowd_anomalies when found.
exports.onPostCreated = functions.firestore
  .document('location_posts/{postId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const postId = context.params.postId;
    const { latitude, longitude, crowdingLevel, locationName, userId } = data;

    if (!latitude || !longitude || crowdingLevel === undefined) return null;

    try {
      await detectCrowdAnomaly(data, postId);
    } catch (err) {
      console.error('onPostCreated error:', err);
    }

    try {
      await upsertLocationFromPost(data);
    } catch (err) {
      console.error('onPostCreated locations upsert error:', err);
    }

    return null;
  });

// ─── FUNCTION 6: onPeepCreatedCrowdAlert ───────────────────────────────────
// Separate onCreate trigger for location_posts — does not modify onPostCreated.
// Notifies users who follow a location when crowd level changes meaningfully.
//
// FIRESTORE INDEXES (create in Firebase Console if prompted):
//   location_follows: locationId ASC, alertsEnabled ASC
//   location_follows: locationName ASC, alertsEnabled ASC

const CROWD_ALERT_COOLDOWN_MS = 2 * 60 * 60 * 1000;

function crowdWordLabel(level) {
  const value = Math.max(0, Math.min(10, Number(level) || 0));
  if (value === 0) return 'Empty';
  if (value <= 2) return 'Quiet';
  if (value <= 4) return 'Moderate';
  if (value <= 6) return 'Busy';
  if (value <= 8) return 'Crowded';
  return 'Packed';
}

function shouldSendCrowdAlert(previousLevel, newLevel) {
  if (previousLevel === null || previousLevel === undefined) return true;
  const prev = Number(previousLevel);
  const next = Number(newLevel);
  if (Number.isNaN(prev) || Number.isNaN(next)) return true;
  if (Math.abs(next - prev) >= 3) return true;
  if (next >= 8 && prev < 8) return true;
  if (next <= 3 && prev > 5) return true;
  return false;
}

function isCrowdAlertCooldownExpired(lastAlertedAt) {
  if (!lastAlertedAt) return true;
  const lastMs = typeof lastAlertedAt.toDate === 'function'
    ? lastAlertedAt.toDate().getTime()
    : (lastAlertedAt._seconds ? lastAlertedAt._seconds * 1000 : 0);
  if (!lastMs) return true;
  return Date.now() - lastMs >= CROWD_ALERT_COOLDOWN_MS;
}

async function fetchLocationFollowers(locationId, locationName) {
  const seen = new Map();

  if (locationId) {
    const byId = await db.collection('location_follows')
      .where('locationId', '==', locationId)
      .where('alertsEnabled', '==', true)
      .get();
    for (const doc of byId.docs) {
      seen.set(doc.id, doc);
    }
  }

  if (locationName) {
    const byName = await db.collection('location_follows')
      .where('locationName', '==', locationName)
      .where('alertsEnabled', '==', true)
      .get();
    for (const doc of byName.docs) {
      seen.set(doc.id, doc);
    }
  }

  return [...seen.values()];
}

exports.onPeepCreatedCrowdAlert = functions.firestore
  .document('location_posts/{postId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const postId = context.params.postId;
    const {
      locationName,
      crowdingLevel,
      userId: posterId,
      venueId,
      locationId: postLocationId,
    } = data;

    if (!locationName || crowdingLevel === undefined || crowdingLevel === null) {
      return null;
    }

    const resolvedLocationId = venueId || postLocationId || locationName;

    try {
      const followerDocs = await fetchLocationFollowers(
        resolvedLocationId,
        locationName,
      );

      if (followerDocs.length === 0) {
        return null;
      }

      const label = crowdWordLabel(crowdingLevel);
      const title = `${locationName} update 👀`;
      const body = `Now ${crowdingLevel}/10 — ${label}`;

      const sends = followerDocs.map(async (followDoc) => {
        const follow = followDoc.data();
        const followerUserId = follow.userId;
        if (!followerUserId) return;
        if (posterId && followerUserId === posterId) return;
        if (!follow.alertsEnabled) return;
        if (!isCrowdAlertCooldownExpired(follow.lastAlertedAt)) return;

        const previousLevel = follow.lastKnownCrowdingLevel;
        if (!shouldSendCrowdAlert(previousLevel, crowdingLevel)) return;

        const token = await getFcmToken(followerUserId);
        if (!token) return;

        await sendFcm(token, title, body, {
          type: 'crowd_change_alert',
          locationName: String(locationName),
          crowdingLevel: String(crowdingLevel),
          peepId: postId,
          postId,
          locationId: String(follow.locationId || resolvedLocationId),
        });

        await followDoc.ref.update({
          lastAlertedAt: FieldValue.serverTimestamp(),
          lastKnownCrowdingLevel: Number(crowdingLevel),
        });

        const prev = previousLevel == null ? null : Number(previousLevel);
        const next = Number(crowdingLevel);
        await db.collection('growth_events').add({
          eventName: 'growth_crowd_alert_sent',
          properties: {
            userId: followerUserId,
            locationId: follow.locationId || resolvedLocationId,
            locationName,
            previousLevel: prev,
            newLevel: next,
            delta: prev == null ? null : Math.abs(next - prev),
            peepId: postId,
            timestamp: new Date().toISOString(),
          },
          userId: followerUserId,
          timestamp: FieldValue.serverTimestamp(),
          appVersion: 'cloud_function',
          platform: 'server',
        });
      });

      await Promise.all(sends);
      return null;
    } catch (err) {
      console.error('onPeepCreatedCrowdAlert error:', err);
      return null;
    }
  });

// ─── FUNCTION 8: onVenueEntryEvent ─────────────────────────────────────────
// Fires when the client writes venue_entry_events (app alive or killed-app
// geofence_entry relay). Sends walk-in FCM push to the entering user.
exports.onVenueEntryEvent = functions.firestore
  .document('venue_entry_events/{eventId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const { userId, venueName, venueId, latitude, longitude, notificationSent } = data;

    if (notificationSent === true) {
      return null;
    }
    if (!userId || !venueName || !venueId) {
      return null;
    }

    const token = await getFcmToken(userId);
    if (!token) {
      console.log('onVenueEntryEvent: no FCM token for', userId);
      return null;
    }

    const cooldownMs = 240 * 60 * 1000;
    const cooldownTs = Timestamp.fromMillis(Date.now() - cooldownMs);

    let recentSnap;
    try {
      recentSnap = await db.collection('venue_entry_events')
        .where('userId', '==', userId)
        .where('venueId', '==', venueId)
        .where('notificationSent', '==', true)
        .where('timestamp', '>', cooldownTs)
        .limit(1)
        .get();
    } catch (e) {
      console.error('onVenueEntryEvent cooldown query error:', e);
      return null;
    }

    if (!recentSnap.empty) {
      console.log('onVenueEntryEvent: suppressed by venue cooldown', userId, venueId);
      return null;
    }

    const startOfToday = new Date();
    startOfToday.setUTCHours(0, 0, 0, 0);
    const startOfTodayTs = Timestamp.fromDate(startOfToday);

    let dailySnap;
    try {
      dailySnap = await db.collection('venue_entry_events')
        .where('userId', '==', userId)
        .where('notificationSent', '==', true)
        .where('timestamp', '>', startOfTodayTs)
        .get();
    } catch (e) {
      console.error('onVenueEntryEvent daily limit query error:', e);
      return null;
    }

    if (dailySnap.size >= 15) {
      console.log('onVenueEntryEvent: suppressed by daily limit', userId);
      return null;
    }

    const title = 'You just walked in 👀';
    const body = `How's ${venueName} right now?`;

    try {
      await messaging.send({
        token,
        notification: { title, body },
        data: {
          type: 'walk_in_prompt',
          venueName: String(venueName),
          venueId: String(venueId),
          latitude: String(latitude ?? ''),
          longitude: String(longitude ?? ''),
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
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

      await snap.ref.update({ notificationSent: true });
    } catch (e) {
      const code = e.code || (e.errorInfo && e.errorInfo.code);
      if (code === 'messaging/registration-token-not-registered') {
        await db.collection(USERS_COLLECTION).doc(userId).update({
          fcmToken: FieldValue.delete(),
        });
      }
      console.error('onVenueEntryEvent send error:', e);
    }

    return null;
  });

// ─── FUNCTION 7: backfillLocationsFromPosts ────────────────────────────────
// One-time HTTP trigger to populate locations from existing location_posts.
exports.backfillLocationsFromPosts = functions.https.onRequest(async (req, res) => {
  const secret = req.query.secret || req.body.secret;
  if (secret !== 'peepl_backfill_2026') {
    return res.status(403).json({ error: 'Forbidden' });
  }

  try {
    let processed = 0;
    let created = 0;
    let updated = 0;
    let lastDoc = null;
    const batchSize = 100;

    let hasMore = true;
    while (hasMore) {
      let query = db.collection('location_posts')
        .limit(batchSize);
      if (lastDoc) query = query.startAfter(lastDoc);

      const snapshot = await query.get();
      if (snapshot.empty) break;

      for (const doc of snapshot.docs) {
        const data = doc.data();
        const locationName = data.locationName;
        const latitude = data.latitude;
        const longitude = data.longitude;

        if (!locationName || !latitude || !longitude) continue;

        processed++;
        const locationId = locationName
          .toLowerCase()
          .replace(/[^a-z0-9]/g, '_')
          .substring(0, 100);

        const locationRef = db.collection('locations').doc(locationId);
        const locationDoc = await locationRef.get();

        if (!locationDoc.exists) {
          await locationRef.set({
            locationName, latitude, longitude,
            geofenceRadiusMeters: 150,
            isActive: true,
            createdAt: FieldValue.serverTimestamp(),
            lastPeeped: FieldValue.serverTimestamp(),
            peepCount: 1,
          });
          created++;
        } else {
          await locationRef.update({
            lastPeeped: FieldValue.serverTimestamp(),
            peepCount: FieldValue.increment(1),
          });
          updated++;
        }
      }

      lastDoc = snapshot.docs[snapshot.docs.length - 1];
      hasMore = snapshot.docs.length >= batchSize;
    }

    return res.json({ processed, created, updated });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// ─── FUNCTION: onPeepViewRecorded (Phase 5) ────────────────────────────────
// When helpedCount increases on a location_post, increment totalImpact on
// the post author's user document by the delta.
exports.onPeepViewRecorded = functions.firestore
  .document('location_posts/{postId}')
  .onUpdate(async (change) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};

    const beforeCount = typeof before.helpedCount === 'number' ? before.helpedCount : 0;
    const afterCount = typeof after.helpedCount === 'number' ? after.helpedCount : 0;
    const delta = afterCount - beforeCount;

    if (delta <= 0) return null;

    const userId = after.userId;
    if (!userId) return null;

    await db.collection(USERS_COLLECTION).doc(userId).set(
      { totalImpact: FieldValue.increment(delta) },
      { merge: true },
    );

    return null;
  });

// ─── FUNCTION: sendReengagementPush (Phase 9) ──────────────────────────────
// Daily 6 PM ET — nudge inactive users (7+ days) with FCM, max 500 per run.
exports.sendReengagementPush = functions.pubsub
  .schedule('0 18 * * *')
  .timeZone('America/New_York')
  .onRun(async () => {
    const nowMs = Date.now();
    const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
    const inactiveBefore = Timestamp.fromMillis(nowMs - sevenDaysMs);
    const pushCooldownBefore = Timestamp.fromMillis(nowMs - sevenDaysMs);

    const snap = await db
      .collection(USERS_COLLECTION)
      .where('lastActive', '<', inactiveBefore)
      .limit(500)
      .get();

    let sent = 0;

    for (const doc of snap.docs) {
      if (sent >= 500) break;

      const data = doc.data();
      const token = data.fcmToken;
      if (!token || typeof token !== 'string' || token.trim() === '') continue;

      const lastPush = data.lastReengagementPush;
      if (lastPush) {
        const lastPushMs =
          typeof lastPush.toMillis === 'function'
            ? lastPush.toMillis()
            : lastPush._seconds * 1000;
        if (lastPushMs > pushCooldownBefore.toMillis()) continue;
      }

      await sendFcm(
        token,
        'Going out tonight?',
        "See what's live around you.",
        { type: 'reengagement' },
      );

      await doc.ref.set(
        { lastReengagementPush: FieldValue.serverTimestamp() },
        { merge: true },
      );
      sent += 1;
    }

    console.log(`sendReengagementPush: sent ${sent} notifications`);
    return null;
  });
