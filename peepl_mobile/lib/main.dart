import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'routes.dart';
import 'services/auth_service.dart';
import 'theme_notifier.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/push_notification_service.dart';
import 'services/geofence_service.dart' as geofence_svc;
import 'services/presence_service.dart';
import 'services/local_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class _AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    if (user != null) {
      Future.microtask(
        () => PushNotificationService.instance.onUserSignedIn(),
      );
      return const MainShell(initialBodyIndex: 0);
    }
    return LoginScreen();
  }
}
