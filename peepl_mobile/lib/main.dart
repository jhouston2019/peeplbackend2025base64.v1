import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'routes.dart';
import 'services/auth_service.dart';
import 'theme_notifier.dart';
import 'screens/login_screen.dart';
import 'screens/feed_screen.dart';
import 'services/push_notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootDebugApp());
}

class BootDebugApp extends StatefulWidget {
  const BootDebugApp({super.key});

  @override
  State<BootDebugApp> createState() => _BootDebugAppState();
}

class _BootDebugAppState extends State<BootDebugApp> {
  String status = "Starting...";
  String? error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      setState(() => status = "Initializing Firebase...");

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      setState(() => status = "Firebase OK");

      await Future.delayed(const Duration(seconds: 1));

      runApp(const MyApp());
    } catch (e, stack) {
      setState(() {
        error = "$e\n\n$stack";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Text(
                error!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(status),
        ),
      ),
    );
  }
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
    PushNotificationService.instance.init(navKey: navigatorKey).then((_) {
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
      return FeedScreen();
    }
    return LoginScreen();
  }
}
