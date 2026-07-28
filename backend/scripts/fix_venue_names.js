const admin = require('firebase-admin');
const https = require('https');

const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const PLACES_API_KEY = 'AIzaSyBkJayDy4YBldg0Y5Ux7sR5Qww8am59vV8';
const USERS_COLLECTION = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

function looksLikeAddress(name) {
  if (!name) return true;
  // Matches patterns like "434 High St SW" or "US-19 N" or "2042 Johnson Ferry Rd"
  return /^\d+\s|^US-\d+|^[A-Z]{2}-\d+|\bRd\b|\bSt\b|\bAve\b|\bBlvd\b|\bPkwy\b|\bDr\b|\bLn\b|\bHwy\b/i.test(name);
}

function fetchVenueName(lat, lng) {
  return new Promise((resolve, reject) => {
    const url = `https://maps.googleapis.com/maps/api/place/nearbysearch/json` +
      `?location=${lat},${lng}&rankby=distance&type=establishment&key=${PLACES_API_KEY}`;
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          if (parsed.results && parsed.results.length > 0) {
            resolve(parsed.results[0].name);
          } else {
            resolve(null);
          }
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function fixVenueNames() {
  console.log('Fetching all location_posts...');
  const snapshot = await db.collection('location_posts').get();
  console.log(`Found ${snapshot.docs.length} posts.`);

  let updated = 0;
  let skipped = 0;
  let failed = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const { locationName, latitude, longitude } = data;

    if (!looksLikeAddress(locationName)) {
      console.log(`SKIP: "${locationName}" looks like a real name`);
      skipped++;
      continue;
    }

    if (!latitude || !longitude) {
      console.log(`SKIP: ${doc.id} has no coordinates`);
      skipped++;
      continue;
    }

    try {
      const venueName = await fetchVenueName(latitude, longitude);
      if (venueName && venueName !== locationName) {
        await db.collection('location_posts').doc(doc.id).update({
          locationName: venueName,
        });
        console.log(`UPDATED: "${locationName}" → "${venueName}"`);
        updated++;
      } else {
        console.log(`NO CHANGE: "${locationName}" — no better name found`);
        skipped++;
      }
    } catch (e) {
      console.error(`FAILED: ${doc.id} — ${e.message}`);
      failed++;
    }

    // Throttle to avoid hitting Places API rate limits
    await sleep(200);
  }

  console.log(`\nDone. Updated: ${updated}, Skipped: ${skipped}, Failed: ${failed}`);
  process.exit(0);
}

fixVenueNames().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
