const admin = require('firebase-admin');
const https = require('https');

const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const PLACES_API_KEY = 'AIzaSyAROeS73A4uhjNjZx_mMbqUnW99MCrv31o';

const NEARBY_RADII = [100, 200, 300];
const MAX_VENUE_DISTANCE_METERS = 200;
const PREFERRED_TYPES = new Set([
  'tourist_attraction',
  'amusement_park',
  'museum',
  'stadium',
  'park',
  'point_of_interest',
  'establishment',
]);

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
  return looksLikeAddress(trimmed);
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

function scoreResult(result, lat, lng) {
  const types = result.types || [];
  let score = 0;
  for (const type of types) {
    if (PREFERRED_TYPES.has(type)) score += 12;
    if (type === 'locality' || type === 'political' || type === 'route') {
      score -= 40;
    }
  }
  if ((result.name || '').includes(' ')) score += 6;
  const distance = resultDistanceMeters(result, lat, lng);
  if (distance != null) score -= Math.round(distance / 10);
  return score;
}

function bestNameFromResults(results, lat, lng) {
  if (!results || results.length === 0) return null;

  let bestName = null;
  let bestScore = -9999;
  for (const result of results) {
    const name = result.name;
    if (isWeakVenueName(name)) continue;
    const distance = resultDistanceMeters(result, lat, lng);
    if (distance != null && distance > MAX_VENUE_DISTANCE_METERS) continue;
    const score = scoreResult(result, lat, lng);
    if (score > bestScore) {
      bestScore = score;
      bestName = name;
    }
  }
  return bestName;
}

async function fetchVenueName(lat, lng) {
  for (const radius of NEARBY_RADII) {
    const nearbyUrl =
      `https://maps.googleapis.com/maps/api/place/nearbysearch/json` +
      `?location=${lat},${lng}&radius=${radius}&type=establishment&key=${PLACES_API_KEY}`;
    const nearby = await placesGet(nearbyUrl);
    const nearbyName = bestNameFromResults(nearby.results, lat, lng);
    if (nearbyName) return nearbyName;
  }

  const textUrl =
    `https://maps.googleapis.com/maps/api/place/textsearch/json` +
    `?query=${encodeURIComponent('point of interest')}` +
    `&location=${lat},${lng}&radius=${MAX_VENUE_DISTANCE_METERS}&key=${PLACES_API_KEY}`;
  const text = await placesGet(textUrl);
  return bestNameFromResults(text.results, lat, lng);
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

    if (!looksLikeAddress(locationName)) {
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
        const update = {
          locationName: venueName,
          venueName,
        };
        if (looksLikeAddress(locationName)) {
          update.address = locationName;
        }
        await db.collection('location_posts').doc(doc.id).update(update);
        console.log(`UPDATED: "${locationName}" → "${venueName}"`);
        updated++;
      } else {
        skipped++;
      }
    } catch (e) {
      console.error(`FAILED: ${doc.id} — ${e.message}`);
      failed++;
    }

    await sleep(200);
  }

  console.log(`\nDone. Updated: ${updated}, Skipped: ${skipped}, Failed: ${failed}`);
  process.exit(0);
}

fixVenueNames().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
