import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'services/notification_service.dart';
import 'services/presence_service.dart';
import 'theme_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    Stripe.publishableKey = kStripePublishableKey;
    await Stripe.instance.applySettings();
  }

  await NotificationService.instance.initialize();
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
    NotificationService.instance.attachNavigator(navigatorKey).then((_) async {
      final geofenceService = geofence_svc.PeeplGeofenceService.instance;
      await LocalNotificationService.instance
          .initialize(navigatorKey: navigatorKey);
      geofenceService.onLocationEntered = (locationId, name, lat, lng) async {
        debugPrint('GEOFENCE ENTERED: $name ($locationId) at $lat, $lng');
        await PresenceService.instance.recordArrival(name, lat, lng);
      };
      await geofenceService.initialize();
      await geofenceService.loadGeofencesFromFirestore();

      if (mounted) setState(() => _ready = true);
    });
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
    final onboardingComplete =
        prefs.getBool('onboarding_complete') ?? false;
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user != null && !onboardingComplete) {
      Navigator.pushReplacementNamed(context, '/onboarding/1');
      return;
    }

    if (!onboardingComplete) {
      Navigator.pushReplacementNamed(context, '/splash');
      return;
    }

    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      final route = await NotificationService.instance.routeAfterLogin();
      Future.microtask(
        () => NotificationService.instance.onUserSignedIn(),
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, route);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.instance.processPendingNotification();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
