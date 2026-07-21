import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

const _kHasRequestedPushPermissionKey = 'hasRequestedPushPermission';

// Must be top-level — FCM requirement for background handling.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    '[FCM Background] ${message.messageId}: ${message.notification?.title}',
  );
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
  Map<String, dynamic>? _pendingNotificationData;

  Future<void> init({required GlobalKey<NavigatorState> navKey}) async {
    navigatorKey = navKey;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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
      alert: false,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _pendingNotificationData = Map<String, dynamic>.from(initialMessage.data);
    }

    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
  }

  /// Marks the permission prompt as shown without requesting OS permission.
  Future<void> markPermissionPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasRequestedPushPermissionKey, true);
  }
  Future<String> routeAfterLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final hasRequested =
        prefs.getBool(_kHasRequestedPushPermissionKey) ?? false;
    return hasRequested ? '/home' : '/permissions/push';
  }

  /// Requests notification permission with platform-specific prompts.
  /// Call after login on the dedicated permission screen.
  Future<void> requestPermissions() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasRequestedPushPermissionKey, true);

    await _refreshAndSaveToken();
  }

  /// Process a notification tap that arrived before navigation was ready.
  Future<void> processPendingNotification() async {
    final data = _pendingNotificationData;
    if (data == null) return;
    _pendingNotificationData = null;
    await _routeFromData(data);
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
      final tokenData = {
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'platform': 'mobile',
      };

      // Primary path requested: users/{uid} with fcmToken field.
      await _db.collection('users').doc(uid).set(
        tokenData,
        SetOptions(merge: true),
      );

      // Legacy path used by Cloud Functions / backend senders.
      await _db.collection(uid).doc('profile').set(
        tokenData,
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
      await _db.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
      });
      await _db.collection(uid).doc('profile').update({
        'fcmToken': FieldValue.delete(),
      });
      await _fcm.deleteToken();
    } catch (e) {
      debugPrint('[FCM] Token removal error: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM Foreground] ${message.notification?.title}');
    await _persistNotification(message);

    final notification = message.notification;
    final title = notification?.title ??
        message.data['title'] as String? ??
        'Peepl';
    final body = notification?.body ?? message.data['body'] as String? ?? '';
    final android = notification?.android;

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
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

  Future<void> _persistNotification(RemoteMessage message) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';

    try {
      await _db
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .add({
        'type': message.data['type'] ?? 'push',
        'title': title,
        'body': body,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'relatedId': message.data['postId'] ??
            message.data['relatedId'] ??
            '',
        'iconType': message.data['iconType'] ?? 'push',
      });
    } catch (e) {
      debugPrint('[FCM] Firestore write error: $e');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    _routeFromData(Map<String, dynamic>.from(message.data));
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

  Future<void> _routeFromData(Map<String, dynamic> data) async {
    final nav = navigatorKey?.currentState;
    if (nav == null) {
      _pendingNotificationData = data;
      return;
    }

    final type = data['type'] as String?;

    switch (type) {
      case 'new_post':
      case 'new_post_nearby':
        nav.pushNamedAndRemoveUntil('/feed', (route) => false);
        break;
      case 'post_liked':
        final postId = data['postId'] as String?;
        if (postId != null && postId.isNotEmpty) {
          await _navigateToPostDetail(postId);
        } else {
          nav.pushNamed('/feed');
        }
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

  Future<void> _navigateToPostDetail(String postId) async {
    final nav = navigatorKey?.currentState;
    if (nav == null) return;

    try {
      final snap = await _db.collection('location_posts').doc(postId).get();
      if (!snap.exists) {
        nav.pushNamed('/feed');
        return;
      }
      final postData = <String, dynamic>{'id': snap.id, ...?snap.data()};
      nav.pushNamed('/peep_detail', arguments: postData);
    } catch (e) {
      debugPrint('[FCM] Post fetch error: $e');
      nav.pushNamed('/feed');
    }
  }
}
