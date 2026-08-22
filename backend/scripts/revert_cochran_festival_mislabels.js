const admin = require('firebase-admin');

const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Original residence location before the incorrect festival relabel.
const COCHRAN_RESIDENCE = {
  locationName: '3633 Cochran Rd, Gainesville, GA',
  latitude: 34.3690721,
  longitude: -83.8621006,
};

// Posts incorrectly rewritten by fix_renaissance_festival_posts.js
const MISLABELED_IDS = [
  '6APKBXhG3AqVDEeyyOX0',
  'VFU5bfBpE6wnBADTYuVn',
  'nLWEL6Ep6wtzbi9rOa9g',
];

async function revertMislabels() {
  console.log('Reverting incorrect Georgia Renaissance Festival labels...');

  for (const id of MISLABELED_IDS) {
    const ref = db.collection('location_posts').doc(id);
    const snap = await ref.get();
    if (!snap.exists) {
      console.log(`SKIP: ${id} not found`);
      continue;
    }

    await ref.update({
      locationName: COCHRAN_RESIDENCE.locationName,
      latitude: COCHRAN_RESIDENCE.latitude,
      longitude: COCHRAN_RESIDENCE.longitude,
      venueName: admin.firestore.FieldValue.delete(),
      address: COCHRAN_RESIDENCE.locationName,
    });
    console.log(`REVERTED ${id} → "${COCHRAN_RESIDENCE.locationName}"`);
  }

  // User-typed festival name at the residence GPS — not the Fairburn festival.
  const typedMislabel = db.collection('location_posts').doc('yWGgqtvGJtoUslwhju8r');
  const typedSnap = await typedMislabel.get();
  if (typedSnap.exists) {
    await typedMislabel.update({
      locationName: COCHRAN_RESIDENCE.locationName,
      latitude: COCHRAN_RESIDENCE.latitude,
      longitude: COCHRAN_RESIDENCE.longitude,
      venueName: admin.firestore.FieldValue.delete(),
      address: COCHRAN_RESIDENCE.locationName,
    });
    console.log(
      `REVERTED yWGgqtvGJtoUslwhju8r: "renaissance festival" → "${COCHRAN_RESIDENCE.locationName}"`,
    );
  }

  console.log('Done.');
  process.exit(0);
}

revertMislabels().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
