const admin = require('firebase-admin');
const https = require('https');

const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const PLACES_API_KEY = 'AIzaSyAROeS73A4uhjNjZx_mMbqUnW99MCrv31o';

const MAX_VENUE_DISTANCE_METERS = 35;
const MAX_MAJOR_EVENT_DISTANCE_METERS = 250;
const MIN_MAJOR_POI_RATINGS = 75;
const STORED_NAME_CONFIRM_METERS = 60;
const EVENT_NAME = /\b(festival|fair|renfest|renaissance)\b/i;

const RANK_BY_DISTANCE_TYPES = [
  'restaurant',
  'bar',
  'night_club',
  'cafe',
  'bakery',
  'meal_takeaway',
  'tourist_attraction',
  'museum',
  'stadium',
  'amusement_park',
  'park',
  'point_of_interest',
  'establishment',
];

const FOOD_DRINK_TYPES = new Set([
  'restaurant',
  'bar',
  'night_club',
  'cafe',
  'bakery',
  'meal_takeaway',
  'food',
  'tourist_attraction',
  'museum',
  'stadium',
  'amusement_park',
  'park',
]);

const EXCLUDED_TYPES = new Set([
  'locality',
  'political',
  'route',
  'premise',
  'subpremise',
  'street_address',
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
  'store',
  'clothing_store',
  'shoe_store',
  'home_goods_store',
  'transit_station',
  'beauty_salon',
  'hair_care',
]);

const DEPRIORITIZED_NAME =
  /\b(properties|property management|financial advisor|insurance|personnel|capital management|edward jones|realty|real estate|law firm|attorney|accounting|consulting group|models of atlanta|click models|resource brokers|media group|law llc)\b/i;

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
    trimmed === 'Unknown Venue' ||
    trimmed === 'Unknown Location' ||
    trimmed === 'Home' ||
    trimmed === 'Park' ||
    trimmed === 'the house'
  ) {
    return true;
  }
  if (looksLikeAddress(trimmed)) return true;
  if (DEPRIORITIZED_NAME.test(trimmed)) return true;
  return false;
}

function normalizeName(value) {
  return String(value).toLowerCase().replace(/[^a-z0-9]/g, '');
}

function namesMatch(a, b) {
  if (!a || !b) return false;
  if (a === b) return true;
  return a.includes(b) || b.includes(a);
}

function storedVenueName(data) {
  for (const key of ['venueName', 'businessName', 'locationName']) {
    const raw = data[key];
    if (!raw || isWeakVenueName(raw)) continue;
    return String(raw).split(',')[0].trim();
  }
  return null;
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
  if (types.some((t) => FOOD_DRINK_TYPES.has(t))) return true;
  const ratings = result.user_ratings_total || 0;
  return (
    ratings >= MIN_MAJOR_POI_RATINGS &&
    (types.includes('point_of_interest') || types.includes('establishment'))
  );
}

function maxDistanceForResult(result) {
  const types = result.types || [];
  const name = result.name || '';
  const ratings = result.user_ratings_total || 0;
  if (
    EVENT_NAME.test(name) ||
    (ratings >= MIN_MAJOR_POI_RATINGS &&
      (types.includes('point_of_interest') ||
        types.includes('establishment') ||
        types.includes('tourist_attraction')))
  ) {
    return MAX_MAJOR_EVENT_DISTANCE_METERS;
  }
  return MAX_VENUE_DISTANCE_METERS;
}

function scoreCandidate(result, distanceMeters) {
  let score = distanceMeters;
  const types = result.types || [];
  if (types.includes('restaurant')) score -= 4;
  if (types.includes('bar')) score -= 3;
  if (types.includes('night_club')) score -= 2;
  if (types.includes('cafe')) score -= 2;
  if (types.includes('bakery')) score -= 1;
  if (types.includes('tourist_attraction')) score -= 1;
  if (types.includes('park')) score -= 1;
  if (EVENT_NAME.test(result.name || '')) score -= 6;
  if (types.length === 1 && types[0] === 'point_of_interest') score += 8;
  const ratings = result.user_ratings_total || 0;
  if (
    ratings >= MIN_MAJOR_POI_RATINGS &&
    (types.includes('point_of_interest') || types.includes('establishment'))
  ) {
    score -= 8;
  }
  score -= Math.log(ratings + 1) * 1.5;
  return score;
}

async function storedNameMatchesLocation(storedName, lat, lng) {
  const url =
    `https://maps.googleapis.com/maps/api/place/findplacefromtext/json` +
    `?input=${encodeURIComponent(storedName)}` +
    `&inputtype=textquery` +
    `&fields=name,geometry` +
    `&locationbias=circle:${STORED_NAME_CONFIRM_METERS}@${lat},${lng}` +
    `&key=${PLACES_API_KEY}`;
  const response = await placesGet(url);
  if (response.status !== 'OK') return false;

  const normalizedStored = normalizeName(storedName);
  for (const candidate of response.candidates || []) {
    if (!candidate.name) continue;
    if (!namesMatch(normalizedStored, normalizeName(candidate.name))) continue;
    const distance = resultDistanceMeters(candidate, lat, lng);
    if (distance != null && distance <= STORED_NAME_CONFIRM_METERS) {
      return true;
    }
  }
  return false;
}

async function fetchVenueName(lat, lng, storedHint) {
  if (
    storedHint &&
    !EVENT_NAME.test(storedHint) &&
    (await storedNameMatchesLocation(storedHint, lat, lng))
  ) {
    return storedHint;
  }

  const seenPlaceIds = new Set();
  const candidates = [];

  for (const type of RANK_BY_DISTANCE_TYPES) {
    const url =
      `https://maps.googleapis.com/maps/api/place/nearbysearch/json` +
      `?location=${lat},${lng}&rankby=distance&type=${type}&key=${PLACES_API_KEY}`;
    const response = await placesGet(url);
    const results = response.results || [];

    for (const result of results.slice(0, 5)) {
      if (result.place_id) {
        if (seenPlaceIds.has(result.place_id)) continue;
        seenPlaceIds.add(result.place_id);
      }
      if (!isEligibleVenue(result)) continue;
      const distance = resultDistanceMeters(result, lat, lng);
      if (distance == null || distance > maxDistanceForResult(result)) continue;
      candidates.push({
        name: result.name,
        score: scoreCandidate(result, distance),
        distance,
        ratings: result.user_ratings_total || 0,
        types: result.types || [],
      });
    }
  }

  if (candidates.length === 0) return null;

  candidates.sort((a, b) => a.score - b.score);
  const bestDistance = Math.min(...candidates.map((c) => c.distance));
  const nearby = candidates.filter((c) => c.distance - bestDistance <= 12);
  nearby.sort((a, b) => {
    const foodA = a.types.some((t) => FOOD_DRINK_TYPES.has(t)) ? 1 : 0;
    const foodB = b.types.some((t) => FOOD_DRINK_TYPES.has(t)) ? 1 : 0;
    if (foodA !== foodB) return foodB - foodA;
    if (b.ratings !== a.ratings) return b.ratings - a.ratings;
    return a.score - b.score;
  });
  return nearby[0].name;
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
      const storedHint = storedVenueName(data);
      const venueName = await fetchVenueName(latitude, longitude, storedHint);
      if (!venueName) {
        skipped++;
        continue;
      }

      if (venueName !== locationName) {
        const update = {
          locationName: venueName,
          venueName,
        };
        if (
          looksLikeAddress(locationName) ||
          DEPRIORITIZED_NAME.test(locationName || '')
        ) {
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

    await sleep(300);
  }

  console.log(`\nDone. Updated: ${updated}, Skipped: ${skipped}, Failed: ${failed}`);
  process.exit(0);
}

fixVenueNames().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
