import messaging from '@react-native-firebase/messaging';
import { Platform, Alert, PermissionsAndroid } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { authService } from './AuthService';

class PushNotificationService {
  private static instance: PushNotificationService;
  private fcmToken: string | null = null;
  private isInitialized: boolean = false;

  public static getInstance(): PushNotificationService {
    if (!PushNotificationService.instance) {
      PushNotificationService.instance = new PushNotificationService();
    }
    return PushNotificationService.instance;
  }

  async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      // Request permission
      const hasPermission = await this.requestPermission();
      if (!hasPermission) {
        console.log('Push notification permission denied');
        return;
      }

      // Get FCM token
      this.fcmToken = await messaging().getToken();
      console.log('FCM Token:', this.fcmToken);

      // Register token with backend
      await this.registerTokenWithBackend();

      // Set up message handlers
      this.setupMessageHandlers();

      this.isInitialized = true;
      console.log('Push notification service initialized');
    } catch (error) {
      console.error('Push notification initialization error:', error);
    }
  }

  private async requestPermission(): Promise<boolean> {
    if (Platform.OS === 'android') {
      const granted = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS,
        {
          title: 'Notification Permission',
          message: 'Peepl needs permission to send you notifications about nearby venues and social updates.',
          buttonNeutral: 'Ask Me Later',
          buttonNegative: 'Cancel',
          buttonPositive: 'OK',
        }
      );
      return granted === PermissionsAndroid.RESULTS.GRANTED;
    }

    // iOS permission request
    const authStatus = await messaging().requestPermission();
    const enabled =
      authStatus === messaging.AuthorizationStatus.AUTHORIZED ||
      authStatus === messaging.AuthorizationStatus.PROVISIONAL;

    return enabled;
  }

  private async registerTokenWithBackend(): Promise<void> {
    if (!this.fcmToken) {
      return;
    }

    try {
      const token = await AsyncStorage.getItem('authToken');
      if (!token) {
        return;
      }

      const response = await fetch(`${this.getApiBaseUrl()}/notifications/register-token`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          deviceToken: this.fcmToken,
          platform: Platform.OS,
        }),
      });

      if (response.ok) {
        console.log('FCM token registered with backend');
      } else {
        console.error('Failed to register FCM token with backend');
      }
    } catch (error) {
      console.error('Error registering FCM token:', error);
    }
  }

  private setupMessageHandlers(): void {
    // Handle background messages
    messaging().setBackgroundMessageHandler(async remoteMessage => {
      console.log('Message handled in the background!', remoteMessage);
    });

    // Handle foreground messages
    messaging().onMessage(async remoteMessage => {
      console.log('A new FCM message arrived!', remoteMessage);
      
      // Show local notification for foreground messages
      if (remoteMessage.notification) {
        Alert.alert(
          remoteMessage.notification.title || 'Peepl',
          remoteMessage.notification.body || '',
          [
            {
              text: 'Cancel',
              style: 'cancel',
            },
            {
              text: 'View',
              onPress: () => this.handleNotificationPress(remoteMessage.data),
            },
          ]
        );
      }
    });

    // Handle notification press
    messaging().onNotificationOpenedApp(remoteMessage => {
      console.log('Notification caused app to open from background state:', remoteMessage);
      this.handleNotificationPress(remoteMessage.data);
    });

    // Handle notification press when app is closed
    messaging()
      .getInitialNotification()
      .then(remoteMessage => {
        if (remoteMessage) {
          console.log('Notification caused app to open from quit state:', remoteMessage);
          this.handleNotificationPress(remoteMessage.data);
        }
      });
  }

  private handleNotificationPress(data: any): void {
    if (!data) {
      return;
    }

    switch (data.type) {
      case 'location_based':
        // Navigate to create peep screen
        console.log('Navigate to create peep for venue:', data.venueId);
        break;
      case 'social':
        // Navigate to peep details
        console.log('Navigate to peep:', data.peepId);
        break;
      case 'reminder':
        // Navigate to create peep screen
        console.log('Navigate to create peep reminder for venue:', data.venueId);
        break;
      default:
        console.log('Unknown notification type:', data.type);
    }
  }

  async unregisterToken(): Promise<void> {
    if (!this.fcmToken) {
      return;
    }

    try {
      const token = await AsyncStorage.getItem('authToken');
      if (!token) {
        return;
      }

      const response = await fetch(`${this.getApiBaseUrl()}/notifications/unregister-token`, {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          deviceToken: this.fcmToken,
        }),
      });

      if (response.ok) {
        console.log('FCM token unregistered from backend');
      } else {
        console.error('Failed to unregister FCM token from backend');
      }
    } catch (error) {
      console.error('Error unregistering FCM token:', error);
    }
  }

  async updateLocation(latitude: number, longitude: number): Promise<void> {
    try {
      const token = await AsyncStorage.getItem('authToken');
      if (!token) {
        return;
      }

      const response = await fetch(`${this.getApiBaseUrl()}/location/update`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          latitude,
          longitude,
        }),
      });

      if (response.ok) {
        console.log('Location updated for geofencing');
      } else {
        console.error('Failed to update location for geofencing');
      }
    } catch (error) {
      console.error('Error updating location:', error);
    }
  }

  private getApiBaseUrl(): string {
    return __DEV__ 
      ? 'http://localhost:3000' 
      : 'https://your-production-api.com';
  }

  getToken(): string | null {
    return this.fcmToken;
  }

  isReady(): boolean {
    return this.isInitialized && !!this.fcmToken;
  }
}

export const pushNotificationService = PushNotificationService.getInstance();
