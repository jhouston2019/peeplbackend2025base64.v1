import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Must be top-level — FCM requirement for background handling.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] ${message.messageId}: ${message.notification?.title}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'peepl_high_importance',
    'Peepl Notifications',
    description: 'Crowd alerts, likes, and proximity updates from Peepl.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? navigatorKey;

  Future<void> init({required GlobalKey<NavigatorState> navKey}) async {
    navigatorKey = navKey;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      await Future.delayed(const Duration(milliseconds: 500));
      _handleNotificationTap(initialMessage);
    }

    await _refreshAndSaveToken();
    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
  }

  Future<void> _refreshAndSaveToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) await _saveTokenToFirestore(token);
    } catch (e) {
      debugPrint('[FCM] Token fetch error: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection(uid).doc('profile').set(
        {
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'platform': 'mobile',
        },
        SetOptions(merge: true),
      );
      debugPrint('[FCM] Token saved for $uid');
    } catch (e) {
      debugPrint('[FCM] Token save error: $e');
    }
  }

  /// Call immediately after sign-in.
  Future<void> onUserSignedIn() async {
    await _refreshAndSaveToken();
  }

  /// Call before sign-out.
  Future<void> onUserSignedOut() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection(uid).doc('profile').update({
        'fcmToken': FieldValue.delete(),
      });
      await _fcm.deleteToken();
    } catch (e) {
      debugPrint('[FCM] Token removal error: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM Foreground] ${message.notification?.title}');
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Background/terminated tap → open the notifications screen so the user
    // can see all pending items in one place. The main.dart onMessageOpenedApp
    // listener also fires for this case; the duplicate push is a no-op because
    // the navigator deduplicates identical named routes.
    navigatorKey?.currentState?.pushNamed('/notifications');
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _routeFromData(data);
    } catch (e) {
      debugPrint('[FCM] Payload parse error: $e');
    }
  }

  void _routeFromData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final nav = navigatorKey?.currentState;
    if (nav == null) return;

    switch (type) {
      case 'new_post':
        nav.pushNamedAndRemoveUntil('/feed', (route) => false);
        break;
      case 'post_liked':
        nav.pushNamed('/feed');
        break;
      case 'crowdsource_request':
        final locationName = data['locationName'] as String? ?? '';
        nav.pushNamed(
          '/post',
          arguments: {'locationName': locationName},
        );
        break;
      default:
        nav.pushNamed('/feed');
    }
  }
}
