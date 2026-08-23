const admin = require('firebase-admin');

const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const RENFEST = {
  locationName: 'Georgia Renaissance Festival',
  venueName: 'Georgia Renaissance Festival',
  address: '6905 Virlyn B Smith Rd, Fairburn, GA 30213',
  latitude: 33.5649819,
  longitude: -84.6028081,
};

// Posts from the Fairburn festival that were incorrectly reverted to Cochran Rd.
const RENFEST_POST_IDS = [
  '6APKBXhG3AqVDEeyyOX0',
  'VFU5bfBpE6wnBADTYuVn',
  'nLWEL6Ep6wtzbi9rOa9g',
  'yWGgqtvGJtoUslwhju8r',
  'ol9wBKj0klpNgvMFYirq',
];

async function fixRenFestPosts() {
  console.log('Restoring Georgia Renaissance Festival labels...');

  for (const id of RENFEST_POST_IDS) {
    const ref = db.collection('location_posts').doc(id);
    const snap = await ref.get();
    if (!snap.exists) {
      console.log(`SKIP: ${id} not found`);
      continue;
    }

    const before = snap.data().locationName;
    await ref.update({ ...RENFEST });
    console.log(`UPDATED ${id}: "${before}" → "${RENFEST.locationName}"`);
  }

  console.log('Done.');
  process.exit(0);
}

fixRenFestPosts().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
