// NOTE on navigatorKey:
// main.dart's _MyAppState declares a single GlobalKey<NavigatorState> that is
// shared between PeeplApp (MaterialApp.navigatorKey) and PushNotificationService
// via .init(navKey: navigatorKey). It is an instance variable, not a static,
// so it cannot be imported directly. We follow the same pattern used by
// PushNotificationService: accept the key at initialize() time and store it
// as an instance field. The caller (main.dart) passes its existing key so
// only ONE key is ever created across the whole app.

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService _instance =
      LocalNotificationService._();
  static LocalNotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Stored from initialize() — same key as MaterialApp and PushNotificationService.
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize({required GlobalKey<NavigatorState> navigatorKey}) async {
    _navigatorKey = navigatorKey;
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'peepl_geofence',
              'Crowd Check-ins',
              description:
                  'Asks you to report crowd levels when you arrive at a location',
              importance: Importance.high,
              playSound: true,
            ),
          );
    } catch (e) {
      debugPrint('[LocalNotificationService] initialize error: $e');
    }
  }

  Future<void> showArrivalNotification(String locationName) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'peepl_geofence',
        'Crowd Check-ins',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF1565C0),
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.show(
        locationName.hashCode.abs() % 1000,
        'You just arrived at $locationName',
        'How crowded is it? Tap to report.',
        details,
        payload: 'arrival:$locationName',
      );
    } catch (e) {
      debugPrint('[LocalNotificationService] showArrivalNotification error: $e');
    }
  }

  // NOTE on Step 3 (prompt was cut off):
  // The '/post' route in routes.dart is `(_) => const PostScreen()` and
  // PostScreen does not yet read ModalRoute arguments. Step 3 was almost
  // certainly going to wire PostScreen to read arguments['locationName']
  // and pre-fill the location controller. The pushNamed call below is
  // correct and ready — PostScreen just needs to be updated to consume
  // the argument.
  void _onNotificationTap(NotificationResponse response) {
    try {
      final payload = response.payload;
      if (payload == null) return;
      if (!payload.startsWith('arrival:')) return;

      final locationName = payload.substring(8);
      _navigatorKey?.currentState?.pushNamed(
        '/post',
        arguments: {'locationName': locationName},
      );
    } catch (e) {
      debugPrint('[LocalNotificationService] _onNotificationTap error: $e');
    }
  }
}
