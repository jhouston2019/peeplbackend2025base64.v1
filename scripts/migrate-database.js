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

async function migrateFrom2019() {
  try {
    console.log('🚀 Starting migration from Peepl 2019 to Peepl 2025...');

    // This is a placeholder for migrating from the old 2019 version
    // You would need to implement the actual migration logic based on your old data structure

    console.log('📋 Migration steps:');
    console.log('1. Export data from old DynamoDB/AWS system');
    console.log('2. Transform data to new Firestore structure');
    console.log('3. Import data to new Firestore database');
    console.log('4. Verify data integrity');
    console.log('5. Update user references');

    // Example migration for venues
    const oldVenues = [
      // This would come from your old system
      {
        id: 'old-venue-1',
        name: 'Old Coffee Shop',
        address: '123 Old St',
        latitude: 37.7749,
        longitude: -122.4194,
        category: 'Coffee',
        // ... other old fields
      }
    ];

    for (const oldVenue of oldVenues) {
      // Transform to new structure
      const newVenue = {
        name: oldVenue.name,
        address: oldVenue.address,
        latitude: oldVenue.latitude,
        longitude: oldVenue.longitude,
        category: oldVenue.category,
        description: oldVenue.description || '',
        peepCount: 0,
        averageRating: 0,
        totalRatings: 0,
        createdBy: 'migrated',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true
      };

      // Add to new database
      const venueRef = await db.collection('venues').add(newVenue);
      console.log(`✅ Migrated venue: ${oldVenue.name} -> ${venueRef.id}`);
    }

    // Example migration for users
    const oldUsers = [
      // This would come from your old system
      {
        id: 'old-user-1',
        email: 'user@example.com',
        username: 'olduser',
        // ... other old fields
      }
    ];

    for (const oldUser of oldUsers) {
      // Transform to new structure
      const newUser = {
        uid: oldUser.id,
        email: oldUser.email,
        username: oldUser.username,
        firstName: oldUser.firstName || '',
        lastName: oldUser.lastName || '',
        password: oldUser.password || '', // You'll need to hash this
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true,
        profileImageUrl: oldUser.profileImageUrl || null,
        bio: oldUser.bio || '',
        location: null,
        preferences: {
          notifications: true,
          locationSharing: true,
          publicProfile: true,
          locationNotifications: true,
          socialNotifications: true
        },
        deviceTokens: []
      };

      // Add to new database
      await db.collection('users').doc(oldUser.id).set(newUser);
      console.log(`✅ Migrated user: ${oldUser.email}`);
    }

    console.log('🎉 Migration completed successfully!');
    console.log('');
    console.log('📋 Post-migration steps:');
    console.log('1. Verify all data was migrated correctly');
    console.log('2. Test user authentication');
    console.log('3. Test venue functionality');
    console.log('4. Update any hardcoded references');
    console.log('5. Notify users of the migration');

  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  }
}

async function migrateFromBackup(backupPath) {
  try {
    console.log(`🚀 Starting migration from backup: ${backupPath}`);

    if (!fs.existsSync(backupPath)) {
      throw new Error(`Backup path does not exist: ${backupPath}`);
    }

    // Read metadata
    const metadataPath = path.join(backupPath, 'metadata.json');
    if (!fs.existsSync(metadataPath)) {
      throw new Error('Metadata file not found in backup');
    }

    const metadata = JSON.parse(fs.readFileSync(metadataPath, 'utf8'));
    console.log(`📊 Backup metadata:`, metadata);

    // Restore collections
    for (const collectionName of metadata.collections) {
      const filePath = path.join(backupPath, `${collectionName}.json`);
      
      if (!fs.existsSync(filePath)) {
        console.log(`⚠️  Skipping ${collectionName} - file not found`);
        continue;
      }

      console.log(`📦 Restoring collection: ${collectionName}`);
      
      const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      
      for (const doc of data) {
        const { id, ...docData } = doc;
        
        if (id) {
          await db.collection(collectionName).doc(id).set(docData);
        } else {
          await db.collection(collectionName).add(docData);
        }
      }
      
      console.log(`✅ Restored ${data.length} documents to ${collectionName}`);
    }

    console.log('🎉 Backup restoration completed successfully!');

  } catch (error) {
    console.error('❌ Backup restoration failed:', error);
    throw error;
  }
}

// Run migration if called directly
if (require.main === module) {
  const command = process.argv[2];
  const path = process.argv[3];

  if (command === 'from-2019') {
    migrateFrom2019().then(() => {
      console.log('✅ Migration from 2019 completed');
      process.exit(0);
    }).catch((error) => {
      console.error('❌ Migration failed:', error);
      process.exit(1);
    });
  } else if (command === 'from-backup') {
    if (!path) {
      console.error('❌ Please provide backup path');
      process.exit(1);
    }
    
    migrateFromBackup(path).then(() => {
      console.log('✅ Backup restoration completed');
      process.exit(0);
    }).catch((error) => {
      console.error('❌ Backup restoration failed:', error);
      process.exit(1);
    });
  } else {
    console.log('Usage:');
    console.log('  node migrate-database.js from-2019');
    console.log('  node migrate-database.js from-backup <backup-path>');
    process.exit(1);
  }
}

module.exports = { migrateFrom2019, migrateFromBackup };
