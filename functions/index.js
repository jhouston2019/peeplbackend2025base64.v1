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

// ─── HELPER: derive locations doc id from venue name ───────────────────────
function generateLocationId(locationName) {
  return locationName
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '_')
    .substring(0, 100);
}

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

    if (dailySnap.size >= 3) {
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

    while (true) {
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
      if (snapshot.docs.length < batchSize) break;
    }

    return res.json({ processed, created, updated });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});
