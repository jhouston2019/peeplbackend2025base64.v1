const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

// Initialize Firebase Admin
const firebaseBase64 = process.env.FIREBASE_CONFIG_B64;
if (!firebaseBase64) {
  console.error('FIREBASE_CONFIG_B64 not set in environment variables');
  process.exit(1);
}

const firebaseJson = Buffer.from(firebaseBase64, 'base64').toString('utf8');
const serviceAccount = JSON.parse(firebaseJson);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET || 'peepl-2025.appspot.com'
});

const db = admin.firestore();

async function backupDatabase(backupDir = null) {
  try {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupPath = backupDir || path.join('backups', `backup-${timestamp}`);
    
    // Create backup directory
    if (!fs.existsSync(backupPath)) {
      fs.mkdirSync(backupPath, { recursive: true });
    }

    console.log(`🚀 Starting database backup to: ${backupPath}`);

    // Collections to backup
    const collections = ['users', 'venues', 'peeps', 'user_locations', 'geofence_events'];

    for (const collectionName of collections) {
      console.log(`📦 Backing up collection: ${collectionName}`);
      
      const snapshot = await db.collection(collectionName).get();
      const data = [];
      
      snapshot.forEach(doc => {
        data.push({
          id: doc.id,
          ...doc.data()
        });
      });

      // Write to file
      const filePath = path.join(backupPath, `${collectionName}.json`);
      fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
      
      console.log(`✅ Backed up ${data.length} documents from ${collectionName}`);
    }

    // Create backup metadata
    const metadata = {
      timestamp: new Date().toISOString(),
      collections: collections,
      totalDocuments: 0,
      version: '2.0.0'
    };

    // Count total documents
    for (const collectionName of collections) {
      const filePath = path.join(backupPath, `${collectionName}.json`);
      const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      metadata.totalDocuments += data.length;
    }

    // Write metadata
    fs.writeFileSync(path.join(backupPath, 'metadata.json'), JSON.stringify(metadata, null, 2));

    console.log('🎉 Database backup completed successfully!');
    console.log(`📊 Total documents backed up: ${metadata.totalDocuments}`);
    console.log(`📁 Backup location: ${backupPath}`);

    return backupPath;

  } catch (error) {
    console.error('❌ Database backup failed:', error);
    throw error;
  }
}

// Run backup if called directly
if (require.main === module) {
  const backupDir = process.argv[2];
  backupDatabase(backupDir).then((backupPath) => {
    console.log(`✅ Backup completed: ${backupPath}`);
    process.exit(0);
  }).catch((error) => {
    console.error('❌ Backup failed:', error);
    process.exit(1);
  });
}

module.exports = { backupDatabase };
