const admin = require('firebase-admin');
const https = require('https');

const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const PLACES_API_KEY = 'AIzaSyAROeS73A4uhjNjZx_mMbqUnW99MCrv31o';

const MAX_VENUE_DISTANCE_METERS = 200;
const RANK_BY_DISTANCE_TYPES = [
  'restaurant',
  'bar',
  'night_club',
  'cafe',
  'bakery',
  'meal_takeaway',
  'tourist_attraction',
  'store',
];

const EXCLUDED_TYPES = new Set([
  'locality',
  'political',
  'route',
  'real_estate_agency',
  'finance',
  'insurance_agency',
  'accounting',
  'lawyer',
  'courthouse',
  'local_government_office',
  'general_contractor',
  'moving_company',
  'electrician',
  'plumber',
  'storage',
  'car_dealer',
  'car_repair',
  'gas_station',
]);

const DEPRIORITIZED_NAME =
  /\b(properties|property management|financial advisor|insurance|personnel|capital management|edward jones|realty|real estate|law firm|attorney|accounting|consulting group)\b/i;

function looksLikeAddress(name) {
  if (!name) return true;
  return /^\d+\s|^US-\d+|^[A-Z]{2}-\d+|\bRd\b|\bSt\b|\bAve\b|\bBlvd\b|\bPkwy\b|\bDr\b|\bLn\b|\bHwy\b|\bRoad\b/i.test(
    name,
  );
}

function isWeakVenueName(name) {
  if (!name) return true;
  const trimmed = String(name).trim();
  if (!trimmed) return true;
  if (
    trimmed === 'Current location' ||
    trimmed === 'this location' ||
    trimmed === 'Unknown Venue'
  ) {
    return true;
  }
  if (looksLikeAddress(trimmed)) return true;
  if (DEPRIORITIZED_NAME.test(trimmed)) return true;
  return false;
}

function placesGet(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(e);
          }
        });
      })
      .on('error', reject);
  });
}

function haversineMeters(lat1, lng1, lat2, lng2) {
  const earthRadius = 6371000;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return earthRadius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function resultDistanceMeters(result, lat, lng) {
  const loc = result.geometry && result.geometry.location;
  if (!loc) return null;
  return haversineMeters(lat, lng, loc.lat, loc.lng);
}

function isEligibleVenue(result) {
  const name = result.name;
  if (isWeakVenueName(name)) return false;
  const types = result.types || [];
  if (types.some((t) => EXCLUDED_TYPES.has(t))) return false;
  return types.some(
    (t) =>
      RANK_BY_DISTANCE_TYPES.includes(t) ||
      t === 'food' ||
      t === 'point_of_interest',
  );
}

async function fetchVenueName(lat, lng) {
  let closestName = null;
  let closestDistance = null;

  for (const type of RANK_BY_DISTANCE_TYPES) {
    const url =
      `https://maps.googleapis.com/maps/api/place/nearbysearch/json` +
      `?location=${lat},${lng}&rankby=distance&type=${type}&key=${PLACES_API_KEY}`;
    const response = await placesGet(url);
    const results = response.results || [];

    for (const result of results.slice(0, 8)) {
      if (!isEligibleVenue(result)) continue;
      const distance = resultDistanceMeters(result, lat, lng);
      if (distance == null || distance > MAX_VENUE_DISTANCE_METERS) continue;
      if (closestDistance == null || distance < closestDistance) {
        closestDistance = distance;
        closestName = result.name;
      }
    }
  }

  return closestName;
}

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
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

    if (!latitude || !longitude || (latitude === 0 && longitude === 0)) {
      skipped++;
      continue;
    }

    try {
      const venueName = await fetchVenueName(latitude, longitude);
      if (venueName && venueName !== locationName) {
        const update = {
          locationName: venueName,
          venueName,
        };
        if (looksLikeAddress(locationName) || DEPRIORITIZED_NAME.test(locationName || '')) {
          update.address = locationName;
        }
        await doc.ref.update(update);
        console.log(`UPDATED: "${locationName}" → "${venueName}"`);
        updated++;
      } else {
        skipped++;
      }
    } catch (e) {
      console.error(`FAILED: ${doc.id} — ${e.message}`);
      failed++;
    }

    await sleep(250);
  }

  console.log(`\nDone. Updated: ${updated}, Skipped: ${skipped}, Failed: ${failed}`);
  process.exit(0);
}

fixVenueNames().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
