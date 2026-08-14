require('dotenv').config();

const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
// const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

// ── Billing constants ────────────────────────────────────────────────────────
// Flat hourly rates in USD (charged upfront at booking time).
const FLAT_RATE_HOURLY = { basic: 9.99, standard: 19.99, premium: 39.99 };
// CPM rates in USD per 1 000 impressions (charged post-run against actuals).
const CPM_RATE = { basic: 5.0, standard: 8.0, premium: 12.0 };
// Estimated impressions per hour per tier — used for CPM upfront estimate only.
const CPM_EST_HOURLY = { basic: 200, standard: 500, premium: 1200 };

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

const USERS_COLLECTION = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

async function getFcmToken(uid) {
  const firestorePath = `${USERS_COLLECTION}/${uid}`;
  try {
    console.log(`[FCM] Reading token from ${firestorePath}`);
    const doc = await admin.firestore().collection(USERS_COLLECTION).doc(uid).get();
    if (!doc.exists) {
      console.warn(`[FCM] No user document at ${firestorePath}`);
      return null;
    }
    const token = doc.data().fcmToken;
    if (!token) {
      console.warn(`[FCM] No FCM token stored at ${firestorePath}`);
      return null;
    }
    return token;
  } catch (err) {
    console.warn('[FCM] getFcmToken error for', firestorePath, ':', err.message);
    return null;
  }
}

const app = express();

app.use(cors());

// ── Stripe webhook ───────────────────────────────────────────────────────────
// IMPORTANT: This route MUST be registered before app.use(express.json()).
// Stripe signature verification requires the raw (unparsed) request body.
// Using express.json() first would parse + re-stringify the body, breaking
// the HMAC check.
// app.post(
//   '/merchant/payment-confirmed',
//   express.raw({ type: 'application/json' }),
//   async (req, res) => {
//     const sig = req.headers['stripe-signature'];
//     if (!sig || !process.env.STRIPE_WEBHOOK_SECRET) {
//       return res.status(400).json({ error: 'Missing Stripe signature or secret' });
//     }
//
//     let event;
//     try {
//       event = stripe.webhooks.constructEvent(
//         req.body,
//         sig,
//         process.env.STRIPE_WEBHOOK_SECRET,
//       );
//     } catch (err) {
//       console.error('[Stripe] Webhook signature verification failed:', err.message);
//       return res.status(400).json({ error: `Webhook Error: ${err.message}` });
//     }
//
//     if (!admin.apps.length) return res.status(503).json({ error: 'Firebase Admin not initialised' });
//     const db = admin.firestore();
//
//     if (event.type === 'payment_intent.succeeded') {
//       const intent = event.data.object;
//       const { adId, merchantId, tier, durationHours } = intent.metadata;
//       try {
//         const now = admin.firestore.Timestamp.now();
//         const endDate = new Date();
//         endDate.setHours(endDate.getHours() + parseInt(durationHours, 10));
//
//         await db.collection('native_ads').doc(adId).update({
//           isActive: true,
//           startDate: now,
//           endDate: admin.firestore.Timestamp.fromDate(endDate),
//           billing_status: 'paid',
//           stripePaymentIntentId: intent.id,
//         });
//
//         await db.collection('merchant_payments').add({
//           adId,
//           merchantId,
//           amount: intent.amount,
//           currency: intent.currency,
//           stripePaymentIntentId: intent.id,
//           status: 'paid',
//           tier,
//           durationHours: parseInt(durationHours, 10),
//           timestamp: now,
//         });
//
//         console.log(`[Stripe] Ad ${adId} activated for merchant ${merchantId}`);
//       } catch (err) {
//         console.error('[Stripe] Post-payment Firestore error:', err.message);
//         // Still return 200 so Stripe doesn't retry — log the error separately.
//       }
//     } else if (event.type === 'payment_intent.payment_failed') {
//       const intent = event.data.object;
//       const { adId } = intent.metadata;
//       try {
//         await db.collection('native_ads').doc(adId).update({
//           billing_status: 'payment_failed',
//         });
//       } catch (err) {
//         console.error('[Stripe] Failed-payment update error:', err.message);
//       }
//     }
//
//     res.json({ received: true });
//   },
// );

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
    if (!token) return res.json({ success: false, reason: 'no_token' });
    const messageId = await admin.messaging().send({
      token,
      notification: { title, body },
      data: { ...data, type: data.type || 'general' },
      android: { notification: { channelId: 'peepl_high_importance', priority: 'high', color: '#1565C0' } },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    });
    console.log(`[FCM] Sent to ${uid} (${USERS_COLLECTION}/${uid}): ${messageId}`);
    res.json({ success: true, messageId });
  } catch (err) {
    console.warn('[FCM] Send error for', uid, ':', err.message);
    res.json({ success: false, reason: 'send_error' });
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
    if (!token) return res.json({ success: false, reason: 'no_token' });
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
    console.log(`[FCM] Like notification sent to ${postOwnerUid} (${USERS_COLLECTION}/${postOwnerUid}): ${messageId}`);
    res.json({ success: true, messageId });
  } catch (err) {
    console.warn('[FCM] Send error for', postOwnerUid, ':', err.message);
    res.json({ success: false, reason: 'send_error' });
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
    if (!token) return res.json({ success: false, reason: 'no_token' });
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
    console.log(`[FCM] Proximity notification sent to ${targetUid} (${USERS_COLLECTION}/${targetUid}): ${messageId}`);
    res.json({ success: true, messageId });
  } catch (err) {
    console.warn('[FCM] Send error for', targetUid, ':', err.message);
    res.json({ success: false, reason: 'send_error' });
  }
});

// ── Merchant billing ─────────────────────────────────────────────────────────

// POST /merchant/create-payment-intent
// Body: { adId, merchantId, durationHours, tier, billing_model? }
// Returns: { clientSecret, amountCents }
// app.post('/merchant/create-payment-intent', async (req, res) => {
//   const { adId, merchantId, durationHours, tier, billing_model = 'flat_rate' } = req.body;
//   if (!adId || !merchantId || !durationHours || !tier) {
//     return res.status(400).json({ error: 'adId, merchantId, durationHours, and tier are required' });
//   }
//
//   if (!process.env.STRIPE_SECRET_KEY) {
//     return res.status(503).json({ error: 'Stripe not configured on this server' });
//   }
//
//   try {
//     let amountCents;
//     if (billing_model === 'cpm') {
//       const estimatedImpressions = (CPM_EST_HOURLY[tier] ?? 200) * durationHours;
//       const rate = CPM_RATE[tier] ?? 5.0;
//       amountCents = Math.max(50, Math.round((estimatedImpressions / 1000) * rate * 100));
//     } else {
//       const hourlyRate = FLAT_RATE_HOURLY[tier] ?? 9.99;
//       amountCents = Math.round(hourlyRate * durationHours * 100);
//     }
//
//     const paymentIntent = await stripe.paymentIntents.create({
//       amount: amountCents,
//       currency: 'usd',
//       automatic_payment_methods: { enabled: true },
//       metadata: {
//         adId,
//         merchantId,
//         tier,
//         durationHours: String(durationHours),
//         billing_model,
//       },
//     });
//
//     console.log(`[Stripe] PaymentIntent created for ad ${adId}: $${(amountCents / 100).toFixed(2)}`);
//     res.json({ clientSecret: paymentIntent.client_secret, amountCents });
//   } catch (err) {
//     console.error('[Stripe] create-payment-intent error:', err.message);
//     res.status(500).json({ error: err.message });
//   }
// });

// GET /merchant/billing-history/:merchantId
// Returns the 50 most recent payment records for a merchant.
// app.get('/merchant/billing-history/:merchantId', async (req, res) => {
//   if (!admin.apps.length) return res.status(503).json({ error: 'Firebase Admin not initialised' });
//   const { merchantId } = req.params;
//   try {
//     const snapshot = await admin.firestore()
//       .collection('merchant_payments')
//       .where('merchantId', '==', merchantId)
//       .orderBy('timestamp', 'desc')
//       .limit(50)
//       .get();
//     const payments = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
//     res.json({ payments });
//   } catch (err) {
//     console.error('[Billing history] Error:', err.message);
//     res.status(500).json({ error: err.message });
//   }
// });

// POST /merchant/run-billing-cron
// Deactivates expired ads and invoices CPM campaigns against actual impressions.
// Trigger this endpoint via Railway's cron scheduler (Settings → Cron Jobs)
// using an Authorization header: Bearer <CRON_SECRET>.
// Recommended schedule: every hour — "0 * * * *"
// app.post('/merchant/run-billing-cron', async (req, res) => {
//   const cronSecret = process.env.CRON_SECRET;
//   if (cronSecret && req.headers['authorization'] !== `Bearer ${cronSecret}`) {
//     return res.status(401).json({ error: 'Unauthorized' });
//   }
//   if (!admin.apps.length) return res.status(503).json({ error: 'Firebase Admin not initialised' });
//
//   try {
//     const db = admin.firestore();
//     const now = admin.firestore.Timestamp.now();
//
//     const expiredSnap = await db.collection('native_ads')
//       .where('isActive', '==', true)
//       .where('endDate', '<=', now)
//       .get();
//
//     let invoiced = 0;
//     for (const doc of expiredSnap.docs) {
//       const ad = doc.data();
//       try {
//         if (ad.billing_model === 'cpm' && ad.stripeCustomerId) {
//           const impressions = ad.impressions ?? 0;
//           const rate = CPM_RATE[ad.tier] ?? 5.0;
//           const finalCharge = Math.max(50, Math.round((impressions / 1000) * rate * 100));
//           await stripe.paymentIntents.create({
//             amount: finalCharge,
//             currency: 'usd',
//             customer: ad.stripeCustomerId,
//             confirm: true,
//             off_session: true,
//             metadata: { adId: doc.id, merchantId: ad.advertiserId, type: 'cpm_final' },
//           });
//           await db.collection('merchant_payments').add({
//             adId: doc.id,
//             merchantId: ad.advertiserId,
//             amount: finalCharge,
//             currency: 'usd',
//             billing_model: 'cpm',
//             impressions,
//             status: 'invoiced',
//             timestamp: now,
//           });
//         }
//         await doc.ref.update({ isActive: false, billing_status: 'invoiced' });
//         invoiced++;
//       } catch (err) {
//         console.error(`[Cron] Failed to process ad ${doc.id}:`, err.message);
//       }
//     }
//
//     console.log(`[Cron] Billing run complete — ${invoiced} ads invoiced`);
//     res.json({ invoiced });
//   } catch (err) {
//     console.error('[Cron] Error:', err.message);
//     res.status(500).json({ error: err.message });
//   }
// });

// ── Growth Phase 4: Peep web preview + deep link association files ───────────

const PEEPL_SHARE_HOST = 'peepl2025v1-production.up.railway.app';
const APP_STORE_URL = 'https://apps.apple.com/app/peepl/id6747926332';
const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.peepl.app';
const APPLE_TEAM_ID = 'MJZ3VHZ23U';
const APPLE_BUNDLE_ID = 'com.peepl.app';
// TODO: Replace with release keystore SHA-256 fingerprint for Android App Links.
const ANDROID_SHA256_FINGERPRINT = 'SHA256_FINGERPRINT_PLACEHOLDER';

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function crowdLabel(level) {
  const value = Math.max(0, Math.min(10, Number(level) || 0));
  if (value === 0) return 'Empty';
  if (value <= 2) return 'Quiet';
  if (value <= 4) return 'Moderate';
  if (value <= 6) return 'Busy';
  if (value <= 8) return 'Crowded';
  return 'Packed';
}

function crowdBadgeColor(level) {
  const value = Math.max(0, Math.min(10, Number(level) || 0));
  if (value <= 4) return '#4CAF50';
  if (value <= 7) return '#FFA726';
  return '#FF5722';
}

function minutesAgoLabel(timestamp) {
  if (!timestamp) return 'recently';
  let date;
  if (typeof timestamp.toDate === 'function') {
    date = timestamp.toDate();
  } else if (timestamp instanceof Date) {
    date = timestamp;
  } else if (timestamp._seconds != null) {
    date = new Date(timestamp._seconds * 1000);
  } else {
    return 'recently';
  }
  const minutes = Math.max(0, Math.floor((Date.now() - date.getTime()) / 60000));
  if (minutes < 1) return 'just now';
  if (minutes === 1) return '1 minute ago';
  return `${minutes} minutes ago`;
}

function detectStorePlatform(userAgent) {
  const ua = String(userAgent || '').toLowerCase();
  if (/iphone|ipad|ipod/.test(ua)) return 'ios';
  if (/android/.test(ua)) return 'android';
  return 'desktop';
}

function renderPreviewPage({
  venueName,
  crowdingLevel,
  crowdLabelText,
  minutesLabel,
  imageUrl,
  storePlatform,
}) {
  const safeVenue = escapeHtml(venueName);
  const safeLabel = escapeHtml(crowdLabelText);
  const safeMinutes = escapeHtml(minutesLabel);
  const safeImageUrl = imageUrl ? escapeHtml(imageUrl) : '';
  const badgeColor = crowdBadgeColor(crowdingLevel);
  const level = Math.max(0, Math.min(10, Number(crowdingLevel) || 0));

  let ctaHtml;
  if (storePlatform === 'ios') {
    ctaHtml = `<a class="cta" href="${APP_STORE_URL}">See what's happening around you</a>`;
  } else if (storePlatform === 'android') {
    ctaHtml = `<a class="cta" href="${PLAY_STORE_URL}">See what's happening around you</a>`;
  } else {
    ctaHtml = `
      <a class="cta" href="${APP_STORE_URL}">Get Peepl on the App Store</a>
      <a class="cta secondary" href="${PLAY_STORE_URL}">Get Peepl on Google Play</a>`;
  }

  const imageBlock = safeImageUrl
    ? `<img class="hero" src="${safeImageUrl}" alt="${safeVenue}">`
    : '';

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${safeVenue} — Peepl</title>
  <meta property="og:title" content="${safeVenue} — Peepl">
  <meta property="og:description" content="${safeLabel} right now. ${level}/10">
  ${safeImageUrl ? `<meta property="og:image" content="${safeImageUrl}">` : ''}
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: #f5f5f5;
      color: #212121;
      line-height: 1.4;
      min-height: 100vh;
    }
    .wrap { max-width: 480px; margin: 0 auto; padding: 24px 20px 40px; }
    .logo { color: #1565C0; font-size: 22px; font-weight: 700; margin-bottom: 20px; }
    .card {
      background: #fff;
      border-radius: 16px;
      padding: 20px;
      box-shadow: 0 2px 12px rgba(0,0,0,0.06);
    }
    .venue { font-size: 26px; font-weight: 700; margin-bottom: 14px; }
    .crowd-row { display: flex; align-items: center; gap: 12px; margin-bottom: 8px; }
    .badge {
      width: 44px; height: 44px; border-radius: 50%;
      display: flex; align-items: center; justify-content: center;
      color: #fff; font-weight: 800; font-size: 18px;
    }
    .crowd-label { font-size: 18px; font-weight: 600; }
    .time { color: #757575; font-size: 14px; margin-bottom: 16px; }
    .hero {
      width: 100%; max-height: 300px; object-fit: cover;
      border-radius: 12px; margin-bottom: 20px; display: block;
    }
    .cta {
      display: block; text-align: center; text-decoration: none;
      background: #1565C0; color: #fff; font-weight: 700;
      padding: 14px 18px; border-radius: 12px; margin-top: 12px;
    }
    .cta.secondary { background: #fff; color: #1565C0; border: 2px solid #1565C0; }
    .footer { text-align: center; color: #9e9e9e; font-size: 12px; margin-top: 24px; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="logo">Peepl</div>
    <div class="card">
      <div class="venue">${safeVenue}</div>
      <div class="crowd-row">
        <div class="badge" style="background:${badgeColor}">${level}</div>
        <div class="crowd-label">${safeLabel}</div>
      </div>
      <div class="time">Peeped ${safeMinutes}</div>
      ${imageBlock}
      ${ctaHtml}
    </div>
    <div class="footer">Real-time crowd levels, wherever you go.</div>
  </div>
</body>
</html>`;
}

function minutesFromIsoString(iso) {
  if (!iso) return 'recently';
  try {
    const date = new Date(iso);
    const minutes = Math.max(0, Math.floor((Date.now() - date.getTime()) / 60000));
    if (minutes < 1) return 'just now';
    if (minutes === 1) return '1 min ago';
    return `${minutes} min ago`;
  } catch (err) {
    return 'recently';
  }
}

function isExpiredFirestoreTimestamp(expiresAt) {
  if (!expiresAt) return false;
  const ms = typeof expiresAt.toMillis === 'function'
    ? expiresAt.toMillis()
    : expiresAt._seconds * 1000;
  return Date.now() > ms;
}

function renderGroupComparisonPage({ venues, storePlatform }) {
  const list = Array.isArray(venues) ? venues : [];
  const safeVenues = list.map((v) => {
    const level = v.crowdingLevel != null
      ? Math.max(0, Math.min(10, Number(v.crowdingLevel) || 0))
      : null;
    return {
      name: escapeHtml(v.locationName || 'Venue'),
      level,
      label: escapeHtml(
        v.crowdLabel || (level != null ? crowdLabel(level) : 'No recent data'),
      ),
      minutes: escapeHtml(minutesFromIsoString(v.lastPeeped)),
      badgeColor: level != null ? crowdBadgeColor(level) : '#9E9E9E',
    };
  });

  const ogDescription = safeVenues
    .map((v) => (v.level != null ? `${v.name} ${v.level}/10` : v.name))
    .join(' vs ');

  const cardsHtml = safeVenues.map((v) => {
    const badge = v.level != null
      ? `<div class="badge" style="background:${v.badgeColor}">${v.level}</div>`
      : '<div class="badge stale">—</div>';
    return `
      <div class="card venue-card">
        <div class="venue">${v.name}</div>
        <div class="crowd-row">
          ${badge}
          <div class="crowd-label">${v.label}</div>
        </div>
        <div class="time">Last updated ${v.minutes}</div>
      </div>`;
  }).join('');

  let ctaHtml;
  if (storePlatform === 'ios') {
    ctaHtml = `<a class="cta" href="${APP_STORE_URL}">See live crowd data → Get Peepl</a>`;
  } else if (storePlatform === 'android') {
    ctaHtml = `<a class="cta" href="${PLAY_STORE_URL}">See live crowd data → Get Peepl</a>`;
  } else {
    ctaHtml = `
      <a class="cta" href="${APP_STORE_URL}">See live crowd data → Get Peepl</a>
      <a class="cta secondary" href="${PLAY_STORE_URL}">Get Peepl on Google Play</a>`;
  }

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Where should we go? — Peepl</title>
  <meta property="og:title" content="Where should we go?">
  <meta property="og:description" content="${escapeHtml(ogDescription)}">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: #f5f5f5;
      color: #212121;
      line-height: 1.4;
      min-height: 100vh;
    }
    .wrap { max-width: 480px; margin: 0 auto; padding: 24px 20px 40px; }
    .logo { color: #1565C0; font-size: 22px; font-weight: 700; margin-bottom: 12px; }
    .headline { font-size: 24px; font-weight: 700; margin-bottom: 16px; }
    .card {
      background: #fff;
      border-radius: 16px;
      padding: 20px;
      box-shadow: 0 2px 12px rgba(0,0,0,0.06);
      margin-bottom: 12px;
    }
    .venue { font-size: 22px; font-weight: 700; margin-bottom: 12px; }
    .crowd-row { display: flex; align-items: center; gap: 12px; margin-bottom: 8px; }
    .badge {
      width: 44px; height: 44px; border-radius: 50%;
      display: flex; align-items: center; justify-content: center;
      color: #fff; font-weight: 800; font-size: 18px;
    }
    .badge.stale { background: #9E9E9E; }
    .crowd-label { font-size: 18px; font-weight: 600; }
    .time { color: #757575; font-size: 14px; }
    .cta {
      display: block; text-align: center; text-decoration: none;
      background: #1565C0; color: #fff; font-weight: 700;
      padding: 14px 18px; border-radius: 12px; margin-top: 12px;
    }
    .cta.secondary { background: #fff; color: #1565C0; border: 2px solid #1565C0; }
    .footer { text-align: center; color: #9e9e9e; font-size: 12px; margin-top: 24px; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="logo">Peepl</div>
    <div class="headline">Where should we go? 🤔</div>
    ${cardsHtml}
    ${ctaHtml}
    <div class="footer">Real-time crowd levels, wherever you go.</div>
  </div>
</body>
</html>`;
}

function renderSimplePage(title, message, statusCode) {
  const safeTitle = escapeHtml(title);
  const safeMessage = escapeHtml(message);
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${safeTitle}</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #f5f5f5; color: #212121;
      display: flex; align-items: center; justify-content: center;
      min-height: 100vh; padding: 24px; text-align: center;
    }
    h1 { font-size: 22px; margin-bottom: 12px; color: #1565C0; }
    p { color: #616161; }
  </style>
</head>
<body>
  <div>
    <h1>Peepl</h1>
    <p>${safeMessage}</p>
  </div>
</body>
</html>`;
}

async function fetchPeepDocument(peepId) {
  const db = admin.firestore();
  const locationDoc = await db.collection('location_posts').doc(peepId).get();
  if (locationDoc.exists) {
    return { id: locationDoc.id, ...locationDoc.data(), _collection: 'location_posts' };
  }
  const peepDoc = await db.collection('peeps').doc(peepId).get();
  if (peepDoc.exists) {
    return { id: peepDoc.id, ...peepDoc.data(), _collection: 'peeps' };
  }
  return null;
}

function peepTimestamp(data) {
  const ts = data?.timestamp || data?.createdAt || data?.updatedAt;
  if (!ts) return 0;
  if (typeof ts.toDate === 'function') return ts.toDate().getTime();
  if (ts instanceof Date) return ts.getTime();
  if (ts._seconds != null) return ts._seconds * 1000;
  return 0;
}

async function fetchLatestVenuePeep(venueKey) {
  const db = admin.firestore();
  const decoded = decodeURIComponent(venueKey);
  const keysToTry = [...new Set([decoded, venueKey].filter(Boolean))];

  for (const key of keysToTry) {
    const byName = await db.collection('location_posts')
      .where('locationName', '==', key)
      .limit(50)
      .get();
    if (!byName.empty) {
      const latest = byName.docs.sort((a, b) => peepTimestamp(b.data()) - peepTimestamp(a.data()))[0];
      return { id: latest.id, ...latest.data() };
    }

    const byVenueId = await db.collection('location_posts')
      .where('venueId', '==', key)
      .limit(50)
      .get();
    if (!byVenueId.empty) {
      const latest = byVenueId.docs.sort((a, b) => peepTimestamp(b.data()) - peepTimestamp(a.data()))[0];
      return { id: latest.id, ...latest.data() };
    }
  }

  const venueDoc = await db.collection('venues').doc(venueKey).get();
  if (venueDoc.exists) {
    const venue = venueDoc.data();
    const venueName = venue.name || venue.locationName;
    if (venueName) {
      const byVenueName = await db.collection('location_posts')
        .where('locationName', '==', venueName)
        .limit(50)
        .get();
      if (!byVenueName.empty) {
        const latest = byVenueName.docs.sort((a, b) => peepTimestamp(b.data()) - peepTimestamp(a.data()))[0];
        return { id: latest.id, ...latest.data() };
      }
    }
  }

  return null;
}

async function fetchDealDocument(dealId) {
  const db = admin.firestore();
  const nativeDoc = await db.collection('native_ads').doc(dealId).get();
  if (nativeDoc.exists) {
    return { id: nativeDoc.id, ...nativeDoc.data() };
  }
  const merchantDoc = await db.collection('merchant_ads').doc(dealId).get();
  if (merchantDoc.exists) {
    return { id: merchantDoc.id, ...merchantDoc.data() };
  }
  return null;
}

function dealTitleFromDoc(deal) {
  for (const key of ['dealHeadline', 'discount', 'subtitle', 'bodyText', 'body', 'headline', 'title']) {
    const value = deal[key];
    if (value && String(value).trim()) return String(value).trim();
  }
  return 'Special offer';
}

function dealVenueNameFromDoc(deal) {
  for (const key of ['advertiser', 'businessName', 'venueName', 'headline', 'title', 'brandName']) {
    const value = deal[key];
    if (value && String(value).trim()) return String(value).trim();
  }
  return 'Local venue';
}

function renderDealPreviewPage({
  dealTitle,
  venueName,
  description,
  imageUrl,
  storePlatform,
}) {
  const safeTitle = escapeHtml(dealTitle);
  const safeVenue = escapeHtml(venueName);
  const safeDescription = escapeHtml(description);
  const safeImageUrl = imageUrl ? escapeHtml(imageUrl) : '';

  let ctaHtml;
  if (storePlatform === 'ios') {
    ctaHtml = `<a class="cta" href="${APP_STORE_URL}">See what's happening around you</a>`;
  } else if (storePlatform === 'android') {
    ctaHtml = `<a class="cta" href="${PLAY_STORE_URL}">See what's happening around you</a>`;
  } else {
    ctaHtml = `
      <a class="cta" href="${APP_STORE_URL}">Get Peepl on the App Store</a>
      <a class="cta secondary" href="${PLAY_STORE_URL}">Get Peepl on Google Play</a>`;
  }

  const imageBlock = safeImageUrl
    ? `<img class="hero" src="${safeImageUrl}" alt="${safeTitle}">`
    : '';

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${safeTitle} — Peepl</title>
  <meta property="og:title" content="${safeTitle} at ${safeVenue} — Peepl">
  <meta property="og:description" content="${safeDescription || `${safeTitle} at ${safeVenue}`}">
  ${safeImageUrl ? `<meta property="og:image" content="${safeImageUrl}">` : ''}
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: #f5f5f5; color: #212121; line-height: 1.4; min-height: 100vh;
    }
    .wrap { max-width: 480px; margin: 0 auto; padding: 24px 20px 40px; }
    .logo { color: #1565C0; font-size: 22px; font-weight: 700; margin-bottom: 20px; }
    .card {
      background: #fff; border-radius: 16px; padding: 20px;
      box-shadow: 0 2px 12px rgba(0,0,0,0.06);
    }
    .deal-title { font-size: 24px; font-weight: 700; margin-bottom: 8px; }
    .venue { color: #616161; font-size: 16px; font-weight: 600; margin-bottom: 12px; }
    .description { color: #424242; font-size: 15px; margin-bottom: 16px; }
    .hero {
      width: 100%; max-height: 300px; object-fit: cover;
      border-radius: 12px; margin-bottom: 20px; display: block;
    }
    .cta {
      display: block; text-align: center; text-decoration: none;
      background: #1565C0; color: #fff; font-weight: 700;
      padding: 14px 18px; border-radius: 12px; margin-top: 12px;
    }
    .cta.secondary { background: #fff; color: #1565C0; border: 2px solid #1565C0; }
    .footer { text-align: center; color: #9e9e9e; font-size: 12px; margin-top: 24px; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="logo">Peepl</div>
    <div class="card">
      <div class="deal-title">${safeTitle}</div>
      <div class="venue">${safeVenue}</div>
      ${safeDescription ? `<div class="description">${safeDescription}</div>` : ''}
      ${imageBlock}
      ${ctaHtml}
    </div>
    <div class="footer">Deals and live crowd levels, wherever you go.</div>
  </div>
</body>
</html>`;
}

async function recordPreviewOpen({ peepId, shareId, uid, src, userAgent }) {
  if (!admin.apps.length) return;
  const db = admin.firestore();
  const truncatedUa = String(userAgent || '').slice(0, 200);
  const openedAt = admin.firestore.FieldValue.serverTimestamp();

  const openPayload = {
    shareId: shareId || null,
    peepId,
    openedAt,
    userAgent: truncatedUa,
    hasApp: false,
  };
  if (uid) openPayload.uid = uid;
  if (src) openPayload.src = src;

  try {
    await db.collection('peep_link_opens').add(openPayload);
  } catch (err) {
    console.warn('[Growth] peep_link_opens write failed:', err.message);
  }

  try {
    await db.collection('growth_events').add({
      eventName: 'growth_preview_viewed',
      properties: {
        shareId: shareId || null,
        peepId,
        userAgent: truncatedUa,
      },
      userId: uid || null,
      timestamp: openedAt,
      appVersion: 'backend',
      platform: 'web',
    });
  } catch (err) {
    console.warn('[Growth] growth_preview_viewed write failed:', err.message);
  }
}

app.get('/.well-known/apple-app-site-association', (req, res) => {
  res.type('application/json');
  res.json({
    applinks: {
      apps: [],
      details: [{
        appID: `${APPLE_TEAM_ID}.${APPLE_BUNDLE_ID}`,
        paths: ['/p/*', '/w/*'],
      }],
    },
  });
});

app.get('/.well-known/assetlinks.json', (req, res) => {
  res.type('application/json');
  res.json([{
    relation: ['delegate_permission/common.handle_all_urls'],
    target: {
      namespace: 'android_app',
      package_name: APPLE_BUNDLE_ID,
      sha256_cert_fingerprints: [ANDROID_SHA256_FINGERPRINT],
    },
  }]);
});

app.get('/p/:peepId', async (req, res) => {
  const { peepId } = req.params;
  const shareId = req.query.ref || null;
  const uid = req.query.uid || null;
  const src = req.query.src || null;
  const userAgent = req.headers['user-agent'] || '';

  if (!admin.apps.length) {
    res.status(503).send(renderSimplePage(
      'Peepl',
      'Preview is temporarily unavailable. Please try again later.',
      503,
    ));
    return;
  }

  try {
    const peep = await fetchPeepDocument(peepId);
    if (!peep) {
      res.status(404).send(renderSimplePage(
        'Peep unavailable',
        'This Peep is no longer available.',
        404,
      ));
      return;
    }

    const venueName = peep.locationName || peep.venueName || peep.name || 'Unknown venue';
    const crowdingLevel = (peep.crowdingLevel ?? peep.crowdLevel ?? 0);
    const label = crowdLabel(crowdingLevel);
    const minutesLabel = minutesAgoLabel(peep.timestamp || peep.createdAt || peep.updatedAt);
    const imageUrl = peep.imageUrl || peep.photoUrl || null;
    const storePlatform = detectStorePlatform(userAgent);

    recordPreviewOpen({ peepId, shareId, uid, src, userAgent }).catch((err) => {
      console.warn('[Growth] recordPreviewOpen error:', err.message);
    });

    res.type('html').send(renderPreviewPage({
      venueName,
      crowdingLevel,
      crowdLabelText: label,
      minutesLabel,
      imageUrl,
      storePlatform,
    }));
  } catch (err) {
    console.error('[Growth] /p/:peepId error:', err.message);
    res.status(500).send(renderSimplePage(
      'Something went wrong',
      'We could not load this Peep right now. Please try again later.',
      500,
    ));
  }
});

app.get('/v/:venueKey', async (req, res) => {
  const { venueKey } = req.params;
  const userAgent = req.headers['user-agent'] || '';

  if (!admin.apps.length) {
    res.status(503).send(renderSimplePage(
      'Peepl',
      'Preview is temporarily unavailable. Please try again later.',
      503,
    ));
    return;
  }

  try {
    const peep = await fetchLatestVenuePeep(venueKey);
    if (!peep) {
      res.status(404).send(renderSimplePage(
        'Venue unavailable',
        'No live crowd data is available for this venue right now.',
        404,
      ));
      return;
    }

    const venueName = peep.locationName || peep.venueName || decodeURIComponent(venueKey);
    const crowdingLevel = (peep.crowdingLevel ?? peep.crowdLevel ?? 0);
    const label = crowdLabel(crowdingLevel);
    const minutesLabel = minutesAgoLabel(peep.timestamp || peep.createdAt || peep.updatedAt);
    const imageUrl = peep.imageUrl || peep.photoUrl || null;
    const storePlatform = detectStorePlatform(userAgent);

    res.type('html').send(renderPreviewPage({
      venueName,
      crowdingLevel,
      crowdLabelText: label,
      minutesLabel,
      imageUrl,
      storePlatform,
    }));
  } catch (err) {
    console.error('[Growth] /v/:venueKey error:', err.message);
    res.status(500).send(renderSimplePage(
      'Something went wrong',
      'We could not load this venue right now. Please try again later.',
      500,
    ));
  }
});

app.get('/d/:dealId', async (req, res) => {
  const { dealId } = req.params;
  const userAgent = req.headers['user-agent'] || '';

  if (!admin.apps.length) {
    res.status(503).send(renderSimplePage(
      'Peepl',
      'Preview is temporarily unavailable. Please try again later.',
      503,
    ));
    return;
  }

  try {
    const deal = await fetchDealDocument(dealId);
    if (!deal) {
      res.status(404).send(renderSimplePage(
        'Deal unavailable',
        'This deal is no longer available.',
        404,
      ));
      return;
    }

    const dealTitle = dealTitleFromDoc(deal);
    const venueName = dealVenueNameFromDoc(deal);
    const description = deal.bodyText || deal.body || deal.tagline || deal.subline || '';
    const imageUrl = deal.imageUrl || deal.logoUrl || deal.merchantLogo || null;
    const storePlatform = detectStorePlatform(userAgent);

    res.type('html').send(renderDealPreviewPage({
      dealTitle,
      venueName,
      description,
      imageUrl,
      storePlatform,
    }));
  } catch (err) {
    console.error('[Growth] /d/:dealId error:', err.message);
    res.status(500).send(renderSimplePage(
      'Something went wrong',
      'We could not load this deal right now. Please try again later.',
      500,
    ));
  }
});

app.get('/w/:groupId', async (req, res) => {
  const { groupId } = req.params;
  const userAgent = req.headers['user-agent'] || '';

  if (!admin.apps.length) {
    res.status(503).send(renderSimplePage(
      'Peepl',
      'Preview is temporarily unavailable. Please try again later.',
      503,
    ));
    return;
  }

  try {
    const db = admin.firestore();
    const doc = await db.collection('venue_comparisons').doc(groupId).get();
    if (!doc.exists || isExpiredFirestoreTimestamp(doc.data()?.expiresAt)) {
      res.status(404).send(renderSimplePage(
        'Comparison unavailable',
        'This comparison has expired or is no longer available.',
        404,
      ));
      return;
    }

    const data = doc.data();
    const venues = data.venues || [];
    const storePlatform = detectStorePlatform(userAgent);

    try {
      await db.collection('growth_events').add({
        eventName: 'growth_group_preview_viewed',
        properties: {
          groupId,
          timestamp: new Date().toISOString(),
          userAgent: String(userAgent).slice(0, 200),
        },
        userId: null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        appVersion: 'backend',
        platform: 'web',
      });
    } catch (err) {
      console.warn('[Growth] growth_group_preview_viewed write failed:', err.message);
    }

    res.type('html').send(renderGroupComparisonPage({
      venues,
      storePlatform,
    }));
  } catch (err) {
    console.error('[Growth] /w/:groupId error:', err.message);
    res.status(500).send(renderSimplePage(
      'Something went wrong',
      'We could not load this comparison right now. Please try again later.',
      500,
    ));
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
