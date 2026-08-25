import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../models/milestone.dart';
import '../services/feed_service.dart';
import '../utils/composer_launch.dart';
import '../widgets/peepl_positive_message.dart';
import 'crowdsource_service.dart';
import 'debug_log_service.dart';
import 'growth_analytics_service.dart';
import 'peep_prompt_suppression_service.dart';
import 'peepl_positive_messages.dart';
import 'presence_service.dart';
import 'dwell_detector.dart';
import 'location_service.dart';

/// Context for Flow 1 organic walk-in prompts. No venue name — generic copy only.
class WalkInPromptContext {
  const WalkInPromptContext({
    required this.lat,
    required this.lng,
    required this.venueId,
    this.placeId,
  });

  final double lat;
  final double lng;

  /// Suppression cell id or registry location id — not necessarily a Place ID.
  final String venueId;
  final String? placeId;
}

const _walkInPromptTitle = 'How\'s the crowd there?';
const _walkInPromptBody = 'Tap to share how crowded it is where you are.';

/// Firestore composite indexes required before production deploy.
///
/// `onPeepCreatedCrowdAlert` (Cloud Function) — `location_follows` queries:
///   - collection: location_follows — fields: locationId ASC, alertsEnabled ASC
///   - collection: location_follows — fields: locationName ASC, alertsEnabled ASC
///
/// `onVenueEntryEvent` (Cloud Function) — `venue_entry_events` cooldown queries:
///   - collection: venue_entry_events — fields: userId ASC, venueId ASC,
///     notificationSent ASC, timestamp ASC
///   - collection: venue_entry_events — fields: userId ASC, notificationSent ASC,
///     timestamp ASC

/// Firestore collection used for user profile documents (includes fcmToken).
const kUsersCollection = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

const kVenueEntryEventsCollection = 'venue_entry_events';

const _kHasRequestedPushPermissionKey = 'hasRequestedPushPermission';
const _kPushPermissionShownKey = 'push_permission_shown';
const _kPushNotificationsEnabledKey = 'pushNotificationsEnabled';
const _kLocationAlertsEnabledKey = 'locationAlertsEnabled';

Future<void> _writeVenueEntryEventToFirestore({
  required String userId,
  required String venueName,
  required String venueId,
  required double latitude,
  required double longitude,
  String? address,
}) async {
  if (userId.isEmpty || venueName.isEmpty || venueId.isEmpty) return;
  if (latitude.isNaN ||
      longitude.isNaN ||
      (latitude == 0 && longitude == 0)) {
    return;
  }

  try {
    await FirebaseFirestore.instance.collection(kVenueEntryEventsCollection).add({
      'userId': userId,
      'venueName': venueName,
      'venueId': venueId,
      'latitude': latitude,
      'longitude': longitude,
      if (address != null && address.isNotEmpty) 'address': address,
      'timestamp': FieldValue.serverTimestamp(),
      'notificationSent': false,
    });
  } catch (e) {
    debugPrint('[FCM] venue_entry_events write error: $e');
  }
}

Future<void> _showWalkInLocalNotificationFromData(
  Map<String, dynamic> data, {
  String? title,
  String? body,
}) async {
  try {
  final venueId =
      (data['venueId'] ?? data['locationId'])?.toString() ?? 'walk_in';
  final lat = double.tryParse(data['latitude']?.toString() ?? '');
  final lng = double.tryParse(data['longitude']?.toString() ?? '');

  final notificationTitle = title ?? _walkInPromptTitle;
  final notificationBody = body ??
      await PeeplPositiveMessages.instance.enrichPushBody(
        _walkInPromptBody,
        notificationType: 'walk_in_prompt',
      );

  const walkInChannel = AndroidNotificationChannel(
    'peepl_walk_in',
    'Walk-in Prompts',
    description: 'Prompts when you arrive at a venue.',
    importance: Importance.high,
  );

  final localNotifications = FlutterLocalNotificationsPlugin();
  final androidPlugin = localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(walkInChannel);

  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@drawable/ic_notification'),
    iOS: DarwinInitializationSettings(),
  );
  await localNotifications.initialize(initSettings);

  final payload = jsonEncode({
    'type': 'walk_in_prompt',
    if (lat != null) 'latitude': lat,
    if (lng != null) 'longitude': lng,
    'venueId': venueId,
    if (data['placeId'] != null) 'placeId': data['placeId'].toString(),
  });

  await localNotifications.show(
    venueId.hashCode,
    notificationTitle,
    notificationBody,
    NotificationDetails(
      android: AndroidNotificationDetails(
        walkInChannel.id,
        walkInChannel.name,
        channelDescription: walkInChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: payload,
  );
  } catch (e) {
    debugPrint('[FCM] _showWalkInLocalNotificationFromData error: $e');
  }
}

// Must be top-level — FCM requirement for background handling.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    final type = message.data['type']?.toString();

    if (type == 'geofence_entry') {
      final data = message.data;
      final lat = double.tryParse(data['latitude']?.toString() ?? '');
      final lng = double.tryParse(data['longitude']?.toString() ?? '');
      if (lat == null || lng == null) return;

      await _writeVenueEntryEventToFirestore(
        userId: data['userId']?.toString() ?? '',
        venueName: data['venueName']?.toString() ?? '',
        venueId: data['venueId']?.toString() ?? '',
        latitude: lat,
        longitude: lng,
      );
      return;
    }

    if (type == 'walk_in_prompt') {
      await _showWalkInLocalNotificationFromData(
        message.data,
        title: message.notification?.title,
        body: message.notification?.body,
      );
      return;
    }

    debugPrint(
      '[FCM Background] ${message.messageId}: ${message.notification?.title}',
    );
  } catch (e) {
    debugPrint('[FCM Background] handler error: $e');
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Set by [FeedScreen] when user returns after 5+ days (Phase 9).
  static bool sessionComebackActive = false;

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
  bool _coldStartWalkInCaptured = false;

  /// Optional in-app walk-in prompt (e.g. FeedScreen dialog).
  void Function(WalkInPromptContext ctx)? onVenueEntryInAppPrompt;

  /// Records a walk-in push that launched the app from a killed state.
  /// Call from [main] before [runApp] so the tap survives auth routing.
  void captureColdStartWalkIn(RemoteMessage message) {
    _pendingNotificationData = Map<String, dynamic>.from(message.data);
    _pendingLaunchMessage = message;
    _coldStartWalkInCaptured = true;
  }

  /// Single entry point for all venue-entry walk-in prompts — dwell detector,
  /// registry geofence, and in-app dialog all route here. Generic copy only.
  Future<void> handleVenueEntry({
    required String venueId,
    required double lat,
    required double lng,
    String? placeId,
  }) async {
    if (!await isLocationAlertsEnabled()) {
      debugPrint('[NotificationService] Venue entry skipped (location alerts off)');
      return;
    }

    if (lat.isNaN || lng.isNaN || (lat == 0 && lng == 0)) {
      await GrowthAnalyticsService.logEvent(
        'growth_peep_prompt_suppressed',
        {
          'venueId': venueId,
          'reason': 'missing_coordinates',
        },
      );
      debugPrint(
        '[NotificationService] Venue entry skipped for $venueId (no coordinates)',
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (!await PeepPromptSuppressionService.instance.shouldShowPrompt(venueId)) {
      final suppression =
          await PeepPromptSuppressionService.instance.check(venueId);
      await GrowthAnalyticsService.logEvent(
        'growth_peep_prompt_suppressed',
        {
          'venueId': venueId,
          'reason': suppression.reason ?? 'unknown',
        },
      );
      debugPrint(
        '[NotificationService] Venue entry suppressed for $venueId '
        '(${suppression.reason})',
      );
      return;
    }

    await _updateUserLastLocation(lat, lng);

    final promptContext = WalkInPromptContext(
      lat: lat,
      lng: lng,
      venueId: venueId,
      placeId: placeId,
    );

    await GrowthAnalyticsService.logEvent(
      'growth_venue_entry_detected',
      {
        'venueId': venueId,
        if (placeId != null) 'placeId': placeId,
      },
    );

    try {
      await PresenceService.instance.recordArrival('walk-in', lat, lng);
    } catch (e) {
      debugPrint('[NotificationService] recordArrival error: $e');
    }

    final inApp = onVenueEntryInAppPrompt;
    if (inApp != null && _isAppForeground) {
      inApp(promptContext);
      await PeepPromptSuppressionService.instance.recordPromptShown(venueId);
      await GrowthAnalyticsService.logEvent(
        'growth_peep_prompt_delivered',
        {
          'venueId': venueId,
          'channel': 'in_app',
        },
      );
      return;
    }

    if (_isAppForeground) {
      await _deliverWalkInLocalNotification(
        venueId: venueId,
        lat: lat,
        lng: lng,
        placeId: placeId,
      );
      await PeepPromptSuppressionService.instance.recordPromptShown(venueId);
      await GrowthAnalyticsService.logEvent(
        'growth_peep_prompt_delivered',
        {
          'venueId': venueId,
          'channel': 'local',
        },
      );
      return;
    }

    // Background — local notification on device. No Firestore / FCM required.
    await _deliverWalkInLocalNotification(
      venueId: venueId,
      lat: lat,
      lng: lng,
      placeId: placeId,
    );
    await PeepPromptSuppressionService.instance.recordPromptShown(venueId);
    if (uid != null) {
      unawaited(_writeVenueEntryEventToFirestore(
        userId: uid,
        venueName: 'walk-in',
        venueId: venueId,
        latitude: lat,
        longitude: lng,
      ));
    }
    await GrowthAnalyticsService.logEvent(
      'growth_peep_prompt_delivered',
      {
        'venueId': venueId,
        'channel': 'local',
      },
    );
  }

  bool get _isAppForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  Future<void> _deliverWalkInLocalNotification({
    required String venueId,
    required double lat,
    required double lng,
    String? placeId,
  }) async {
    final payload = jsonEncode({
      'type': 'walk_in_prompt',
      'latitude': lat,
      'longitude': lng,
      'venueId': venueId,
      if (placeId != null && placeId.isNotEmpty) 'placeId': placeId,
    });

    final walkInBody =
        await PeeplPositiveMessages.instance.enrichPushBody(
      _walkInPromptBody,
      notificationType: 'walk_in_prompt',
    );

    try {
      await _localNotifications.show(
        venueId.hashCode,
        _walkInPromptTitle,
        walkInBody,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _walkInChannel.id,
            _walkInChannel.name,
            channelDescription: _walkInChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[FCM] _deliverWalkInLocalNotification show error: $e');
    }
  }

  /// Core FCM and local-notification setup. Call from main() after
  /// Firebase.initializeApp().
  Future<void> initialize() async {
    DwellDetector.instance.onArrival =
        ({required lat, required lng, required cellId}) {
      unawaited(
        handleVenueEntry(venueId: cellId, lat: lat, lng: lng),
      );
    };

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_channel);
      await androidPlugin?.createNotificationChannel(_walkInChannel);

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
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

      _fcm.onTokenRefresh.listen(
        _saveTokenToFirestore,
        onError: (Object e) {
          debugPrint('[FCM] onTokenRefresh listener error: $e');
        },
      );
    } catch (e) {
      debugPrint('[FCM] initialize error: $e');
    }
  }

  /// Attach the app navigator and wire FCM foreground/tap listeners.
  Future<void> attachNavigator(GlobalKey<NavigatorState> navKey) async {
    navigatorKey = navKey;

    if (_listenersAttached) return;
    _listenersAttached = true;

    FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
      onError: (Object e) {
        debugPrint('[FCM] onMessage listener error: $e');
      },
    );
    FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
      onError: (Object e) {
        debugPrint('[FCM] onMessageOpenedApp listener error: $e');
      },
    );

    if (!_coldStartWalkInCaptured) {
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _pendingNotificationData =
            Map<String, dynamic>.from(initialMessage.data);
        _pendingLaunchMessage = initialMessage;
      }
    }

    _startCrowdsourceResponseListener();
    unawaited(syncLocationForCrowdsourceTargeting());
  }

  /// Flow 3 — record trigger doc after a post. Server [onNewPost] fulfills
  /// crowdsource requests and sends FCM (single path, no client duplicate).
  Future<void> onPostSubmitted({
    required String postId,
    required String userId,
    required String username,
    required String locationName,
    required double latitude,
    required double longitude,
    required int crowdingLevel,
    String? crowdsourceRequestId,
  }) async {
    if (postId.isEmpty) {
      debugPrint('[FCM] onPostSubmitted: empty postId');
      return;
    }

    try {
      await _updateUserLastLocation(latitude, longitude);

      final trimmedName = locationName.trim();
      if (trimmedName.isNotEmpty &&
          CrowdsourceService.isValidCoordinate(latitude, longitude)) {
        try {
          await PresenceService.instance.recordArrival(
            trimmedName,
            latitude,
            longitude,
          );
        } catch (e) {
          debugPrint('[FCM] recordArrival on post error: $e');
        }
      }

      await _db.collection('notification_triggers').doc(postId).set({
        'latitude': latitude,
        'longitude': longitude,
        'locationName': locationName,
        'posterId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        if (crowdsourceRequestId != null && crowdsourceRequestId.isNotEmpty)
          'crowdsourceRequestId': crowdsourceRequestId,
      });

      await CrowdsourceService.instance.fulfillMatchingRequests(
        postId: postId,
        responderId: userId,
        username: username,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        crowdingLevel: crowdingLevel,
        crowdsourceRequestId: crowdsourceRequestId,
      );
    } catch (e) {
      debugPrint('[FCM] onPostSubmitted error: $e');
      await DebugLogService.log(
        'FCM',
        'onPostSubmitted_failed',
        data: {'error': e.toString(), 'postId': postId},
      );
    }
  }

  Future<void> handlePostSubmission({
    required String userId,
    required String locationName,
  }) async {
    try {
      await _showPeepSubmissionSuccessBottomSheet(
        userId: userId,
        locationName: locationName,
      );
      await checkAndShowMilestones(userId);
    } catch (_) {}
  }

  Future<void> _showPeepSubmissionSuccessBottomSheet({
    required String userId,
    required String locationName,
  }) async {
    DocumentSnapshot<Map<String, dynamic>>? userSnap;
    try {
      userSnap =
          await _db.collection(kUsersCollection).doc(userId).get();
    } catch (e) {
      debugPrint(
        '[FCM] _showPeepSubmissionSuccessBottomSheet user get error: $e',
      );
      return;
    }
    final totalImpact =
        (userSnap.data()?['totalImpact'] as num?)?.toInt() ?? 0;

    final nav = navigatorKey?.currentState;
    if (nav == null || !nav.mounted) return;
    final context = nav.context;
    if (!context.mounted) return;

    final headline = sessionComebackActive
        ? 'Welcome back — your Peep just updated $locationName.'
        : 'Your Peep is live.';
    final impactLine = !sessionComebackActive && totalImpact > 0
        ? "You've now helped $totalImpact people with your contributions."
        : null;

    sessionComebackActive = false;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => GestureDetector(
        onTap: () => Navigator.pop(sheetContext),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 40, color: Color(0xFF1565C0)),
              const SizedBox(height: 16),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              if (impactLine != null) ...[
                const SizedBox(height: 12),
                Text(
                  impactLine,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
              const PeeplPositiveMessage(
                contextKey: 'peep_submission_success',
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to dismiss',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> checkAndShowMilestones(String userId) async {
    try {
      final newIds = await FeedService().checkMilestones(userId);
      if (newIds.isEmpty) return;

      final nav = navigatorKey?.currentState;
      if (nav == null || !nav.mounted) return;
      final context = nav.context;

      for (final id in newIds) {
        final text = Milestone.textFor(id);
        if (text == null) continue;
        if (!context.mounted) return;

        await showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (sheetContext) => GestureDetector(
            onTap: () => Navigator.pop(sheetContext),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.emoji_events_outlined,
                      size: 40, color: Color(0xFF1565C0)),
                  const SizedBox(height: 16),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  PeeplPositiveMessage(
                    contextKey: 'milestone_$id',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to dismiss',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (_) {}
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
          'lastKnownLatitude': latitude,
          'lastKnownLongitude': longitude,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[FCM] lastLocation update error: $e');
    }
  }

  /// Keeps Firestore location/presence in sync so Get-a-Peep can find this user.
  Future<void> syncLocationForCrowdsourceTargeting() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    Position? pos;
    try {
      pos = await LocationService.getCurrentLocation(forceRefresh: true);
    } catch (e) {
      debugPrint('[NotificationService] getCurrentLocation error: $e');
    }
    try {
      if (pos != null) {
        await _updateUserLastLocation(pos.latitude, pos.longitude);
      }
    } catch (e) {
      debugPrint('[NotificationService] _updateUserLastLocation error: $e');
    }

    if (pos == null) return;

    try {
      final displayName =
          await LocationLabelService.resolve(pos.latitude, pos.longitude);
      if (displayName.isNotEmpty && displayName != 'Current location') {
        await PresenceService.instance.recordArrival(
          displayName,
          pos.latitude,
          pos.longitude,
        );
      }
    } catch (e) {
      debugPrint('[FCM] syncLocationForCrowdsourceTargeting error: $e');
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

        // FCM from onCrowdsourceResponseCreated delivers the push; show local
        // notification as a foreground backup when the app is open.
        final data = change.doc.data();
        if (data == null) continue;

        final username = data['responderUsername'] as String? ?? 'Someone';
        final locationName = data['locationName'] as String? ?? 'a location';
        final crowdingLevel = (data['crowdingLevel'] as num?)?.toInt() ?? 0;
        final levelLabel = crowdingLevel <= 4
            ? 'not crowded'
            : crowdingLevel <= 6
                ? 'moderately crowded'
                : 'very crowded';

        if (_isAppForeground) {
          final responseBody =
              await PeeplPositiveMessages.instance.enrichPushBody(
            '$username just posted about $locationName — it\'s $levelLabel. Tap to see.',
            notificationType: 'crowdsource_response',
          );
          try {
            await _localNotifications.show(
              docId.hashCode,
              'Your Peep request was answered!',
              responseBody,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  _channel.id,
                  _channel.name,
                  channelDescription: _channel.description,
                  importance: Importance.high,
                  priority: Priority.high,
                  icon: '@drawable/ic_notification',
                ),
                iOS: const DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
              payload: jsonEncode({
                'type': 'crowdsource_response',
                'postId': data['postId'],
                'requestId': docId,
              }),
            );
          } catch (e) {
            debugPrint('[FCM] crowdsource listener show error: $e');
          }
        } else {
          debugPrint(
            '[FCM] crowdsource_response doc $docId (background FCM expected)',
          );
        }
      }
    }, onError: (Object e) {
      debugPrint('[FCM] crowdsource response listener error: $e');
    });
  }

  Future<void> markPermissionPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasRequestedPushPermissionKey, true);
    await prefs.setBool(_kPushPermissionShownKey, true);
  }

  Future<bool> isPushEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPushNotificationsEnabledKey) ?? true;
  }

  Future<bool> isLocationAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kLocationAlertsEnabledKey) ?? true;
  }

  /// Applies push preference: saves token when enabled, removes when disabled.
  Future<void> applyPushPreference(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPushNotificationsEnabledKey, enabled);

    if (enabled) {
      try {
        await _fcm.requestPermission(alert: true, badge: true, sound: true);
      } catch (e) {
        debugPrint('[FCM] requestPermission error: $e');
      }
      await _refreshAndSaveToken();
      _startCrowdsourceResponseListener();
    } else {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await _db.collection(kUsersCollection).doc(uid).update({
            'fcmToken': FieldValue.delete(),
          });
        } catch (e) {
          debugPrint('[FCM] Token delete on disable error: $e');
        }
      }
      try {
        await _fcm.deleteToken();
      } catch (e) {
        debugPrint('[FCM] deleteToken on disable error: $e');
      }
    }
  }

  Future<String> routeAfterLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final hasRequested = prefs.getBool(_kHasRequestedPushPermissionKey) ??
        prefs.getBool(_kPushPermissionShownKey) ??
        false;
    return hasRequested ? '/home' : '/permissions/push';
  }

  Future<void> requestPermissions() async {
    try {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (e) {
      debugPrint('[FCM] requestPermission error: $e');
    }

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
    if (!await isPushEnabled()) return;
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
    if (!await isPushEnabled()) return;

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
    unawaited(syncLocationForCrowdsourceTargeting());
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

    if (!await isPushEnabled()) return;

    final notification = message.notification;
    final title = notification?.title ??
        message.data['title'] as String? ??
        'Peepl';
    final body = notification?.body ?? message.data['body'] as String? ?? '';
    final android = notification?.android;

    try {
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
            icon: android?.smallIcon ?? '@drawable/ic_notification',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      debugPrint('[FCM] _handleForegroundMessage show error: $e');
    }
  }

  Future<void> _persistNotification(RemoteMessage message) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return; // Auth not available in background isolate

    // TODO: add Firestore index on notifications.items.messageId if query is slow
    if (message.messageId != null) {
      try {
        final existing = await _db
            .collection('notifications')
            .doc(uid)
            .collection('items')
            .where('messageId', isEqualTo: message.messageId)
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) return;
      } catch (e) {
        debugPrint('[FCM] _persistNotification dedup error: $e');
      }
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
        'relatedId': data['postId'] ?? data['requestId'] ?? data['relatedId'] ?? '',
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
        if (data['requestId'] != null) 'requestId': data['requestId'].toString(),
        if (data['placeId'] != null) 'placeId': data['placeId'].toString(),
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
          arguments: ComposerLaunch.crowdsourceRouteArgs(
            locationName: locationName,
            latitude: lat,
            longitude: lng,
            placeId: data['placeId']?.toString(),
            requestId: data['requestId']?.toString(),
          ),
        );
        break;
      case 'walk_in_prompt':
        final venueId = (data['venueId'] ?? data['locationId'])?.toString();
        final placeId = data['placeId']?.toString();
        final lat = double.tryParse(data['latitude']?.toString() ?? '');
        final lng = double.tryParse(data['longitude']?.toString() ?? '');
        unawaited(
          GrowthAnalyticsService.logEvent(
            'growth_peep_prompt_tapped',
            {
              if (venueId != null) 'venueId': venueId,
            },
          ),
        );
        nav.pushNamed(
          '/post',
          arguments: {
            'fromVenueEntry': true,
            'composerSource': 'walk_in',
            if (lat != null) 'latitude': lat,
            if (lng != null) 'longitude': lng,
            if (venueId != null && venueId.isNotEmpty) 'venueId': venueId,
            if (placeId != null && placeId.isNotEmpty) 'placeId': placeId,
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
      case 'crowd_change_alert':
        final postId =
            (data['peepId'] ?? data['postId'])?.toString().trim();
        final locationId = data['locationId']?.toString();
        final userId = FirebaseAuth.instance.currentUser?.uid;
        unawaited(
          GrowthAnalyticsService.logEvent(
            'growth_crowd_alert_tapped',
            {
              if (userId != null) 'userId': userId,
              if (locationId != null && locationId.isNotEmpty)
                'locationId': locationId,
              'timestamp': DateTime.now().toIso8601String(),
            },
          ),
        );
        if (postId != null && postId.isNotEmpty) {
          await _navigateToLocationDetail(postId);
        } else {
          nav.pushNamed('/feed');
        }
        break;
      case 'reengagement':
        nav.pushNamed('/feed');
        break;
      default:
        nav.pushNamed('/feed');
    }
  }

  Future<void> _navigateToLocationDetail(String postId) async {
    final nav = navigatorKey?.currentState;
    if (nav == null) return;

    try {
      final snap = await _db.collection('location_posts').doc(postId).get();
      if (!snap.exists) {
        nav.pushNamed('/feed');
        return;
      }
      final postData = <String, dynamic>{'id': snap.id, ...?snap.data()};
      nav.pushNamed('/location_detail', arguments: postData);
    } catch (e) {
      debugPrint('[FCM] Location detail fetch error: $e');
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
      nav.pushNamed('/location_detail', arguments: postData);
    } catch (e) {
      debugPrint('[FCM] Post fetch error: $e');
      nav.pushNamed('/feed');
    }
  }
}
