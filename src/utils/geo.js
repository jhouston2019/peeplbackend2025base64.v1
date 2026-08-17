/**
 * Read coordinates from a Firestore doc that may use lat/lng or latitude/longitude.
 * @param {object|null|undefined} data
 * @returns {{ latitude: number, longitude: number }|null}
 */
function extractCoords(data) {
  if (!data || typeof data !== 'object') return null;

  const rawLat = data.latitude ?? data.lat;
  const rawLng = data.longitude ?? data.lng;
  if (rawLat == null || rawLng == null) return null;

  const latitude = typeof rawLat === 'number' ? rawLat : parseFloat(rawLat);
  const longitude = typeof rawLng === 'number' ? rawLng : parseFloat(rawLng);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;

  return { latitude, longitude };
}

/**
 * @param {number|null|undefined} lat
 * @param {number|null|undefined} lng
 * @returns {boolean}
 */
function isValidCoord(lat, lng) {
  if (lat == null || lng == null) return false;
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return false;
  if (lat === 0 && lng === 0) return false;
  if (Math.abs(lat) > 90 || Math.abs(lng) > 180) return false;
  return true;
}

/**
 * Calculate distance between two lat/lng coordinates using the Haversine formula.
 * @param {number} lat1
 * @param {number} lng1
 * @param {number} lat2
 * @param {number} lng2
 * @returns {number} Distance in kilometers
 */
function calculateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371; // Earth's radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

module.exports = { calculateDistance, extractCoords, isValidCoord };
