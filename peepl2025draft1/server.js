const express = require("express");
const multer = require("multer");
const admin = require("firebase-admin");

const app = express();
const upload = multer({ storage: multer.memoryStorage() });

// Decode base64-encoded Firebase config
const firebaseBase64 = process.env.FIREBASE_CONFIG_B64;
if (!firebaseBase64) {
  console.error("FIREBASE_CONFIG_B64 not set");
  process.exit(1);
}
const firebaseJson = Buffer.from(firebaseBase64, 'base64').toString('utf8');
const serviceAccount = JSON.parse(firebaseJson);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: "crowd-checker-7bd94.appspot.com"
});

const db = admin.firestore();

app.use(express.json());

app.post("/upload", upload.single("photo"), async (req, res) => {
  try {
    const data = {
      location: req.body.location,
      description: req.body.description,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (req.file) {
      const bucket = admin.storage().bucket();
      const file = bucket.file(Date.now() + "_" + req.file.originalname);
      await file.save(req.file.buffer, {
        metadata: { contentType: req.file.mimetype },
      });
      await file.makePublic();
      data.imageUrl = file.publicUrl();
    }

    const docRef = await db.collection("reports").add(data);
    res.status(200).json({ id: docRef.id, ...data });
  } catch (err) {
    console.error(err);
    res.status(500).send("Error uploading report");
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
