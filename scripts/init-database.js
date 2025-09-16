const admin = require('firebase-admin');
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

async function initializeDatabase() {
  try {
    console.log('🚀 Initializing Peepl 2025 database...');

    // Create sample venues
    const sampleVenues = [
      {
        name: 'Coffee Corner',
        address: '123 Main St, San Francisco, CA',
        latitude: 37.7749,
        longitude: -122.4194,
        category: 'Coffee Shop',
        description: 'Cozy coffee shop with great atmosphere and friendly staff',
        peepCount: 0,
        averageRating: 0,
        totalRatings: 0,
        createdBy: 'system',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true
      },
      {
        name: 'Pizza Palace',
        address: '456 Oak Ave, San Francisco, CA',
        latitude: 37.7849,
        longitude: -122.4094,
        category: 'Restaurant',
        description: 'Best pizza in town with authentic Italian recipes',
        peepCount: 0,
        averageRating: 0,
        totalRatings: 0,
        createdBy: 'system',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true
      },
      {
        name: 'Green Park',
        address: '789 Pine St, San Francisco, CA',
        latitude: 37.7649,
        longitude: -122.4294,
        category: 'Park',
        description: 'Beautiful park perfect for outdoor activities and relaxation',
        peepCount: 0,
        averageRating: 0,
        totalRatings: 0,
        createdBy: 'system',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true
      }
    ];

    // Add sample venues
    for (const venue of sampleVenues) {
      const venueRef = await db.collection('venues').add(venue);
      console.log(`✅ Created venue: ${venue.name} (ID: ${venueRef.id})`);
    }

    // Create database indexes (Firestore will create them automatically when needed)
    console.log('📊 Database indexes will be created automatically when queries are made');

    // Create sample user (for testing)
    const sampleUser = {
      uid: 'sample-user-123',
      email: 'test@peepl.com',
      username: 'testuser',
      firstName: 'Test',
      lastName: 'User',
      password: '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4J/8KzKz2K', // password: test123
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true,
      profileImageUrl: null,
      bio: 'Test user for Peepl 2025',
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

    await db.collection('users').doc('sample-user-123').set(sampleUser);
    console.log('✅ Created sample user: test@peepl.com (password: test123)');

    // Create Firestore security rules
    const securityRules = `
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Venues are publicly readable, only authenticated users can create
    match /venues/{venueId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
        (resource.data.createdBy == request.auth.uid || 
         request.auth.token.admin == true);
    }
    
    // Peeps are publicly readable, only authenticated users can create
    match /peeps/{peepId} {
      allow read: if true;
      allow create: if request.auth != null && 
        request.auth.uid == resource.data.userId;
      allow update: if request.auth != null && 
        request.auth.uid == resource.data.userId;
    }
    
    // User locations are private
    match /user_locations/{userId} {
      allow read, write: if request.auth != null && 
        request.auth.uid == userId;
    }
    
    // Geofence events are private
    match /geofence_events/{eventId} {
      allow read, write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
    }
  }
}`;

    console.log('🔒 Security rules created (copy to Firebase Console):');
    console.log(securityRules);

    console.log('🎉 Database initialization completed successfully!');
    console.log('');
    console.log('📋 Next steps:');
    console.log('1. Copy the security rules above to Firebase Console > Firestore > Rules');
    console.log('2. Test the API endpoints');
    console.log('3. Test user login with: test@peepl.com / test123');
    console.log('4. Start the mobile app and test features');

  } catch (error) {
    console.error('❌ Database initialization failed:', error);
    process.exit(1);
  }
}

// Run initialization
initializeDatabase().then(() => {
  console.log('✅ Database initialization script completed');
  process.exit(0);
}).catch((error) => {
  console.error('❌ Database initialization script failed:', error);
  process.exit(1);
});
