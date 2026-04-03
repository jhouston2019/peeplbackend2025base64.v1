import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'routes.dart';
import 'services/auth_service.dart';
import 'theme_notifier.dart';
import 'screens/login_screen.dart';
import 'services/push_notification_service.dart';
import 'screens/feed_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    await PushNotificationService.instance.init(navKey: navigatorKey);
    runApp(PeeplApp(navigatorKey: navigatorKey));
  } catch (e, stack) {
    debugPrint('STARTUP ERROR: $e');
    debugPrint('$stack');
    // ignore: avoid_print
    print('STARTUP ERROR: $e');
    // ignore: avoid_print
    print(stack);
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText('STARTUP ERROR:\n$e\n\n$stack'),
            ),
          ),
        ),
      ),
    );
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
