/// @deprecated Consolidated into [NotificationService]. Walk-in venue prompts,
/// geofence arrival taps, and the `peepl_walk_in` channel are owned by
/// [NotificationService.handleVenueEntry]. This file is retained temporarily
/// and must not be initialized from [main].
//
// Legacy — see NotificationService.handleVenueEntry.

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../theme/peepl_app_tokens.dart';

/// @deprecated Consolidated into [NotificationService.handleVenueEntry].
/// Do not initialize from [main].
@Deprecated('Use NotificationService.handleVenueEntry instead')
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService _instance =
      LocalNotificationService._();
  static LocalNotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Stored from initialize() — same key as MaterialApp and NotificationService.
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize({required GlobalKey<NavigatorState> navigatorKey}) async {
    _navigatorKey = navigatorKey;
    try {
      const androidSettings =
          AndroidInitializationSettings('@drawable/ic_notification');
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
        icon: '@drawable/ic_notification',
        color: PeeplAppTokens.accentBlue,
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
