const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const compression = require("compression");
const rateLimit = require("express-rate-limit");
const multer = require("multer");
const admin = require("firebase-admin");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const { body, validationResult } = require("express-validator");
const { createServer } = require("http");
const { Server } = require("socket.io");
const cron = require("node-cron");
const axios = require("axios");
const winston = require("winston");
const geofire = require("geofire-common");
require("dotenv").config();

// Import services
const notificationService = require("./src/services/NotificationService");
const { triggerCrowdConfirmationIfNeeded } = require("./src/services/NotificationService");
const geofencingService = require("./src/services/GeofencingService");
const { calculateDistance } = require("./src/utils/geo");
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
const auth = admin.auth();
const storage = admin.storage();

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
    logger.error("Firebase Auth verification failed:", error);
    return res.status(403).json({ error: "Invalid or expired token" });
  }
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
    logger.error("Profile fetch error:", error);
    res.status(500).json({ error: "Failed to fetch profile" });
  }
});

app.put("/users/profile", authenticateToken, [
  body("username").optional().isLength({ min: 3, max: 30 }),
  body("firstName").optional().isLength({ min: 1, max: 50 }),
  body("lastName").optional().isLength({ min: 1, max: 50 }),
  body("bio").optional().isLength({ max: 500 })
], validateRequest, async (req, res) => {
  try {
    const allowedFields = ['username', 'firstName', 'lastName', 'bio', 'profileImageUrl', 'preferences'];
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
    logger.error("Profile update error:", error);
    res.status(500).json({ error: "Failed to update profile" });
  }
});

// Venue Routes
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
    const venueData = {
      ...req.body,
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
    logger.error("Venue creation error:", error);
    res.status(500).json({ error: "Failed to create venue" });
  }
});

// Peep Routes
app.post("/peeps", authenticateToken, upload.single("photo"), [
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
    triggerCrowdConfirmationIfNeeded(venueId, venueName).catch(e =>
      logger.error('Push trigger failed:', e)
    );

    res.status(201).json({
      message: "Peep created successfully",
      peepId: peepRef.id,
      isPioneer
    });
  } catch (error) {
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
    logger.error("Peeps fetch error:", error);
    res.status(500).json({ error: "Failed to fetch peeps" });
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
    logger.error('Search venues nearby error:', error);
    res.status(500).json({ error: 'Failed to search nearby venues' });
  }
});

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
    logger.error('Favorite remove error:', error);
    res.status(500).json({ error: 'Failed to remove favorite' });
  }
});

app.use((error, req, res, next) => {
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