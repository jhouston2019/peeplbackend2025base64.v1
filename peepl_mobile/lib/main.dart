import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/constants.dart';
import 'firebase_options.dart';
import 'routes.dart';
import 'services/auth_service.dart';
import 'services/geofence_service.dart' as geofence_svc;
import 'services/local_notification_service.dart';
import 'services/presence_service.dart';
import 'services/push_notification_service.dart';
import 'theme_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Stripe must be configured before Firebase and before runApp.
  Stripe.publishableKey = kStripePublishableKey;
  await Stripe.instance.applySettings();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    PushNotificationService.instance.init(navKey: navigatorKey).then((_) async {
      // Cold-start: if the app was launched by tapping a notification, open
      // the notifications screen once the navigator is ready.
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.pushNamed('/notifications');
        });
      }
      final geofenceService = geofence_svc.PeeplGeofenceService.instance;
      await LocalNotificationService.instance
          .initialize(navigatorKey: navigatorKey);
      geofenceService.onLocationEntered = (name, lat, lng) async {
        debugPrint('GEOFENCE ENTERED: $name at $lat, $lng');
        await PresenceService.instance.recordArrival(name, lat, lng);
        await LocalNotificationService.instance.showArrivalNotification(name);
      };
      await geofenceService.initialize();
      await geofenceService.loadGeofencesFromFirestore();

      // ── FCM foreground: persist to Firestore + show snackbar ──────────────
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // ── FCM background tap: open notifications screen ─────────────────────
      FirebaseMessaging.onMessageOpenedApp.listen((_) {
        navigatorKey.currentState?.pushNamed('/notifications');
      });

      if (mounted) setState(() => _ready = true);
    });
  }

  /// Writes the incoming FCM message to `notifications/{uid}/items` and
  /// shows a snackbar with the notification title.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';

    // Persist to Firestore so the notifications screen can display it.
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .add({
        'type': message.data['type'] ?? 'push',
        'title': title,
        'body': body,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'relatedId': message.data['relatedId'] ?? '',
        'iconType': message.data['iconType'] ?? 'push',
      });
    } catch (e) {
      debugPrint('[FCM] Firestore write error: $e');
    }

    // Show an in-app snackbar.
    if (title.isEmpty) return;
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(title),
          action: SnackBarAction(
            label: 'View',
            onPressed: () =>
                navigatorKey.currentState?.pushNamed('/notifications'),
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return PeeplApp(navigatorKey: navigatorKey);
  }
}

class PeeplApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const PeeplApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeNotifier>(
      create: (_) => ThemeNotifier(),
      child: StreamProvider<User?>.value(
        value: AuthService().userStream,
        initialData: null,
        child: Consumer<ThemeNotifier>(
          builder: (context, themeNotifier, _) {
            return MaterialApp(
              title: 'Peepl',
              theme: ThemeData(
                primaryColor: Color(0xFF1565C0),
                scaffoldBackgroundColor: Color(0xFF1565C0),
              ),
              routes: appRoutes,
              navigatorKey: navigatorKey,
              home: _AuthGate(),
              debugShowCheckedModeBanner: false,
            );
          },
        ),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCompleted = prefs.getBool('hasCompletedOnboarding') ?? false;
    if (!mounted) return;

    if (!hasCompleted) {
      Navigator.pushReplacementNamed(context, '/splash');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      Future.microtask(
        () => PushNotificationService.instance.onUserSignedIn(),
      );
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
