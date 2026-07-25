import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'crowdsource_service.dart';
import 'debug_log_service.dart';

/// Firestore collection used for user profile documents (includes fcmToken).
const kUsersCollection = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

const _kHasRequestedPushPermissionKey = 'hasRequestedPushPermission';
const _kPushPermissionShownKey = 'push_permission_shown';
const _kWalkInPromptCooldown = Duration(hours: 2);

// Must be top-level — FCM requirement for background handling.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    '[FCM Background] ${message.messageId}: ${message.notification?.title}',
  );
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'peepl_high_importance',
    'Peepl Notifications',
    description: 'Crowd alerts, likes, and proximity updates from Peepl.',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel _walkInChannel =
      AndroidNotificationChannel(
    'peepl_walk_in',
    'Walk-in Prompts',
    description: 'Prompts when you arrive at a venue.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? navigatorKey;
  Map<String, dynamic>? _pendingNotificationData;
  RemoteMessage? _pendingLaunchMessage;
  bool _listenersAttached = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _crowdsourceResponseSub;
  final Set<String> _seenCrowdsourceResponseIds = {};
  bool _crowdsourceListenerPrimed = false;

  /// Core FCM and local-notification setup. Call from main() after
  /// Firebase.initializeApp().
  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.createNotificationChannel(_walkInChannel);

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

    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
  }

  /// Attach the app navigator and wire FCM foreground/tap listeners.
  Future<void> attachNavigator(GlobalKey<NavigatorState> navKey) async {
    navigatorKey = navKey;

    if (_listenersAttached) return;
    _listenersAttached = true;

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _pendingNotificationData = Map<String, dynamic>.from(initialMessage.data);
      _pendingLaunchMessage = initialMessage;
    }

    _startCrowdsourceResponseListener();
  }

  /// Flow 1 — geofence walk-in prompt (max once per location per 2 hours).
  Future<void> handleGeofenceWalkIn({
    required String locationId,
    required String locationName,
    required double latitude,
    required double longitude,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'last_prompted_$locationId';
    final lastMs = prefs.getInt(key);
    if (lastMs != null) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastMs;
      if (elapsed < _kWalkInPromptCooldown.inMilliseconds) {
        debugPrint('[FCM] Walk-in prompt skipped for $locationId (cooldown)');
        return;
      }
    }

    await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
    await _updateUserLastLocation(latitude, longitude);

    final payload = jsonEncode({
      'type': 'walk_in_prompt',
      'locationId': locationId,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
    });

    await _localNotifications.show(
      locationId.hashCode,
      "You're at $locationName!",
      "How's the crowd right now? Tap to share.",
      NotificationDetails(
        android: AndroidNotificationDetails(
          _walkInChannel.id,
          _walkInChannel.name,
          channelDescription: _walkInChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  /// Flow 3 — record trigger doc and fulfill crowdsource requests after a post.
  Future<void> onPostSubmitted({
    required String userId,
    required String username,
    required String locationName,
    required double latitude,
    required double longitude,
    required int crowdingLevel,
  }) async {
    final postId = await _findRecentPostId(userId, locationName);
    if (postId == null) {
      debugPrint('[FCM] Could not resolve postId for notification trigger');
      return;
    }

    try {
      await _updateUserLastLocation(latitude, longitude);

      await _db.collection('notification_triggers').doc(postId).set({
        'latitude': latitude,
        'longitude': longitude,
        'locationName': locationName,
        'posterId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await CrowdsourceService.instance.fulfillMatchingRequests(
        postId: postId,
        responderId: userId,
        username: username,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        crowdingLevel: crowdingLevel,
      );
    } catch (e) {
      debugPrint('[FCM] onPostSubmitted error: $e');
    }
  }

  Future<String?> _findRecentPostId(String userId, String locationName) async {
    try {
      final snap = await _db
          .collection('location_posts')
          .where('userId', isEqualTo: userId)
          .limit(25)
          .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? best;
      Timestamp? bestTs;

      for (final doc in snap.docs) {
        if (doc.data()['locationName'] != locationName) continue;
        final ts = doc.data()['timestamp'];
        if (ts is! Timestamp) continue;
        if (bestTs == null || ts.compareTo(bestTs) > 0) {
          best = doc;
          bestTs = ts;
        }
      }

      return best?.id;
    } catch (e) {
      debugPrint('[FCM] _findRecentPostId error: $e');
      return null;
    }
  }

  Future<void> _updateUserLastLocation(double latitude, double longitude) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection(kUsersCollection).doc(uid).set(
        {
          'lastLocation': {
            'latitude': latitude,
            'longitude': longitude,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[FCM] lastLocation update error: $e');
    }
  }

  void _startCrowdsourceResponseListener() {
    _crowdsourceResponseSub?.cancel();
    _seenCrowdsourceResponseIds.clear();
    _crowdsourceListenerPrimed = false;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _crowdsourceResponseSub = _db
        .collection('crowdsource_responses')
        .where('requesterId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) async {
      if (!_crowdsourceListenerPrimed) {
        for (final doc in snapshot.docs) {
          _seenCrowdsourceResponseIds.add(doc.id);
        }
        _crowdsourceListenerPrimed = true;
        return;
      }

      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final docId = change.doc.id;
        if (_seenCrowdsourceResponseIds.contains(docId)) continue;
        _seenCrowdsourceResponseIds.add(docId);

        final data = change.doc.data();
        if (data == null) continue;

        final username = data['responderUsername'] as String? ?? 'Someone';
        final locationName = data['locationName'] as String? ?? 'a location';
        final crowdingLevel = (data['crowdingLevel'] as num?)?.toInt() ?? 0;
        final levelLabel = _crowdingLabel(crowdingLevel);

        await _showCrowdsourceResponseNotification(
          requestId: docId,
          body:
              '$username just posted about $locationName — it\'s $levelLabel! Tap to see.',
          data: data,
        );
      }
    });
  }

  String _crowdingLabel(int level) {
    if (level <= 4) return 'not crowded';
    if (level <= 6) return 'moderately crowded';
    return 'very crowded';
  }

  Future<void> _showCrowdsourceResponseNotification({
    required String requestId,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final payload = jsonEncode({
      'type': 'crowdsource_response',
      'postId': data['postId'],
      'requestId': requestId,
    });

    await _localNotifications.show(
      requestId.hashCode,
      'Crowd update',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> markPermissionPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasRequestedPushPermissionKey, true);
    await prefs.setBool(_kPushPermissionShownKey, true);
  }

  Future<String> routeAfterLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final hasRequested = prefs.getBool(_kHasRequestedPushPermissionKey) ??
        prefs.getBool(_kPushPermissionShownKey) ??
        false;
    return hasRequested ? '/home' : '/permissions/push';
  }

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
    await prefs.setBool(_kPushPermissionShownKey, true);

    await _refreshAndSaveToken();
    _startCrowdsourceResponseListener();
  }

  Future<void> processPendingNotification() async {
    final data = _pendingNotificationData;
    if (data == null) return;
    _pendingNotificationData = null;
    await _routeFromData(data);
    final launchMessage = _pendingLaunchMessage;
    _pendingLaunchMessage = null;
    if (launchMessage != null) {
      await _persistNotification(launchMessage);
    }
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

      await _db.collection(kUsersCollection).doc(uid).set(
        tokenData,
        SetOptions(merge: true),
      );

      debugPrint('[FCM] Token saved for $uid');
    } catch (e) {
      debugPrint('[FCM] Token save error: $e');
    }
  }

  Future<void> onUserSignedIn() async {
    await _refreshAndSaveToken();
    _startCrowdsourceResponseListener();
  }

  Future<void> onUserSignedOut() async {
    await _crowdsourceResponseSub?.cancel();
    _crowdsourceResponseSub = null;
    _seenCrowdsourceResponseIds.clear();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection(kUsersCollection).doc(uid).update({
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
    if (uid == null) return; // Auth not available in background isolate

    // TODO: add Firestore index on notifications.items.messageId if query is slow
    if (message.messageId != null) {
      final existing = await _db
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .where('messageId', isEqualTo: message.messageId)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return;
    }

    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    final data = message.data;

    try {
      await _db
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .add({
        'type': data['type'] ?? 'push',
        'title': title,
        'body': body,
        'isRead': false,
        'read': false,
        'messageId': message.messageId ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'relatedId': data['postId'] ?? data['relatedId'] ?? '',
        // Location context — present on crowdsource_request, null on others.
        // notifications_screen uses these for in-app tap navigation.
        if (data['locationName'] != null) 'locationName': data['locationName'],
        if (data['latitude'] != null)
          'latitude': data['latitude'] is String
              ? double.tryParse(data['latitude']!) ?? 0.0
              : (data['latitude'] as num).toDouble(),
        if (data['longitude'] != null)
          'longitude': data['longitude'] is String
              ? double.tryParse(data['longitude']!) ?? 0.0
              : (data['longitude'] as num).toDouble(),
        if (data['username'] != null) 'username': data['username'],
        'iconType': data['iconType'] ?? 'push',
      });
    } catch (e) {
      debugPrint('[FCM] Firestore write error: $e');
    }
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    await _routeFromData(Map<String, dynamic>.from(message.data));
    await _persistNotification(message);
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

  /// Maps every known FCM `type` variant to a single canonical value.
  /// The deployed onLikeCreated function may send either 'like' (older
  /// build) or 'post_liked' (current source), so both must resolve here.
  String _canonicalNotificationType(dynamic rawType) {
    final t = (rawType ?? '').toString().trim().toLowerCase();
    switch (t) {
      case 'like':
      case 'post_like':
      case 'post_liked':
        return 'post_liked';
      default:
        return t;
    }
  }

  Future<void> _routeFromData(Map<String, dynamic> data) async {
    final nav = navigatorKey?.currentState;
    if (nav == null) {
      _pendingNotificationData = data;
      return;
    }

    final type = _canonicalNotificationType(data['type']);
    final resolvedPostId = type == 'post_liked'
        ? (data['postId'] ?? data['post_id'] ?? data['id'])
            ?.toString()
            .trim()
        : data['postId']?.toString();
    DebugLogService.log('NOTIF', 'tap', data: {
      'rawType': data['type'],
      'canonicalType': type,
      'postId': resolvedPostId,
    });

    switch (type) {
      case 'new_post':
      case 'new_post_nearby':
        final postId = data['postId'] as String?;
        if (postId != null && postId.isNotEmpty) {
          await _navigateToPostDetail(postId);
        } else {
          nav.pushNamedAndRemoveUntil('/feed', (route) => false);
        }
        break;
      case 'post_liked':
        final postId = resolvedPostId;
        if (postId != null && postId.isNotEmpty) {
          await _navigateToPostDetail(postId);
        } else {
          DebugLogService.log('NOTIF', 'post_liked_missing_postId',
              data: {'payload': data.toString()});
          nav.pushNamed('/feed');
        }
        break;
      case 'crowdsource_request':
        final locationName = data['locationName'] as String? ?? '';
        final lat = double.tryParse(data['latitude']?.toString() ?? '');
        final lng = double.tryParse(data['longitude']?.toString() ?? '');
        nav.pushNamed(
          '/post',
          arguments: {
            'locationName': locationName,
            if (lat != null) 'latitude': lat,
            if (lng != null) 'longitude': lng,
          },
        );
        break;
      case 'walk_in_prompt':
        nav.pushNamed(
          '/post',
          arguments: {
            'locationName': data['locationName'] as String? ?? '',
            'latitude': (data['latitude'] as num?)?.toDouble(),
            'longitude': (data['longitude'] as num?)?.toDouble(),
          },
        );
        break;
      case 'crowdsource_response':
        final postId = data['postId'] as String?;
        if (postId != null && postId.isNotEmpty) {
          await _navigateToPostDetail(postId);
        } else {
          nav.pushNamed('/feed');
        }
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
