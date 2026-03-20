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
const geofencingService = require("./src/services/GeofencingService");
const { calculateDistance } = require("./src/utils/geo");

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
  body("rating").optional().isInt({ min: 1, max: 5 }),
  body("latitude").optional().isFloat({ min: -90, max: 90 }),
  body("longitude").optional().isFloat({ min: -180, max: 180 })
], validateRequest, async (req, res) => {
  try {
    const { venueId, description, rating, latitude, longitude } = req.body;
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
      rating: rating ? parseInt(rating) : null,
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

    // Update venue statistics
    const venueData = venueDoc.data();
    const newPeepCount = (venueData.peepCount || 0) + 1;
    let newAverageRating = venueData.averageRating || 0;
    let newTotalRatings = venueData.totalRatings || 0;

    if (rating) {
      newTotalRatings += 1;
      newAverageRating = ((venueData.averageRating || 0) * (newTotalRatings - 1) + parseInt(rating)) / newTotalRatings;
    }

    await db.collection("venues").doc(venueId).update({
      peepCount: newPeepCount,
      averageRating: newAverageRating,
      totalRatings: newTotalRatings,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Emit real-time update
    io.to(`venue_${venueId}`).emit("new_peep", {
      peepId: peepRef.id,
      ...peepData
    });

    logger.info(`New peep created: ${peepRef.id} by ${userId}`);
    res.status(201).json({
      message: "Peep created successfully",
      peepId: peepRef.id
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