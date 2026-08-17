const admin = require('firebase-admin');
const logger = require('../utils/logger');
const notificationService = require('./NotificationService');
const { calculateDistance, extractCoords, isValidCoord } = require('../utils/geo');

const USERS_COLLECTION = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

class GeofencingService {
  constructor() {
    this.activeGeofences = new Map(); // userId -> Set of venueIds
    this.userLocations = new Map(); // userId -> { latitude, longitude, timestamp }
    this.geofenceRadius = 100; // 100 meters radius for venue geofence
    this.checkInterval = 30000; // Check every 30 seconds
    this.isRunning = false;
  }

  // Start the geofencing service
  start() {
    if (this.isRunning) {
      logger.warn('Geofencing service is already running');
      return;
    }

    this.isRunning = true;
    logger.info('Starting geofencing service');

    // Check for location updates every 30 seconds
    this.intervalId = setInterval(() => {
      this.checkGeofences();
    }, this.checkInterval);

    // Also check immediately
    this.checkGeofences();
  }

  // Stop the geofencing service
  stop() {
    if (!this.isRunning) {
      return;
    }

    this.isRunning = false;
    if (this.intervalId) {
      clearInterval(this.intervalId);
    }
    logger.info('Geofencing service stopped');
  }

  // Update user location
  async updateUserLocation(userId, latitude, longitude) {
    try {
      const location = {
        latitude,
        longitude,
        timestamp: Date.now(),
      };

      this.userLocations.set(userId, location);

      // Store in database for persistence
      await admin.firestore().collection('user_locations').doc(userId).set({
        ...location,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Mirror into users doc so Cloud Functions can target this user for Get-a-Peep.
      if (isValidCoord(latitude, longitude)) {
        await admin.firestore().collection(USERS_COLLECTION).doc(userId).set(
          {
            lastLocation: {
              latitude,
              longitude,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            lastKnownLatitude: latitude,
            lastKnownLongitude: longitude,
          },
          { merge: true },
        );
      }

      // Check geofences immediately for this user
      await this.checkUserGeofences(userId, location);

      logger.debug(`Updated location for user ${userId}: ${latitude}, ${longitude}`);
    } catch (error) {
      logger.error('Error updating user location:', error);
    }
  }

  // Check all active geofences
  async checkGeofences() {
    try {
      const activeUsers = Array.from(this.userLocations.keys());
      
      for (const userId of activeUsers) {
        const location = this.userLocations.get(userId);
        if (location && this.isLocationRecent(location)) {
          await this.checkUserGeofences(userId, location);
        }
      }
    } catch (error) {
      logger.error('Error checking geofences:', error);
    }
  }

  // Check geofences for a specific user
  async checkUserGeofences(userId, userLocation) {
    try {
      // Get nearby venues
      const nearbyVenues = await this.getNearbyVenues(
        userLocation.latitude,
        userLocation.longitude,
        1000 // 1km radius to check for venues
      );

      const currentGeofences = this.activeGeofences.get(userId) || new Set();
      const newGeofences = new Set();

      for (const venue of nearbyVenues) {
        const venueCoords = extractCoords(venue);
        if (!venueCoords) continue;

        const distance = calculateDistance(
          userLocation.latitude,
          userLocation.longitude,
          venueCoords.latitude,
          venueCoords.longitude
        ) * 1000;

        // If user is within geofence radius
        if (distance <= this.geofenceRadius) {
          newGeofences.add(venue.id);

          // If user just entered this geofence
          if (!currentGeofences.has(venue.id)) {
            await this.handleGeofenceEntry(userId, venue, userLocation);
          }
        }
      }

      // Check for geofence exits
      for (const venueId of currentGeofences) {
        if (!newGeofences.has(venueId)) {
          await this.handleGeofenceExit(userId, venueId);
        }
      }

      // Update active geofences
      this.activeGeofences.set(userId, newGeofences);

    } catch (error) {
      logger.error(`Error checking geofences for user ${userId}:`, error);
    }
  }

  // Handle user entering a geofence
  async handleGeofenceEntry(userId, venue, userLocation) {
    try {
      logger.info(`User ${userId} entered geofence for venue ${venue.name}`);

      // Check if user has posted at this venue recently
      const recentPeep = await this.getRecentPeep(userId, venue.id);
      
      if (!recentPeep) {
        // Send location-based notification
        await notificationService.sendLocationBasedNotification(
          userId,
          venue,
          userLocation
        );

        // Set a reminder notification for 10 minutes later
        setTimeout(async () => {
          const currentLocation = this.userLocations.get(userId);
          if (currentLocation && this.isUserStillAtVenue(userId, venue.id)) {
            await notificationService.sendReminderNotification(userId, venue);
          }
        }, 10 * 60 * 1000); // 10 minutes
      }

      // Log geofence entry
      await admin.firestore().collection('geofence_events').add({
        userId,
        venueId: venue.id,
        venueName: venue.name,
        eventType: 'entry',
        latitude: userLocation.latitude,
        longitude: userLocation.longitude,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

    } catch (error) {
      logger.error('Error handling geofence entry:', error);
    }
  }

  // Handle user exiting a geofence
  async handleGeofenceExit(userId, venueId) {
    try {
      logger.info(`User ${userId} exited geofence for venue ${venueId}`);

      // Log geofence exit
      await admin.firestore().collection('geofence_events').add({
        userId,
        venueId,
        eventType: 'exit',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

    } catch (error) {
      logger.error('Error handling geofence exit:', error);
    }
  }

  // Get nearby venues within radius
  async getNearbyVenues(latitude, longitude, radius) {
    try {
      const venuesSnapshot = await admin.firestore()
        .collection('venues')
        .where('isActive', '==', true)
        .get();

      const nearbyVenues = [];
      venuesSnapshot.forEach(doc => {
        const venue = doc.data();
        const coords = extractCoords(venue);
        if (!coords) return;

        const distance = calculateDistance(
          latitude,
          longitude,
          coords.latitude,
          coords.longitude
        ) * 1000;

        if (distance <= radius) {
          nearbyVenues.push({
            id: doc.id,
            ...venue,
            latitude: coords.latitude,
            longitude: coords.longitude,
            lat: coords.latitude,
            lng: coords.longitude,
            distance
          });
        }
      });

      return nearbyVenues;
    } catch (error) {
      logger.error('Error getting nearby venues:', error);
      return [];
    }
  }

  // Check if user has posted at venue recently (within last 2 hours)
  async getRecentPeep(userId, venueId) {
    try {
      const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000);
      
      const peepsSnapshot = await admin.firestore()
        .collection('peeps')
        .where('userId', '==', userId)
        .where('venueId', '==', venueId)
        .where('createdAt', '>=', twoHoursAgo)
        .where('isActive', '==', true)
        .limit(1)
        .get();

      return !peepsSnapshot.empty;
    } catch (error) {
      logger.error('Error checking recent peep:', error);
      return false;
    }
  }

  // Check if user is still at venue
  isUserStillAtVenue(userId, venueId) {
    const currentGeofences = this.activeGeofences.get(userId) || new Set();
    return currentGeofences.has(venueId);
  }

  // Check if location is recent (within last 5 minutes)
  isLocationRecent(location) {
    const fiveMinutesAgo = Date.now() - 5 * 60 * 1000;
    return location.timestamp > fiveMinutesAgo;
  }

  // Get geofencing status for user
  getGeofencingStatus(userId) {
    const activeGeofences = this.activeGeofences.get(userId) || new Set();
    const userLocation = this.userLocations.get(userId);

    return {
      isActive: this.isRunning,
      userLocation,
      activeGeofences: Array.from(activeGeofences),
      lastUpdate: userLocation ? userLocation.timestamp : null,
    };
  }
}

module.exports = new GeofencingService();
