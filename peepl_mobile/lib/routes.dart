import 'package:flutter/material.dart';
import 'screens/feed_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/post_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_screen.dart';

Map<String, WidgetBuilder> appRoutes = {
  '/feed': (_) => FeedScreen(),
  '/discover': (_) => DiscoverScreen(),
  '/post': (_) => PostScreen(),
  '/chat': (_) => ChatScreen(),
  '/profile': (_) => ProfileScreen(),
  '/settings': (_) => SettingsScreen(),
  '/login': (_) => LoginScreen(),
  '/admin': (_) => const AdminScreen(),
};