import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/constants.dart';
import 'deep_link_handler.dart';
import 'firebase_options.dart';
import 'routes.dart';
import 'screens/feed_screen.dart';
import 'services/admob_service.dart';
import 'services/auth_service.dart';
import 'services/geofence_service.dart' as geofence_svc;
import 'services/notification_service.dart';
import 'services/remote_config_service.dart';
import 'theme/peepl_app_tokens.dart';
import 'theme_notifier.dart';

ThemeData _buildLightTheme() => PeeplAppTokens.buildTheme();

ThemeData _buildDarkTheme() => PeeplAppTokens.buildTheme();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await RemoteConfigService.instance.initialize();

  await AdmobService.initialize();

  if (!kIsWeb) {
    Stripe.publishableKey = kStripePublishableKey;
    await Stripe.instance.applySettings();
  }

  await NotificationService.instance.initialize();

  if (!kIsWeb) {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null &&
        initialMessage.data['type'] == 'walk_in_prompt') {
      NotificationService.instance.captureColdStartWalkIn(initialMessage);
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.instance.attachNavigator(navigatorKey).then((_) async {
      NotificationService.instance.onVenueEntryInAppPrompt = (name) {
        FeedScreen.onGeofenceVenueEntry?.call(name);
      };
      final geofenceService = geofence_svc.PeeplGeofenceService.instance;
      await geofenceService.initialize();
      await DeepLinkHandler.initialize(navigatorKey);

      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateLastActive();
      unawaited(NotificationService.instance.syncLocationForCrowdsourceTargeting());
    }
  }

  Future<void> _updateLastActive() async {
    if (!FeedScreen.comebackCheckComplete) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3')
          .doc(uid)
          .set(
        {'lastActive': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        theme: PeeplAppTokens.buildTheme(),
        home: const Scaffold(
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
              theme: _buildLightTheme(),
              darkTheme: _buildDarkTheme(),
              themeMode: themeNotifier.isDarkMode
                  ? ThemeMode.dark
                  : ThemeMode.light,
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
    // Web debug: skip auth/onboarding and land on home (or hash route).
    if (kDebugMode && kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      await prefs.setBool('hasCompletedOnboarding', true);

      final route = _webDebugEntryRoute();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, route);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        DeepLinkHandler.markStartupComplete();
      });
      return;
    }

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
        DeepLinkHandler.markStartupComplete();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  /// Chrome QA entry — defaults to [/home]; honors `#/feed`, `#/feed_preview`, etc.
  static String _webDebugEntryRoute() {
    const allowed = <String>{
      '/home',
      '/feed',
      '/feed_preview',
      '/discover',
    };

    var fragment = Uri.base.fragment.trim();
    if (fragment.isEmpty) {
      return '/home';
    }
    if (!fragment.startsWith('/')) {
      fragment = '/$fragment';
    }
    // Strip query string if present.
    final q = fragment.indexOf('?');
    if (q >= 0) {
      fragment = fragment.substring(0, q);
    }
    return allowed.contains(fragment) ? fragment : '/home';
  }
}
