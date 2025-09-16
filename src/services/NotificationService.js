const admin = require('firebase-admin');
const logger = require('../utils/logger');

class NotificationService {
  constructor() {
    this.fcmServerKey = process.env.FCM_SERVER_KEY;
  }

  // Send push notification to a single device
  async sendToDevice(deviceToken, notification) {
    try {
      const message = {
        token: deviceToken,
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: notification.data || {},
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().send(message);
      logger.info(`Push notification sent successfully: ${response}`);
      return { success: true, messageId: response };
    } catch (error) {
      logger.error('Error sending push notification:', error);
      return { success: false, error: error.message };
    }
  }

  // Send push notification to multiple devices
  async sendToMultipleDevices(deviceTokens, notification) {
    try {
      const message = {
        tokens: deviceTokens,
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: notification.data || {},
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().sendMulticast(message);
      logger.info(`Push notifications sent: ${response.successCount}/${response.failureCount}`);
      return { 
        success: true, 
        successCount: response.successCount,
        failureCount: response.failureCount,
        responses: response.responses
      };
    } catch (error) {
      logger.error('Error sending multicast push notification:', error);
      return { success: false, error: error.message };
    }
  }

  // Send location-based notification when user enters venue area
  async sendLocationBasedNotification(userId, venue, userLocation) {
    try {
      // Get user's device tokens
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return { success: false, error: 'User not found' };
      }

      const userData = userDoc.data();
      const deviceTokens = userData.deviceTokens || [];

      if (deviceTokens.length === 0) {
        return { success: false, error: 'No device tokens found' };
      }

      const distance = this.calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        venue.latitude,
        venue.longitude
      );

      const notification = {
        title: `You're near ${venue.name}!`,
        body: `Share your experience at ${venue.name}. Tap to create a peep!`,
        data: {
          type: 'location_based',
          venueId: venue.id,
          venueName: venue.name,
          distance: distance.toString(),
          action: 'create_peep',
        },
      };

      return await this.sendToMultipleDevices(deviceTokens, notification);
    } catch (error) {
      logger.error('Error sending location-based notification:', error);
      return { success: false, error: error.message };
    }
  }

  // Send notification when user hasn't posted in a while
  async sendReminderNotification(userId, venue) {
    try {
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return { success: false, error: 'User not found' };
      }

      const userData = userDoc.data();
      const deviceTokens = userData.deviceTokens || [];

      if (deviceTokens.length === 0) {
        return { success: false, error: 'No device tokens found' };
      }

      const notification = {
        title: `Still at ${venue.name}?`,
        body: `Don't forget to share your experience! Your friends would love to hear about it.`,
        data: {
          type: 'reminder',
          venueId: venue.id,
          venueName: venue.name,
          action: 'create_peep',
        },
      };

      return await this.sendToMultipleDevices(deviceTokens, notification);
    } catch (error) {
      logger.error('Error sending reminder notification:', error);
      return { success: false, error: error.message };
    }
  }

  // Send notification when someone likes/comments on user's peep
  async sendSocialNotification(userId, type, data) {
    try {
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return { success: false, error: 'User not found' };
      }

      const userData = userDoc.data();
      const deviceTokens = userData.deviceTokens || [];

      if (deviceTokens.length === 0) {
        return { success: false, error: 'No device tokens found' };
      }

      let notification;
      switch (type) {
        case 'like':
          notification = {
            title: `${data.userName} liked your peep`,
            body: `Your peep at ${data.venueName} got a new like!`,
            data: {
              type: 'social',
              action: 'view_peep',
              peepId: data.peepId,
              venueId: data.venueId,
            },
          };
          break;
        case 'comment':
          notification = {
            title: `${data.userName} commented on your peep`,
            body: `"${data.commentText}"`,
            data: {
              type: 'social',
              action: 'view_peep',
              peepId: data.peepId,
              venueId: data.venueId,
            },
          };
          break;
        default:
          return { success: false, error: 'Unknown notification type' };
      }

      return await this.sendToMultipleDevices(deviceTokens, notification);
    } catch (error) {
      logger.error('Error sending social notification:', error);
      return { success: false, error: error.message };
    }
  }

  // Calculate distance between two points
  calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371e3; // Earth's radius in meters
    const φ1 = (lat1 * Math.PI) / 180;
    const φ2 = (lat2 * Math.PI) / 180;
    const Δφ = ((lat2 - lat1) * Math.PI) / 180;
    const Δλ = ((lon2 - lon1) * Math.PI) / 180;

    const a =
      Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
      Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c; // Distance in meters
  }

  // Register device token for user
  async registerDeviceToken(userId, deviceToken, platform) {
    try {
      const userRef = admin.firestore().collection('users').doc(userId);
      const userDoc = await userRef.get();

      if (!userDoc.exists) {
        return { success: false, error: 'User not found' };
      }

      const userData = userDoc.data();
      const deviceTokens = userData.deviceTokens || [];

      // Add new token if not already present
      const tokenData = {
        token: deviceToken,
        platform: platform,
        registeredAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true,
      };

      if (!deviceTokens.find(t => t.token === deviceToken)) {
        deviceTokens.push(tokenData);
      }

      await userRef.update({
        deviceTokens: deviceTokens,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info(`Device token registered for user ${userId}`);
      return { success: true };
    } catch (error) {
      logger.error('Error registering device token:', error);
      return { success: false, error: error.message };
    }
  }

  // Unregister device token
  async unregisterDeviceToken(userId, deviceToken) {
    try {
      const userRef = admin.firestore().collection('users').doc(userId);
      const userDoc = await userRef.get();

      if (!userDoc.exists) {
        return { success: false, error: 'User not found' };
      }

      const userData = userDoc.data();
      const deviceTokens = userData.deviceTokens || [];

      // Remove token
      const updatedTokens = deviceTokens.filter(t => t.token !== deviceToken);

      await userRef.update({
        deviceTokens: updatedTokens,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info(`Device token unregistered for user ${userId}`);
      return { success: true };
    } catch (error) {
      logger.error('Error unregistering device token:', error);
      return { success: false, error: error.message };
    }
  }
}

module.exports = new NotificationService();
