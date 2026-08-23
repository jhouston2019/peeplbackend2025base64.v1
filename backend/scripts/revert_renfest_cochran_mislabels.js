const admin = require('firebase-admin');

const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Gainesville residence — NOT the Fairburn Renaissance Festival.
const COCHRAN_RESIDENCE = {
  locationName: '3633 Cochran Rd, Gainesville, GA',
  address: '3633 Cochran Rd, Gainesville, GA',
  latitude: 34.3690721,
  longitude: -83.8621006,
};

// Posts incorrectly relabeled as Georgia Renaissance Festival in build 193.
const COCHRAN_POST_IDS = [
  '6APKBXhG3AqVDEeyyOX0',
  'VFU5bfBpE6wnBADTYuVn',
  'nLWEL6Ep6wtzbi9rOa9g',
  'yWGgqtvGJtoUslwhju8r',
  'ol9wBKj0klpNgvMFYirq',
];

async function revertCochranMislabels() {
  console.log('Reverting Cochran Rd posts mislabeled as Renaissance Festival...');

  for (const id of COCHRAN_POST_IDS) {
    const ref = db.collection('location_posts').doc(id);
    const snap = await ref.get();
    if (!snap.exists) {
      console.log(`SKIP: ${id} not found`);
      continue;
    }

    const before = snap.data().locationName;
    await ref.update({
      locationName: COCHRAN_RESIDENCE.locationName,
      address: COCHRAN_RESIDENCE.address,
      latitude: COCHRAN_RESIDENCE.latitude,
      longitude: COCHRAN_RESIDENCE.longitude,
      venueName: admin.firestore.FieldValue.delete(),
    });
    console.log(`REVERTED ${id}: "${before}" → "${COCHRAN_RESIDENCE.locationName}"`);
  }

  console.log('Done.');
  process.exit(0);
}

revertCochranMislabels().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
