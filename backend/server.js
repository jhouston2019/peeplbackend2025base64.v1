require('dotenv').config();

const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

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

async function getFcmToken(uid) {
  try {
    const doc = await admin.firestore().collection(uid).doc('profile').get();
    if (!doc.exists) {
      console.warn('[FCM] No profile document for uid', uid);
      return null;
    }
    const token = doc.data().fcmToken;
    if (!token) {
      console.warn('[FCM] No FCM token stored for uid', uid);
      return null;
    }
    return token;
  } catch (err) {
    console.warn('[FCM] getFcmToken error for', uid, ':', err.message);
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
app.post(
  '/merchant/payment-confirmed',
  express.raw({ type: 'application/json' }),
  async (req, res) => {
    const sig = req.headers['stripe-signature'];
    if (!sig || !process.env.STRIPE_WEBHOOK_SECRET) {
      return res.status(400).json({ error: 'Missing Stripe signature or secret' });
    }

    let event;
    try {
      event = stripe.webhooks.constructEvent(
        req.body,
        sig,
        process.env.STRIPE_WEBHOOK_SECRET,
      );
    } catch (err) {
      console.error('[Stripe] Webhook signature verification failed:', err.message);
      return res.status(400).json({ error: `Webhook Error: ${err.message}` });
    }

    if (!admin.apps.length) return res.status(503).json({ error: 'Firebase Admin not initialised' });
    const db = admin.firestore();

    if (event.type === 'payment_intent.succeeded') {
      const intent = event.data.object;
      const { adId, merchantId, tier, durationHours } = intent.metadata;
      try {
        const now = admin.firestore.Timestamp.now();
        const endDate = new Date();
        endDate.setHours(endDate.getHours() + parseInt(durationHours, 10));

        await db.collection('native_ads').doc(adId).update({
          isActive: true,
          startDate: now,
          endDate: admin.firestore.Timestamp.fromDate(endDate),
          billing_status: 'paid',
          stripePaymentIntentId: intent.id,
        });

        await db.collection('merchant_payments').add({
          adId,
          merchantId,
          amount: intent.amount,
          currency: intent.currency,
          stripePaymentIntentId: intent.id,
          status: 'paid',
          tier,
          durationHours: parseInt(durationHours, 10),
          timestamp: now,
        });

        console.log(`[Stripe] Ad ${adId} activated for merchant ${merchantId}`);
      } catch (err) {
        console.error('[Stripe] Post-payment Firestore error:', err.message);
        // Still return 200 so Stripe doesn't retry — log the error separately.
      }
    } else if (event.type === 'payment_intent.payment_failed') {
      const intent = event.data.object;
      const { adId } = intent.metadata;
      try {
        await db.collection('native_ads').doc(adId).update({
          billing_status: 'payment_failed',
        });
      } catch (err) {
        console.error('[Stripe] Failed-payment update error:', err.message);
      }
    }

    res.json({ received: true });
  },
);

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
    console.log(`[FCM] Sent to ${uid}: ${messageId}`);
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
    console.log(`[FCM] Like notification sent to ${postOwnerUid}: ${messageId}`);
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
app.post('/merchant/create-payment-intent', async (req, res) => {
  const { adId, merchantId, durationHours, tier, billing_model = 'flat_rate' } = req.body;
  if (!adId || !merchantId || !durationHours || !tier) {
    return res.status(400).json({ error: 'adId, merchantId, durationHours, and tier are required' });
  }

  if (!process.env.STRIPE_SECRET_KEY) {
    return res.status(503).json({ error: 'Stripe not configured on this server' });
  }

  try {
    let amountCents;
    if (billing_model === 'cpm') {
      const estimatedImpressions = (CPM_EST_HOURLY[tier] ?? 200) * durationHours;
      const rate = CPM_RATE[tier] ?? 5.0;
      amountCents = Math.max(50, Math.round((estimatedImpressions / 1000) * rate * 100));
    } else {
      const hourlyRate = FLAT_RATE_HOURLY[tier] ?? 9.99;
      amountCents = Math.round(hourlyRate * durationHours * 100);
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountCents,
      currency: 'usd',
      automatic_payment_methods: { enabled: true },
      metadata: {
        adId,
        merchantId,
        tier,
        durationHours: String(durationHours),
        billing_model,
      },
    });

    console.log(`[Stripe] PaymentIntent created for ad ${adId}: $${(amountCents / 100).toFixed(2)}`);
    res.json({ clientSecret: paymentIntent.client_secret, amountCents });
  } catch (err) {
    console.error('[Stripe] create-payment-intent error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /merchant/billing-history/:merchantId
// Returns the 50 most recent payment records for a merchant.
app.get('/merchant/billing-history/:merchantId', async (req, res) => {
  if (!admin.apps.length) return res.status(503).json({ error: 'Firebase Admin not initialised' });
  const { merchantId } = req.params;
  try {
    const snapshot = await admin.firestore()
      .collection('merchant_payments')
      .where('merchantId', '==', merchantId)
      .orderBy('timestamp', 'desc')
      .limit(50)
      .get();
    const payments = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    res.json({ payments });
  } catch (err) {
    console.error('[Billing history] Error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST /merchant/run-billing-cron
// Deactivates expired ads and invoices CPM campaigns against actual impressions.
// Trigger this endpoint via Railway's cron scheduler (Settings → Cron Jobs)
// using an Authorization header: Bearer <CRON_SECRET>.
// Recommended schedule: every hour — "0 * * * *"
app.post('/merchant/run-billing-cron', async (req, res) => {
  const cronSecret = process.env.CRON_SECRET;
  if (cronSecret && req.headers['authorization'] !== `Bearer ${cronSecret}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  if (!admin.apps.length) return res.status(503).json({ error: 'Firebase Admin not initialised' });

  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const expiredSnap = await db.collection('native_ads')
      .where('isActive', '==', true)
      .where('endDate', '<=', now)
      .get();

    let invoiced = 0;
    for (const doc of expiredSnap.docs) {
      const ad = doc.data();
      try {
        if (ad.billing_model === 'cpm' && ad.stripeCustomerId) {
          const impressions = ad.impressions ?? 0;
          const rate = CPM_RATE[ad.tier] ?? 5.0;
          const finalCharge = Math.max(50, Math.round((impressions / 1000) * rate * 100));
          await stripe.paymentIntents.create({
            amount: finalCharge,
            currency: 'usd',
            customer: ad.stripeCustomerId,
            confirm: true,
            off_session: true,
            metadata: { adId: doc.id, merchantId: ad.advertiserId, type: 'cpm_final' },
          });
          await db.collection('merchant_payments').add({
            adId: doc.id,
            merchantId: ad.advertiserId,
            amount: finalCharge,
            currency: 'usd',
            billing_model: 'cpm',
            impressions,
            status: 'invoiced',
            timestamp: now,
          });
        }
        await doc.ref.update({ isActive: false, billing_status: 'invoiced' });
        invoiced++;
      } catch (err) {
        console.error(`[Cron] Failed to process ad ${doc.id}:`, err.message);
      }
    }

    console.log(`[Cron] Billing run complete — ${invoiced} ads invoiced`);
    res.json({ invoiced });
  } catch (err) {
    console.error('[Cron] Error:', err.message);
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
