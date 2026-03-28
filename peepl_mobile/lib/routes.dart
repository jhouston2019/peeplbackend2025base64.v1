import 'package:flutter/material.dart';
import 'screens/post_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/main_shell.dart';

Map<String, WidgetBuilder> appRoutes = {
  '/home': (_) => const MainShell(),
  '/feed': (_) => const MainShell(initialBodyIndex: 0),
  '/discover': (_) => const MainShell(initialBodyIndex: 1),
  '/post': (_) => PostScreen(),
  '/chat': (_) => const MainShell(initialBodyIndex: 2),
  '/profile': (_) => const MainShell(initialBodyIndex: 3),
  '/settings': (_) => SettingsScreen(),
  '/login': (_) => LoginScreen(),
  '/admin': (_) => const AdminScreen(),
};