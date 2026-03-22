require("dotenv").config();
const Sentry = require("@sentry/node");
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV || "development",
  tracesSampleRate: 1.0,
});

const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const compression = require("compression");
const rateLimit = require("express-rate-limit");
const multer = require("multer");
const admin = require("firebase-admin");
const { body, validationResult } = require("express-validator");
const { createServer } = require("http");
const { Server } = require("socket.io");
const cron = require("node-cron");
const winston = require("winston");
const geofire = require("geofire-common");

// Stripe (Task 68) — keys from environment only
const Stripe = require("stripe");
const stripe = process.env.STRIPE_SECRET_KEY
  ? Stripe(process.env.STRIPE_SECRET_KEY)
  : null;

// Import services
const notificationService = require("./src/services/NotificationService");
const { triggerCrowdConfirmationIfNeeded } = require("./src/services/NotificationService");
const geofencingService = require("./src/services/GeofencingService");
const { awardPoints, POINTS_RULES } = require("./src/services/PointsService");

// Initialize Express app
const app = express();
const server = createServer(app);
const io = new Server(server, {
  cors: {
    origin: process.env.CORS_ORIGIN?.split(",") || ["http://localhost:3000"],
    methods: ["GET", "POST"]
  }
});

// Configure Winston logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || "info",
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: "error.log", level: "error" }),
    new winston.transports.File({ filename: "combined.log" })
  ]
});

// Security middleware
app.use(helmet());
app.use(compression());

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
  message: "Too many requests from this IP, please try again later."
});
app.use(limiter);

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { error: 'Too many authentication attempts. Please try again in 15 minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
});

// CORS configuration
app.use(cors({
  origin: process.env.CORS_ORIGIN?.split(",") || ["http://localhost:3000"],
  credentials: true
}));

// Stripe webhooks must receive the raw body (Task 68) — register before express.json()
app.post(
  "/webhooks/stripe",
  express.raw({ type: "application/json" }),
  async (req, res) => {
    if (!stripe) {
      return res.status(503).json({ error: "Stripe not configured" });
    }
    const sig = req.headers["stripe-signature"];
    let event;
    try {
      event = stripe.webhooks.constructEvent(
        req.body,
        sig,
        process.env.STRIPE_WEBHOOK_SECRET
      );
    } catch (err) {
      return res.status(400).send(`Webhook error: ${err.message}`);
    }
    if (event.type === "invoice.payment_failed") {
      const customerId = event.data.object.customer;
      const snap = await admin
        .firestore()
        .collection("users")
        .where("stripeCustomerId", "==", customerId)
        .limit(1)
        .get();
      if (!snap.empty) {
        await snap.docs[0].ref.update({
          paymentFailed: true,
          paymentFailedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
    if (event.type === "customer.subscription.deleted") {
      const subId = event.data.object.id;
      const snap = await admin
        .firestore()
        .collection("users")
        .where("subscriptionId", "==", subId)
        .get();
      snap.docs.forEach((d) => d.ref.update({ isVIP: false }));
    }
    res.json({ received: true });
  }
);

app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// Initialize Firebase Admin
const firebaseBase64 = process.env.FIREBASE_CONFIG_B64;
if (!firebaseBase64) {
  logger.error("FIREBASE_CONFIG_B64 not set");
  process.exit(1);
}

const firebaseJson = Buffer.from(firebaseBase64, "base64").toString("utf8");
const serviceAccount = JSON.parse(firebaseJson);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET || "peepl-2025.appspot.com"
});

const db = admin.firestore();
const storage = admin.storage();

/*
  MERCHANT DATA MODEL

  Collection: merchant_accounts
  Fields:
    - businessName: string
    - category: 'bar_pub' | 'restaurant' | 'coffee' | 'retail' | 'services' | 'entertainment' | 'other'
    - address: string
    - city: string
    - contactName: string
    - email: string
    - phone: string
    - paymentMethod: string (Stripe payment method ID)
    - merchantNumber: string (7-digit generated number, e.g. '#7547698')
    - createdAt: Timestamp
    - isActive: boolean
    - stripeCustomerId: string
    - ownerId: string (Firebase Auth UID)

  Collection: merchant_ads
  Fields:
    - merchantId: string (doc ID from merchant_accounts)
    - offerText: string (max 40 chars)
    - startTime: Timestamp
    - endTime: Timestamp
    - rateType: 'basic' | 'standard' | 'premium'
    - ratePerHour: number (10 | 25 | 50)
    - totalCost: number
    - status: 'pending' | 'live' | 'ended' | 'cancelled'
    - impressions: number
    - claims: number
    - venueRadius: number (km, default 1)
    - lat: number
    - lng: number
    - createdAt: Timestamp
*/

function generateMerchantNumber() {
  return "#" + Math.floor(1000000 + Math.random() * 9000000).toString();
}

// Configure multer for file uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith("image/")) {
      cb(null, true);
    } else {
      cb(new Error("Only image files are allowed"), false);
    }
  }
});

// Firebase Auth middleware
const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];

  if (!token) {
    return res.status(401).json({ error: "Access token required" });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.user = decodedToken;
    next();
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Firebase Auth verification failed:", error);
    return res.status(403).json({ error: "Invalid or expired token" });
  }
};

const requireVIP = async (req, res, next) => {
  const userDoc = await db.collection("users").doc(req.user.uid).get();
  if (!userDoc.data()?.isVIP) {
    return res.status(403).json({ error: "VIPeeps subscription required" });
  }
  next();
};

// Validation middleware
const validateRequest = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
};

// Socket.IO connection handling
io.on("connection", (socket) => {
  logger.info(`User connected: ${socket.id}`);

  socket.on("join_venue", (venueId) => {
    socket.join(`venue_${venueId}`);
    logger.info(`User ${socket.id} joined venue ${venueId}`);
  });

  socket.on("leave_venue", (venueId) => {
    socket.leave(`venue_${venueId}`);
    logger.info(`User ${socket.id} left venue ${venueId}`);
  });

  socket.on("disconnect", () => {
    logger.info(`User disconnected: ${socket.id}`);
  });
});

// Routes

// Health check
app.get("/health", (req, res) => {
  res.json({ status: "OK", timestamp: new Date().toISOString() });
});

// User Authentication Routes
app.post("/auth/register", authLimiter, authenticateToken, [
  body("email").isEmail().normalizeEmail(),
  body("username").isLength({ min: 3, max: 30 }),
  body("firstName").isLength({ min: 1, max: 50 }),
  body("lastName").isLength({ min: 1, max: 50 })
], validateRequest, async (req, res) => {
  try {
    const { email, username, firstName, lastName } = req.body;
    const uid = req.user.uid;

    // Check if user already exists in Firestore
    const existingUser = await db.collection("users").doc(uid).get();
    if (existingUser.exists) {
      return res.status(400).json({ error: "User already exists" });
    }

    // Store user data in Firestore
    const userData = {
      uid,
      email,
      username,
      firstName,
      lastName,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true,
      profileImageUrl: null,
      bio: "",
      location: null,
      preferences: {
        notifications: true,
        locationSharing: true,
        publicProfile: true
      }
    };

    await db.collection("users").doc(uid).set(userData);

    logger.info(`New user registered: ${email}`);
    res.status(201).json({
      message: "User created successfully",
      user: {
        uid,
        email,
        username,
        firstName,
        lastName
      }
    });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Registration error:", error);
    res.status(500).json({ error: "Registration failed" });
  }
});


// User Profile Routes
app.get("/users/profile", authenticateToken, async (req, res) => {
  try {
    const userDoc = await db.collection("users").doc(req.user.uid).get();
    if (!userDoc.exists) {
      return res.status(404).json({ error: "User not found" });
    }

    const userData = userDoc.data();

    res.json(userData);
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Profile fetch error:", error);
    res.status(500).json({ error: "Failed to fetch profile" });
  }
});

app.get("/users/:userId", authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ error: "User not found" });
    }
    const d = userDoc.data();
    const followersSnap = await db.collection("follows").where("followingId", "==", userId).get();
    const followingSnap = await db.collection("follows").where("followerId", "==", userId).get();
    const peepsSnap = await db.collection("peeps").where("userId", "==", userId).where("isActive", "==", true).limit(500).get();
    let isFollowing = false;
    if (req.user.uid !== userId) {
      const f = await db.collection("follows").doc(`${req.user.uid}_${userId}`).get();
      isFollowing = f.exists;
    }
    res.json({
      uid: userId,
      ...d,
      followersCount: followersSnap.size,
      followingCount: followingSnap.size,
      peepsCount: peepsSnap.size,
      isFollowing,
    });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("User by id error:", error);
    res.status(500).json({ error: "Failed to fetch user" });
  }
});

app.post("/users/:userId/follow", authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    if (userId === req.user.uid) {
      return res.status(400).json({ error: "Cannot follow yourself" });
    }
    const target = await db.collection("users").doc(userId).get();
    if (!target.exists) {
      return res.status(404).json({ error: "User not found" });
    }
    await db.collection("follows").doc(`${req.user.uid}_${userId}`).set({
      followerId: req.user.uid,
      followingId: userId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await db.collection("users").doc(userId).update({
      followersCount: admin.firestore.FieldValue.increment(1),
    });
    await db.collection("users").doc(req.user.uid).update({
      followingCount: admin.firestore.FieldValue.increment(1),
    });
    res.json({ following: true });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Follow error:", error);
    res.status(500).json({ error: "Failed to follow" });
  }
});

app.delete("/users/:userId/follow", authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    const ref = db.collection("follows").doc(`${req.user.uid}_${userId}`);
    const existing = await ref.get();
    if (!existing.exists) {
      return res.json({ following: false });
    }
    await ref.delete();
    await db.collection("users").doc(userId).update({
      followersCount: admin.firestore.FieldValue.increment(-1),
    });
    await db.collection("users").doc(req.user.uid).update({
      followingCount: admin.firestore.FieldValue.increment(-1),
    });
    res.json({ following: false });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Unfollow error:", error);
    res.status(500).json({ error: "Failed to unfollow" });
  }
});

app.get("/users/:userId/followers", authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    const snap = await db
      .collection("follows")
      .where("followingId", "==", userId)
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();
    const users = await Promise.all(
      snap.docs.map(async (d) => {
        const followerId = d.data().followerId;
        const userDoc = await db.collection("users").doc(followerId).get();
        const ud = userDoc.data() || {};
        const f = await db.collection("follows").doc(`${req.user.uid}_${followerId}`).get();
        return {
          userId: followerId,
          username: ud.username || "User",
          pioneerCount: ud.pioneerCount || 0,
          points: ud.points || 0,
          profileImageUrl: ud.profileImageUrl || null,
          isFollowing: f.exists,
          ...ud,
        };
      })
    );
    res.json({ followers: users, users });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Followers list error:", error);
    res.status(500).json({ error: "Failed to list followers" });
  }
});

app.get("/users/:userId/following", authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    const snap = await db
      .collection("follows")
      .where("followerId", "==", userId)
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();
    const users = await Promise.all(
      snap.docs.map(async (d) => {
        const followingId = d.data().followingId;
        const userDoc = await db.collection("users").doc(followingId).get();
        const ud = userDoc.data() || {};
        const f = await db.collection("follows").doc(`${req.user.uid}_${followingId}`).get();
        return {
          userId: followingId,
          username: ud.username || "User",
          pioneerCount: ud.pioneerCount || 0,
          points: ud.points || 0,
          profileImageUrl: ud.profileImageUrl || null,
          isFollowing: f.exists,
          ...ud,
        };
      })
    );
    res.json({ following: users, users });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Following list error:", error);
    res.status(500).json({ error: "Failed to list following" });
  }
});

app.get("/feed/following", authenticateToken, async (req, res) => {
  try {
    const followingSnap = await db
      .collection("follows")
      .where("followerId", "==", req.user.uid)
      .get();
    const followingIds = followingSnap.docs.map((d) => d.data().followingId);
    if (followingIds.length === 0) return res.json({ peeps: [] });
    const chunks = [];
    for (let i = 0; i < followingIds.length; i += 10) {
      chunks.push(followingIds.slice(i, i + 10));
    }
    const snaps = await Promise.all(
      chunks.map((chunk) =>
        db
          .collection("peeps")
          .where("userId", "in", chunk)
          .orderBy("createdAt", "desc")
          .limit(50)
          .get()
      )
    );
    const peeps = snaps.flatMap((s) =>
      s.docs.map((d) => ({ id: d.id, ...d.data() }))
    );
    const peepTime = (p) => {
      const c = p.createdAt;
      if (!c) return 0;
      if (typeof c.toMillis === "function") return c.toMillis();
      if (c.seconds != null) return c.seconds * 1000;
      return 0;
    };
    peeps.sort((a, b) => peepTime(b) - peepTime(a));
    res.json({ peeps: peeps.slice(0, 50) });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Following feed error:", error);
    res.status(500).json({ error: "Failed to load feed" });
  }
});

app.put("/users/profile", authenticateToken, [
  body("username").optional().isLength({ min: 3, max: 30 }),
  body("firstName").optional().isLength({ min: 1, max: 50 }),
  body("lastName").optional().isLength({ min: 1, max: 50 }),
  body("bio").optional().isLength({ max: 500 }),
  body("phone").optional().isLength({ max: 30 })
], validateRequest, async (req, res) => {
  try {
    const allowedFields = ['username', 'firstName', 'lastName', 'bio', 'profileImageUrl', 'preferences', 'phone'];
    const updateData = {};
    allowedFields.forEach(field => {
      if (req.body[field] !== undefined) {
        updateData[field] = req.body[field];
      }
    });
    updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();

    if (Object.keys(updateData).length === 1) {
      return res.status(400).json({ error: 'No valid fields provided' });
    }

    await db.collection("users").doc(req.user.uid).update(updateData);

    logger.info(`Profile updated for user: ${req.user.uid}`);
    res.json({ message: "Profile updated successfully" });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Profile update error:", error);
    res.status(500).json({ error: "Failed to update profile" });
  }
});

// Venue Routes
// Required Firestore index: collection=venues, fields=[geohash ASC]
// Create via Firebase Console or firestore.indexes.json
// (Composite queries with isActive + geohash need a matching composite index.)

app.post("/venues/nearby", [
  body("lat").isFloat({ min: -90, max: 90 }),
  body("lng").isFloat({ min: -180, max: 180 }),
  body("radius").optional().isFloat({ min: 0.1, max: 50 })
], validateRequest, async (req, res) => {
  try {
    const { lat, lng, radius = 5 } = req.body;
    const center = [parseFloat(lat), parseFloat(lng)];
    const radiusInM = parseFloat(radius) * 1000;
    const bounds = geofire.geohashQueryBounds(center, radiusInM);
    
    const promises = bounds.map(b =>
      db.collection('venues')
        .orderBy('geohash')
        .startAt(b[0])
        .endAt(b[1])
        .get()
    );
    
    const snapshots = await Promise.all(promises);
    const venues = [];
    
    snapshots.forEach(snap => {
      snap.docs.forEach(doc => {
        const data = doc.data();
        const distanceInKm = geofire.distanceBetween([data.lat, data.lng], center);
        if (distanceInKm <= parseFloat(radius)) {
          venues.push({ id: doc.id, ...data, distance: distanceInKm });
        }
      });
    });
    
    venues.sort((a, b) => a.distance - b.distance);
    res.json({ venues });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Nearby venues error:", error);
    res.status(500).json({ error: "Failed to fetch nearby venues" });
  }
});

app.post("/venues", authenticateToken, [
  body("name").isLength({ min: 1, max: 100 }),
  body("latitude").isFloat({ min: -90, max: 90 }),
  body("longitude").isFloat({ min: -180, max: 180 }),
  body("address").isLength({ min: 1, max: 200 }),
  body("category").isLength({ min: 1, max: 50 })
], validateRequest, async (req, res) => {
  try {
    const lat = parseFloat(req.body.latitude);
    const lng = parseFloat(req.body.longitude);
    const cityLower = (req.body.city || "").toLowerCase().trim();
    const venueData = {
      ...req.body,
      lat,
      lng,
      geohash: geofire.geohashForPoint([lat, lng]),
      nameLower: String(req.body.name || "").toLowerCase(),
      cityLower: cityLower || String(req.body.address || "").toLowerCase(),
      createdBy: req.user.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true,
      peepCount: 0,
      averageRating: 0,
      totalRatings: 0
    };

    const docRef = await db.collection("venues").add(venueData);

    logger.info(`New venue created: ${venueData.name} by ${req.user.uid}`);
    res.status(201).json({
      message: "Venue created successfully",
      venueId: docRef.id
    });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Venue creation error:", error);
    res.status(500).json({ error: "Failed to create venue" });
  }
});

// Peep Routes
app.post("/peeps", authenticateToken, upload.single("photo"), (req, res, next) => {
  if (!Array.isArray(req.body.ageRanges)) {
    if (typeof req.body.ageRanges === "string") {
      try {
        req.body.ageRanges = JSON.parse(req.body.ageRanges);
      } catch {
        req.body.ageRanges = [req.body.ageRanges];
      }
    } else if (req.body.ageRanges != null) {
      req.body.ageRanges = [req.body.ageRanges];
    }
  }
  if (!Array.isArray(req.body.vibe)) {
    if (typeof req.body.vibe === "string") {
      try {
        req.body.vibe = JSON.parse(req.body.vibe);
      } catch {
        req.body.vibe = [req.body.vibe];
      }
    } else if (req.body.vibe != null) {
      req.body.vibe = [req.body.vibe];
    }
  }
  next();
}, [
  body("venueId").isLength({ min: 1 }),
  body("description").isLength({ min: 1, max: 500 }),
  body("crowdSize").isInt({ min: 1, max: 5 }),
  body("mfRatio").isFloat({ min: 0, max: 100 }),
  body("akRatio").isFloat({ min: 0, max: 100 }),
  body("ageRanges").isArray(),
  body("vibe").isArray(),
  body("crowdTrend").isIn(['getting_busier', 'steady', 'clearing_out']),
  body("latitude").optional().isFloat({ min: -90, max: 90 }),
  body("longitude").optional().isFloat({ min: -180, max: 180 })
], validateRequest, async (req, res) => {
  try {
    const { venueId, description, crowdSize, mfRatio, akRatio, ageRanges, vibe, crowdTrend, latitude, longitude } = req.body;
    const userId = req.user.uid;

    // Verify venue exists
    const venueDoc = await db.collection("venues").doc(venueId).get();
    if (!venueDoc.exists) {
      return res.status(404).json({ error: "Venue not found" });
    }

    const peepData = {
      venueId,
      userId,
      description,
      crowdSize: parseInt(crowdSize),
      mfRatio: parseFloat(mfRatio),
      akRatio: parseFloat(akRatio),
      ageRanges,
      vibe,
      crowdTrend,
      latitude: latitude ? parseFloat(latitude) : null,
      longitude: longitude ? parseFloat(longitude) : null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true,
      likeCount: 0,
      commentCount: 0,
      imageUrl: null
    };

    // Handle photo upload
    if (req.file) {
      const bucket = storage.bucket();
      const fileName = `peeps/${Date.now()}_${req.file.originalname}`;
      const file = bucket.file(fileName);

      await file.save(req.file.buffer, {
        metadata: { contentType: req.file.mimetype },
      });

      // TODO: Replace long-lived signed URL with short-lived URL rotation before production launch
      const [signedUrl] = await file.getSignedUrl({
        action: 'read',
        expires: '03-01-2500',
      });
      peepData.imageUrl = signedUrl;
    }

    // Create peep
    const peepRef = await db.collection("peeps").add(peepData);

    // Pioneer detection
    const existingPeeps = await admin.firestore()
      .collection('peeps')
      .where('venueId', '==', venueId)
      .limit(2)
      .get();
    
    const isPioneer = existingPeeps.docs.length === 1;
    
    if (isPioneer) {
      await peepRef.update({ isPioneer: true });
      
      await admin.firestore().collection('venues').doc(venueId).update({
        pioneeredBy: req.user.uid,
        pioneeredAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      await awardPoints(req.user.uid, 'PIONEER_DISCOVERY', POINTS_RULES.PIONEER_DISCOVERY);
    }

    // Award points for peep creation
    await awardPoints(req.user.uid, 'PEEP_CREATED', POINTS_RULES.PEEP_CREATED);
    
    const hasPhoto = !!peepData.imageUrl;
    if (hasPhoto) {
      await awardPoints(req.user.uid, 'PEEP_WITH_PHOTO', POINTS_RULES.PEEP_WITH_PHOTO);
    }
    
    const isFullyComplete = ageRanges.length > 0 && vibe.length > 0 && crowdTrend && description && hasPhoto;
    if (isFullyComplete) {
      await awardPoints(req.user.uid, 'PEEP_FULLY_COMPLETE', POINTS_RULES.PEEP_FULLY_COMPLETE);
    }

    // Update venue statistics
    const venueData = venueDoc.data();
    const newPeepCount = (venueData.peepCount || 0) + 1;

    await db.collection("venues").doc(venueId).update({
      peepCount: newPeepCount,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Emit real-time update
    io.to(`venue_${venueId}`).emit("new_peep", {
      peepId: peepRef.id,
      ...peepData
    });

    logger.info(`New peep created: ${peepRef.id} by ${userId}`);

    const venueName = venueData.name || venueDoc.id;
    triggerCrowdConfirmationIfNeeded(venueId, venueName).catch(e => {
      Sentry.captureException(e);
      logger.error('Push trigger failed:', e);
    });

    res.status(201).json({
      message: "Peep created successfully",
      peepId: peepRef.id,
      isPioneer
    });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Peep creation error:", error);
    res.status(500).json({ error: "Failed to create peep" });
  }
});

app.get("/peeps/venue/:venueId", async (req, res) => {
  try {
    const { venueId } = req.params;
    const { limit = 20, offset = 0 } = req.query;

    const peepsSnapshot = await db.collection("peeps")
      .where("venueId", "==", venueId)
      .where("isActive", "==", true)
      .orderBy("createdAt", "desc")
      .limit(parseInt(limit))
      .offset(parseInt(offset))
      .get();

    const peeps = [];
    peepsSnapshot.forEach(doc => {
      peeps.push({
        id: doc.id,
        ...doc.data()
      });
    });

    res.json(peeps);
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Peeps fetch error:", error);
    res.status(500).json({ error: "Failed to fetch peeps" });
  }
});

app.get("/peeps", authenticateToken, async (req, res) => {
  try {
    const userId = req.query.userId;
    if (!userId) {
      return res.status(400).json({ error: "userId required" });
    }
    const snap = await db
      .collection("peeps")
      .where("userId", "==", userId)
      .where("isActive", "==", true)
      .limit(200)
      .get();
    const peeps = await Promise.all(
      snap.docs.map(async (doc) => {
        const data = doc.data();
        let venueName = "";
        if (data.venueId) {
          const v = await db.collection("venues").doc(data.venueId).get();
          venueName = v.data()?.name || "";
        }
        const u = await db.collection("users").doc(data.userId).get();
        const ud = u.data() || {};
        return {
          id: doc.id,
          ...data,
          venue: { name: venueName, address: "" },
          user: {
            username: ud.username || "",
            firstName: ud.firstName || "",
            lastName: ud.lastName || "",
            profileImageUrl: ud.profileImageUrl || undefined,
          },
        };
      })
    );
    const peepTime = d => {
      const c = d.createdAt;
      if (!c) return 0;
      if (typeof c.toMillis === 'function') return c.toMillis();
      if (c.seconds != null) return c.seconds * 1000;
      return 0;
    };
    peeps.sort((a, b) => peepTime(b) - peepTime(a));
    res.json({ peeps: peeps.slice(0, 100) });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Peeps by user error:", error);
    res.status(500).json({ error: "Failed to fetch peeps" });
  }
});

app.get("/peeps/:peepId", authenticateToken, async (req, res) => {
  try {
    const { peepId } = req.params;
    if (peepId === "venue") {
      return res.status(404).json({ error: "Not found" });
    }
    const doc = await db.collection("peeps").doc(peepId).get();
    if (!doc.exists) {
      return res.status(404).json({ error: "Peep not found" });
    }
    const data = doc.data();
    const userDoc = await db.collection("users").doc(data.userId).get();
    const ud = userDoc.data() || {};
    const venueDoc = data.venueId ? await db.collection("venues").doc(data.venueId).get() : null;
    const vd = venueDoc?.data() || {};
    const likeDoc = await db.collection("peeps").doc(peepId).collection("likes").doc(req.user.uid).get();
    const likesSnap = await db.collection("peeps").doc(peepId).collection("likes").limit(5).get();
    const likerPreview = await Promise.all(
      likesSnap.docs.map(async (l) => {
        const uu = await db.collection("users").doc(l.id).get();
        const uud = uu.data() || {};
        return {
          userId: l.id,
          profileImageUrl: uud.profileImageUrl || null,
          username: uud.username || "",
        };
      })
    );
    res.json({
      id: doc.id,
      ...data,
      notes: data.notes || data.description || "",
      photoUrl: data.imageUrl || data.photoUrl || null,
      likedByMe: likeDoc.exists,
      likerPreview,
      user: {
        username: ud.username || "",
        firstName: ud.firstName || "",
        lastName: ud.lastName || "",
        profileImageUrl: ud.profileImageUrl || undefined,
      },
      venue: {
        name: vd.name || "",
        address: vd.address || "",
        id: data.venueId || null,
      },
    });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Peep by id error:", error);
    res.status(500).json({ error: "Failed to fetch peep" });
  }
});

app.post("/peeps/:peepId/share", authenticateToken, async (req, res) => {
  try {
    res.json({ shared: true, message: "Peep shared" });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Peep share error:", error);
    res.status(500).json({ error: "Failed to share" });
  }
});

app.post("/peeps/:peepId/report", authenticateToken, async (req, res) => {
  try {
    const { peepId } = req.params;
    const { reason } = req.body || {};
    await db.collection("reports").add({
      peepId,
      reason: reason || "unknown",
      reportedBy: req.user.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    res.json({ reported: true });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Peep report error:", error);
    res.status(500).json({ error: "Failed to submit report" });
  }
});

app.post("/peeps/:peepId/like", authenticateToken, async (req, res) => {
  try {
    const { peepId } = req.params;
    const userId = req.user.uid;
    const peepRef = db.collection("peeps").doc(peepId);
    const likeRef = peepRef.collection("likes").doc(userId);
    let likedNew = false;
    await db.runTransaction(async (t) => {
      const likeDoc = await t.get(likeRef);
      if (!likeDoc.exists) {
        t.set(likeRef, { likedAt: admin.firestore.FieldValue.serverTimestamp() });
        t.update(peepRef, { likeCount: admin.firestore.FieldValue.increment(1) });
        likedNew = true;
      }
    });
    if (likedNew) {
      const peepDoc = await peepRef.get();
      if (peepDoc.exists && peepDoc.data().userId) {
        await awardPoints(peepDoc.data().userId, 'LIKE_RECEIVED', POINTS_RULES.LIKE_RECEIVED);
      }
    }
    res.json({ liked: true });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Peep like error:", error);
    res.status(500).json({ error: "Failed to like peep" });
  }
});

app.delete("/peeps/:peepId/like", authenticateToken, async (req, res) => {
  try {
    const { peepId } = req.params;
    const userId = req.user.uid;
    const peepRef = db.collection("peeps").doc(peepId);
    const likeRef = peepRef.collection("likes").doc(userId);
    await db.runTransaction(async (t) => {
      const likeDoc = await t.get(likeRef);
      if (likeDoc.exists) {
        t.delete(likeRef);
        t.update(peepRef, { likeCount: admin.firestore.FieldValue.increment(-1) });
      }
    });
    res.json({ liked: false });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Peep unlike error:", error);
    res.status(500).json({ error: "Failed to unlike peep" });
  }
});

app.post("/peeps/:peepId/comments", authenticateToken, async (req, res) => {
  try {
    const { peepId } = req.params;
    const { text } = req.body;
    if (!text || text.trim().length === 0) {
      return res.status(400).json({ error: "Comment text required" });
    }
    const peepRef = db.collection("peeps").doc(peepId);
    const commentRef = await peepRef.collection("comments").add({
      userId: req.user.uid,
      text: text.trim(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await peepRef.update({ commentCount: admin.firestore.FieldValue.increment(1) });
    res.json({ commentId: commentRef.id });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Peep comment create error:", error);
    res.status(500).json({ error: "Failed to post comment" });
  }
});

app.get("/peeps/:peepId/comments", authenticateToken, async (req, res) => {
  try {
    const { peepId } = req.params;
    const snap = await admin
      .firestore()
      .collection("peeps")
      .doc(peepId)
      .collection("comments")
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();
    const comments = await Promise.all(
      snap.docs.map(async (d) => {
        const data = d.data();
        const userDoc = await admin.firestore().collection("users").doc(data.userId).get();
        return { id: d.id, ...data, username: userDoc.data()?.username || "Unknown" };
      })
    );
    res.json({ comments });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Peep comments fetch error:", error);
    res.status(500).json({ error: "Failed to fetch comments" });
  }
});

app.get("/peeps/:peepId/likes", authenticateToken, async (req, res) => {
  try {
    const { peepId } = req.params;
    const snap = await admin
      .firestore()
      .collection("peeps")
      .doc(peepId)
      .collection("likes")
      .limit(50)
      .get();
    res.json({ likers: snap.docs.map((d) => d.id) });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Peep likers fetch error:", error);
    res.status(500).json({ error: "Failed to fetch likers" });
  }
});

// Push Notification Routes
app.post("/notifications/register-token", authenticateToken, [
  body("deviceToken").isLength({ min: 1 }),
  body("platform").isIn(["ios", "android"])
], validateRequest, async (req, res) => {
  try {
    const { deviceToken, platform } = req.body;
    const userId = req.user.uid;

    const result = await notificationService.registerDeviceToken(userId, deviceToken, platform);
    
    if (result.success) {
      res.json({ message: "Device token registered successfully" });
    } else {
      res.status(400).json({ error: result.error });
    }
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Token registration error:", error);
    res.status(500).json({ error: "Failed to register device token" });
  }
});

app.delete("/notifications/unregister-token", authenticateToken, [
  body("deviceToken").isLength({ min: 1 })
], validateRequest, async (req, res) => {
  try {
    const { deviceToken } = req.body;
    const userId = req.user.uid;

    const result = await notificationService.unregisterDeviceToken(userId, deviceToken);
    
    if (result.success) {
      res.json({ message: "Device token unregistered successfully" });
    } else {
      res.status(400).json({ error: result.error });
    }
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Token unregistration error:", error);
    res.status(500).json({ error: "Failed to unregister device token" });
  }
});

// Location Update Route (for geofencing)
app.post("/location/update", authenticateToken, [
  body("latitude").isFloat({ min: -90, max: 90 }),
  body("longitude").isFloat({ min: -180, max: 180 })
], validateRequest, async (req, res) => {
  try {
    const { latitude, longitude } = req.body;
    const userId = req.user.uid;

    // Update user location for geofencing
    await geofencingService.updateUserLocation(userId, latitude, longitude);

    res.json({ message: "Location updated successfully" });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Location update error:", error);
    res.status(500).json({ error: "Failed to update location" });
  }
});

// Geofencing Status Route
app.get("/geofencing/status", authenticateToken, async (req, res) => {
  try {
    const userId = req.user.uid;
    const status = geofencingService.getGeofencingStatus(userId);
    res.json(status);
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Geofencing status error:", error);
    res.status(500).json({ error: "Failed to get geofencing status" });
  }
});

// Error handling middleware
// Points routes
app.get('/users/points', authenticateToken, async (req, res) => {
  try {
    const userDoc = await admin.firestore().collection('users').doc(req.user.uid).get();
    const points = userDoc.data()?.points || 0;
    const history = await admin.firestore()
      .collection('points')
      .where('userId', '==', req.user.uid)
      .orderBy('timestamp', 'desc')
      .limit(20)
      .get();
    const log = history.docs.map(d => ({ id: d.id, ...d.data() }));
    res.json({ points, log });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Leaderboard routes
app.get('/leaderboard/everyone', authenticateToken, async (req, res) => {
  try {
    const snapshot = await admin.firestore()
      .collection('users')
      .orderBy('points', 'desc')
      .limit(50)
      .get();
    const users = snapshot.docs.map((d, i) => ({
      rank: i + 1,
      userId: d.id,
      username: d.data().username,
      points: d.data().points || 0,
      pioneerCount: d.data().pioneerCount || 0,
      profileImageUrl: d.data().profileImageUrl || null,
    }));
    res.json({ leaderboard: users });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/leaderboard/friends', authenticateToken, async (req, res) => {
  try {
    const followingSnap = await admin.firestore()
      .collection('follows')
      .where('followerId', '==', req.user.uid)
      .get();
    const followingIds = [req.user.uid, ...followingSnap.docs.map(d => d.data().followingId)];
    const chunks = [];
    for (let i = 0; i < followingIds.length; i += 10) {
      chunks.push(followingIds.slice(i, i + 10));
    }
    const userDocs = (await Promise.all(
      chunks.map(chunk =>
        admin.firestore().collection('users').where(admin.firestore.FieldPath.documentId(), 'in', chunk).get()
      )
    )).flatMap(s => s.docs);
    const users = userDocs
      .sort((a, b) => (b.data().points || 0) - (a.data().points || 0))
      .map((d, i) => ({
        rank: i + 1,
        userId: d.id,
        username: d.data().username,
        points: d.data().points || 0,
        pioneerCount: d.data().pioneerCount || 0,
        profileImageUrl: d.data().profileImageUrl || null,
      }));
    res.json({ leaderboard: users });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/leaderboard/rank', authenticateToken, async (req, res) => {
  try {
    const userDoc = await admin.firestore().collection('users').doc(req.user.uid).get();
    const myPoints = userDoc.data()?.points || 0;
    const rankSnap = await admin.firestore()
      .collection('users')
      .where('points', '>', myPoints)
      .get();
    const rank = rankSnap.size + 1;
    res.json({ rank, points: myPoints });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/search/venues', authenticateToken, async (req, res) => {
  try {
    const { q } = req.query;
    if (!q || q.trim().length < 2) return res.status(400).json({ error: 'Query must be at least 2 characters' });
    const term = q.toLowerCase().trim();
    const snap = await db.collection('venues')
      .orderBy('nameLower')
      .startAt(term)
      .endAt(term + '\uf8ff')
      .limit(20)
      .get();
    const venues = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    res.json({ venues });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('Search venues error:', error);
    res.status(500).json({ error: 'Failed to search venues' });
  }
});

app.get('/search/venues/nearby', authenticateToken, async (req, res) => {
  try {
    const { lat, lng, radius = 1 } = req.query;
    if (!lat || !lng) return res.status(400).json({ error: 'lat and lng required' });
    const center = [parseFloat(lat), parseFloat(lng)];
    const radiusInM = parseFloat(radius) * 1000;
    const bounds = geofire.geohashQueryBounds(center, radiusInM);
    const snaps = await Promise.all(
      bounds.map(b => db.collection('venues').orderBy('geohash').startAt(b[0]).endAt(b[1]).get())
    );
    const venues = snaps.flatMap(s => s.docs).filter(d => {
      const { lat: vLat, lng: vLng } = d.data();
      return geofire.distanceBetween([vLat, vLng], center) <= parseFloat(radius);
    }).map(d => ({ id: d.id, ...d.data() }));
    res.json({ venues });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('Search venues nearby error:', error);
    res.status(500).json({ error: 'Failed to search nearby venues' });
  }
});

app.get(
  '/venues/:venueId/crowd-history',
  authenticateToken,
  requireVIP,
  async (req, res) => {
    try {
      const { venueId } = req.params;
      const { hours = 12 } = req.query;
      const hoursInt = Math.min(Math.max(parseInt(String(hours), 10) || 12, 1), 24);
      const since = new Date(Date.now() - hoursInt * 60 * 60 * 1000);

      const snap = await db
        .collection('peeps')
        .where('venueId', '==', venueId)
        .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(since))
        .orderBy('createdAt', 'asc')
        .get();

      const buckets = {};
      for (let i = 0; i < hoursInt; i++) {
        const bucketTime = new Date(since.getTime() + i * 60 * 60 * 1000);
        const key = bucketTime.toISOString().slice(0, 13);
        buckets[key] = { hour: key, peepCount: 0, totalCrowdSize: 0, avgCrowdSize: 0 };
      }

      snap.docs.forEach((doc) => {
        const data = doc.data();
        const peepTime = data.createdAt?.toDate
          ? data.createdAt.toDate()
          : new Date(data.createdAt);
        const key = peepTime.toISOString().slice(0, 13);
        if (buckets[key]) {
          buckets[key].peepCount++;
          buckets[key].totalCrowdSize += data.crowdSize || 0;
          buckets[key].avgCrowdSize =
            buckets[key].totalCrowdSize / buckets[key].peepCount;
        }
      });

      const dataPoints = Object.values(buckets).map((b) => ({
        hour: b.hour,
        peepCount: b.peepCount,
        avgCrowdSize: parseFloat(b.avgCrowdSize.toFixed(1)),
      }));

      res.json({ venueId, hours: hoursInt, dataPoints });
    } catch (error) {
      Sentry.captureException(error);
      logger.error('Crowd history error:', error);
      res.status(500).json({ error: 'Failed to load crowd history' });
    }
  }
);

app.get('/search/venues/city', authenticateToken, async (req, res) => {
  try {
    const { city } = req.query;
    if (!city) return res.status(400).json({ error: 'city required' });
    const snap = await db.collection('venues')
      .where('cityLower', '==', city.toLowerCase().trim())
      .limit(50)
      .get();
    res.json({ venues: snap.docs.map(d => ({ id: d.id, ...d.data() })) });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('Search venues by city error:', error);
    res.status(500).json({ error: 'Failed to search venues by city' });
  }
});

app.get('/search/users', authenticateToken, async (req, res) => {
  try {
    const { q } = req.query;
    if (!q || q.trim().length < 2) return res.status(400).json({ error: 'Query must be at least 2 characters' });
    const term = q.toLowerCase().trim();
    const snap = await db.collection('users')
      .orderBy('usernameLower')
      .startAt(term)
      .endAt(term + '\uf8ff')
      .limit(20)
      .get();
    res.json({ users: snap.docs.map(d => ({ id: d.id, username: d.data().username, profileImageUrl: d.data().profileImageUrl })) });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('Search users error:', error);
    res.status(500).json({ error: 'Failed to search users' });
  }
});

app.get('/users/favorites', authenticateToken, async (req, res) => {
  try {
    const snap = await db
      .collection('users').doc(req.user.uid)
      .collection('favorites')
      .orderBy('addedAt', 'desc')
      .get();
    const favorites = await Promise.all(snap.docs.map(async (d) => {
      const venueDoc = await db.collection('venues').doc(d.data().venueId).get();
      const latestPeep = await db.collection('peeps')
        .where('venueId', '==', d.data().venueId)
        .orderBy('createdAt', 'desc')
        .limit(1)
        .get();
      return {
        venueId: d.data().venueId,
        ...venueDoc.data(),
        currentCrowdSize: latestPeep.docs[0]?.data()?.crowdSize || null,
        lastPeepAt: latestPeep.docs[0]?.data()?.createdAt || null,
      };
    }));
    res.json({ favorites });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('Favorites fetch error:', error);
    res.status(500).json({ error: 'Failed to fetch favorites' });
  }
});

app.post('/users/favorites/:venueId', authenticateToken, async (req, res) => {
  try {
    const { venueId } = req.params;
    await db
      .collection('users').doc(req.user.uid)
      .collection('favorites').doc(venueId)
      .set({ venueId, addedAt: admin.firestore.FieldValue.serverTimestamp() });
    res.json({ favorited: true });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('Favorite add error:', error);
    res.status(500).json({ error: 'Failed to add favorite' });
  }
});

app.delete('/users/favorites/:venueId', authenticateToken, async (req, res) => {
  try {
    const { venueId } = req.params;
    await db
      .collection('users').doc(req.user.uid)
      .collection('favorites').doc(venueId)
      .delete();
    res.json({ favorited: false });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('Favorite remove error:', error);
    res.status(500).json({ error: 'Failed to remove favorite' });
  }
});

app.delete('/users/account', authenticateToken, async (req, res) => {
  try {
    await db.collection('users').doc(req.user.uid).delete();
    res.json({ deleted: true });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('Delete account error:', error);
    res.status(500).json({ error: 'Failed to delete account' });
  }
});

app.post('/groups', authenticateToken, async (req, res) => {
  try {
    const { name, description, isPublic = true } = req.body || {};
    if (!name) return res.status(400).json({ error: 'Group name required' });
    const groupRef = await db.collection('groups').add({
      name,
      description: description || '',
      isPublic,
      creatorId: req.user.uid,
      memberCount: 1,
      peepsToday: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await groupRef.collection('members').doc(req.user.uid).set({
      joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      role: 'admin',
    });
    await db.collection('users').doc(req.user.uid).set(
      { groupIds: admin.firestore.FieldValue.arrayUnion(groupRef.id) },
      { merge: true }
    );
    res.json({ groupId: groupRef.id });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('Group create error:', error);
    res.status(500).json({ error: 'Failed to create group' });
  }
});

app.get('/groups', authenticateToken, async (req, res) => {
  try {
    const snap = await db
      .collection('groups')
      .where('isPublic', '==', true)
      .orderBy('memberCount', 'desc')
      .limit(20)
      .get();
    res.json({ groups: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('Groups list error:', error);
    res.json({ groups: [] });
  }
});

app.get('/groups/mine', authenticateToken, async (req, res) => {
  try {
    const u = await db.collection('users').doc(req.user.uid).get();
    const ids = u.data()?.groupIds || [];
    const out = [];
    for (const gid of ids) {
      const g = await db.collection('groups').doc(gid).get();
      if (!g.exists) continue;
      const data = g.data();
      const membersSnap = await g.ref.collection('members').get();
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      out.push({
        id: g.id,
        name: data.name || 'Group',
        photoUrl: data.photoUrl || null,
        memberCount: membersSnap.size,
        peepsToday: data.peepsToday || 0,
      });
    }
    res.json({ groups: out });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('My groups error:', error);
    res.json({ groups: [] });
  }
});

app.get('/groups/:groupId/peeps', authenticateToken, async (req, res) => {
  try {
    const { groupId } = req.params;
    const snap = await db
      .collection('peeps')
      .where('sharedToGroups', 'array-contains', groupId)
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();
    res.json({ peeps: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('Group peeps error:', error);
    res.status(500).json({ error: 'Failed to load group peeps' });
  }
});

app.post('/groups/:groupId/join', authenticateToken, async (req, res) => {
  try {
    const { groupId } = req.params;
    const groupRef = db.collection('groups').doc(groupId);
    const g = await groupRef.get();
    if (!g.exists) {
      return res.status(404).json({ error: 'Group not found' });
    }
    await groupRef.collection('members').doc(req.user.uid).set({
      joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      role: 'member',
    });
    await groupRef.update({ memberCount: admin.firestore.FieldValue.increment(1) });
    await db.collection('users').doc(req.user.uid).set(
      { groupIds: admin.firestore.FieldValue.arrayUnion(groupId) },
      { merge: true }
    );
    res.json({ joined: true });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('Group join error:', error);
    res.status(500).json({ error: 'Failed to join group' });
  }
});

app.delete('/groups/:groupId/leave', authenticateToken, async (req, res) => {
  try {
    const { groupId } = req.params;
    const groupRef = db.collection('groups').doc(groupId);
    await groupRef.collection('members').doc(req.user.uid).delete();
    await groupRef.update({ memberCount: admin.firestore.FieldValue.increment(-1) });
    await db.collection('users').doc(req.user.uid).set(
      { groupIds: admin.firestore.FieldValue.arrayRemove(groupId) },
      { merge: true }
    );
    res.json({ joined: false });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('Group leave error:', error);
    res.status(500).json({ error: 'Failed to leave group' });
  }
});

app.post('/groups/:groupId/share', authenticateToken, async (req, res) => {
  try {
    const { groupId } = req.params;
    const { peepId } = req.body || {};
    if (!peepId) return res.status(400).json({ error: 'peepId required' });
    await db.collection('peeps').doc(peepId).update({
      sharedToGroups: admin.firestore.FieldValue.arrayUnion(groupId),
    });
    res.json({ shared: true });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('Group share error:', error);
    res.status(500).json({ error: 'Failed to share to group' });
  }
});

app.get('/notifications', authenticateToken, async (req, res) => {
  try {
    const snap = await db.collection('notifications')
      .where('userId', '==', req.user.uid)
      .limit(50)
      .get();
    const notifications = snap.docs.map(d => {
      const x = d.data();
      return {
        id: d.id,
        ...x,
        createdAt: x.createdAt?.toDate?.()?.toISOString?.() || x.createdAt || new Date().toISOString(),
      };
    });
    notifications.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    res.json({ notifications });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('Notifications fetch error:', error);
    res.json({ notifications: [] });
  }
});

app.patch('/notifications/:notificationId/read', authenticateToken, async (req, res) => {
  try {
    await db.collection('notifications').doc(req.params.notificationId).update({
      read: true,
      readAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    res.json({ ok: true });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('Notification read error:', error);
    res.status(500).json({ error: 'Failed to mark read' });
  }
});

app.patch('/notifications/read-all', authenticateToken, async (req, res) => {
  try {
    const snap = await db.collection('notifications')
      .where('userId', '==', req.user.uid)
      .get();
    const batch = db.batch();
    snap.docs.forEach(d => batch.update(d.ref, { read: true }));
    await batch.commit();
    res.json({ ok: true });
  } catch (error) {
    Sentry.captureException(error);
    logger.error('Notifications read all error:', error);
    res.status(500).json({ error: 'Failed' });
  }
});

// --- Merchant portal (Tasks 57–66) ---

app.post("/merchant/signin", async (req, res) => {
  try {
    const { merchantNumber, email, password } = req.body || {};
    if (!merchantNumber || !email || !password) {
      return res
        .status(400)
        .json({ error: "Merchant number, email and password required" });
    }
    void password;

    const userRecord = await admin.auth().getUserByEmail(email);

    const snap = await db
      .collection("merchant_accounts")
      .where("merchantNumber", "==", merchantNumber)
      .where("email", "==", email)
      .limit(1)
      .get();

    if (snap.empty) {
      return res.status(401).json({ error: "Invalid merchant number or email" });
    }

    const merchant = { id: snap.docs[0].id, ...snap.docs[0].data() };
    res.json({ merchant, uid: userRecord.uid });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Merchant signin error:", error);
    res.status(401).json({ error: "Invalid credentials" });
  }
});

app.post("/merchant/setup", authenticateToken, async (req, res) => {
  try {
    const {
      businessName,
      category,
      address,
      city,
      contactName,
      email,
      phone,
    } = req.body || {};
    const merchantNumber = generateMerchantNumber();
    const docRef = await db.collection("merchant_accounts").add({
      businessName,
      category,
      address,
      city,
      contactName,
      email,
      phone,
      merchantNumber,
      ownerId: req.user.uid,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    res.json({ merchantId: docRef.id, merchantNumber });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Merchant setup error:", error);
    res.status(500).json({ error: "Setup failed" });
  }
});

app.get("/merchant/ads", authenticateToken, async (req, res) => {
  try {
    const { merchantId } = req.query;
    if (!merchantId) {
      return res.status(400).json({ error: "merchantId required" });
    }
    const snap = await db
      .collection("merchant_ads")
      .where("merchantId", "==", merchantId)
      .get();
    const ads = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    ads.sort((a, b) => {
      const ta = a.createdAt?.toMillis?.() ?? 0;
      const tb = b.createdAt?.toMillis?.() ?? 0;
      return tb - ta;
    });
    res.json({ ads });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Merchant ads list error:", error);
    res.status(500).json({ error: "Failed to load ads" });
  }
});

app.post("/merchant/ads", authenticateToken, async (req, res) => {
  try {
    const { merchantId, offerText, startTime, endTime, rateType } = req.body || {};
    if (!offerText || offerText.length > 40) {
      return res
        .status(400)
        .json({ error: "Offer text required, max 40 chars" });
    }
    const rates = { basic: 10, standard: 25, premium: 50 };
    const ratePerHour = rates[rateType];
    if (!ratePerHour) {
      return res.status(400).json({ error: "Invalid rate type" });
    }
    const start = new Date(startTime);
    const end = new Date(endTime);
    const hours = (end - start) / 3600000;
    if (hours <= 0) {
      return res.status(400).json({ error: "End time must be after start time" });
    }
    const totalCost = parseFloat((hours * ratePerHour).toFixed(2));
    const merchantDoc = await db.collection("merchant_accounts").doc(merchantId).get();
    if (!merchantDoc.exists) {
      return res.status(404).json({ error: "Merchant not found" });
    }
    const m = merchantDoc.data();
    const adRef = await db.collection("merchant_ads").add({
      merchantId,
      offerText,
      startTime: admin.firestore.Timestamp.fromDate(start),
      endTime: admin.firestore.Timestamp.fromDate(end),
      rateType,
      ratePerHour,
      totalCost,
      status: start <= new Date() ? "live" : "pending",
      impressions: 0,
      claims: 0,
      venueRadius: 1,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lat: m.lat ?? null,
      lng: m.lng ?? null,
    });
    res.json({ adId: adRef.id, totalCost });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Merchant ad create error:", error);
    res.status(500).json({ error: "Failed to create ad" });
  }
});

app.get("/merchant/feed", authenticateToken, async (req, res) => {
  try {
    void req.query;
    const snap = await db
      .collection("merchant_ads")
      .where("status", "==", "live")
      .limit(20)
      .get();
    const ads = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    const batch = db.batch();
    snap.docs.forEach((d) =>
      batch.update(d.ref, {
        impressions: admin.firestore.FieldValue.increment(1),
      })
    );
    await batch.commit();
    res.json({ ads });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Merchant feed error:", error);
    res.status(500).json({ error: "Feed failed" });
  }
});

app.post("/merchant/ads/:adId/claim", authenticateToken, async (req, res) => {
  try {
    const adRef = db.collection("merchant_ads").doc(req.params.adId);
    await adRef.update({ claims: admin.firestore.FieldValue.increment(1) });
    res.json({ claimed: true });
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Merchant ad claim error:", error);
    res.status(500).json({ error: "Claim failed" });
  }
});

// Main feed — most recent peeps across all venues
app.get("/feed", authenticateToken, async (req, res) => {
  try {
    const snapshot = await admin
      .firestore()
      .collection("peeps")
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();
    const peeps = snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
    res.json({ peeps });
  } catch (e) {
    Sentry.captureException(e);
    logger.error("GET /feed error:", e);
    res.status(500).json({ error: e.message });
  }
});

// Single venue by ID
app.get("/venues/:venueId", authenticateToken, async (req, res) => {
  try {
    const doc = await admin
      .firestore()
      .collection("venues")
      .doc(req.params.venueId)
      .get();
    if (!doc.exists) {
      return res.status(404).json({ error: "Venue not found" });
    }
    res.json({ venue: { id: doc.id, ...doc.data() } });
  } catch (e) {
    Sentry.captureException(e);
    logger.error("GET /venues/:venueId error:", e);
    res.status(500).json({ error: e.message });
  }
});

cron.schedule("* * * * *", async () => {
  try {
    const now = admin.firestore.Timestamp.now();
    const pendingSnap = await db
      .collection("merchant_ads")
      .where("status", "==", "pending")
      .where("startTime", "<=", now)
      .get();
    const liveSnap = await db
      .collection("merchant_ads")
      .where("status", "==", "live")
      .where("endTime", "<=", now)
      .get();
    const batch = db.batch();
    pendingSnap.docs.forEach((d) => batch.update(d.ref, { status: "live" }));
    liveSnap.docs.forEach((d) => batch.update(d.ref, { status: "ended" }));
    await batch.commit();
  } catch (error) {
    Sentry.captureException(error);
    logger.error("Merchant ad status cron error:", error);
  }
});

app.use((error, req, res, _next) => {
  Sentry.captureException(error);
  logger.error("Unhandled error:", error);
  res.status(500).json({ error: "Internal server error" });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: "Route not found" });
});

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  logger.info(`Peepl 2025 Backend Server running on port ${PORT}`);
  logger.info(`Environment: ${process.env.NODE_ENV || "development"}`);
});

// Start geofencing service
geofencingService.start();

// Graceful shutdown
process.on("SIGTERM", () => {
  logger.info("SIGTERM received, shutting down gracefully");
  geofencingService.stop();
  server.close(() => {
    logger.info("Process terminated");
    process.exit(0);
  });
});

module.exports = app;