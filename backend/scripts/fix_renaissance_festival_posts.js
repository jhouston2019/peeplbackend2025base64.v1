const admin = require('firebase-admin');
const https = require('https');

const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const GEORGIA_RENAISSANCE_FESTIVAL = {
  locationName: 'Georgia Renaissance Festival',
  venueName: 'Georgia Renaissance Festival',
  latitude: 33.5649819,
  longitude: -84.6028081,
};

function isCochranGainesvilleMislabel(locationName) {
  if (!locationName) return false;
  return /cochran/i.test(locationName) && /gainesville/i.test(locationName);
}

function mentionsRenaissance(data) {
  const fields = [data.description, data.locationName, data.venueName, data.vibe];
  return fields.some((value) => /renaissance/i.test(String(value || '')));
}

async function fixRenaissanceFestivalPosts() {
  console.log('Scanning location_posts for mislabeled Renaissance Festival peeps...');
  const snapshot = await db.collection('location_posts').get();
  console.log(`Found ${snapshot.docs.length} posts.`);

  let updated = 0;
  let skipped = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const locationName = data.locationName || '';

    const shouldFix =
      isCochranGainesvilleMislabel(locationName) ||
      (mentionsRenaissance(data) && /cochran|3633/i.test(locationName));

    if (!shouldFix) {
      skipped++;
      continue;
    }

    await doc.ref.update({
      locationName: GEORGIA_RENAISSANCE_FESTIVAL.locationName,
      venueName: GEORGIA_RENAISSANCE_FESTIVAL.venueName,
      latitude: GEORGIA_RENAISSANCE_FESTIVAL.latitude,
      longitude: GEORGIA_RENAISSANCE_FESTIVAL.longitude,
      address: admin.firestore.FieldValue.delete(),
    });

    console.log(`UPDATED ${doc.id}: "${locationName}" → "${GEORGIA_RENAISSANCE_FESTIVAL.locationName}"`);
    updated++;
  }

  console.log(`\nDone. Updated: ${updated}, Skipped: ${skipped}`);
  process.exit(0);
}

fixRenaissanceFestivalPosts().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
