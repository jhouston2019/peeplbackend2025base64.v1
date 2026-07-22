import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../shell_tab_bus.dart';
import 'discover_screen.dart';
import 'feed_screen.dart';
import 'notifications_screen.dart';

const Color _kSelectedBlue = Color(0xFF1565C0);

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialBodyIndex = 0});

  /// Legacy indices: 0 Feed, 1 Discover, 2 Post (opens /post), 3 Notifications, 4 Profile (home).
  final int initialBodyIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// Bottom bar indices: 0 Home, 1 Discover, 3 Notifications (2 and 4 are push-only).
  late int _currentBarIndex;

  static const List<Widget> _tabBodies = [
    FeedScreen(),
    DiscoverScreen(),
    NotificationsScreen(),
  ];

  int get _stackIndex {
    switch (_currentBarIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 3:
        return 2;
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    final i = widget.initialBodyIndex;
    if (i == 0 || i == 1 || i == 3) {
      _currentBarIndex = i;
    } else {
      _currentBarIndex = 0;
      if (i == 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pushNamed('/post');
        });
      }
    }
    ShellTabBus.pendingBodyIndex.addListener(_onShellTabBus);
  }

  void _onShellTabBus() {
    final v = ShellTabBus.pendingBodyIndex.value;
    if (v == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (v == 2) {
        Navigator.of(context).pushNamed('/post');
      } else if (v == 4) {
        Navigator.of(context).pushNamed('/menu');
      } else if (v == 0 || v == 1 || v == 3) {
        setState(() => _currentBarIndex = v);
      }
      ShellTabBus.pendingBodyIndex.value = null;
    });
  }

  @override
  void dispose() {
    ShellTabBus.pendingBodyIndex.removeListener(_onShellTabBus);
    super.dispose();
  }

  void _onBarTap(int index) {
    if (index == 2) {
      Navigator.of(context).pushNamed('/post');
      return;
    }
    if (index == 4) {
      Navigator.of(context).pushNamed('/menu');
      return;
    }
    setState(() => _currentBarIndex = index);
  }

  Widget _notificationNavIcon(String? uid) {
    const icon = Icon(Icons.notifications_outlined);
    if (uid == null) return icon;

    return StreamBuilder<int>(
      stream: NotificationsScreen.unreadCountStream(uid),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        if (count <= 0) return icon;
        return Badge(
          label: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(fontSize: 10),
          ),
          backgroundColor: Colors.red,
          child: icon,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: IndexedStack(
        index: _stackIndex,
        children: _tabBodies,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: _kSelectedBlue,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withValues(alpha: 0.6),
        currentIndex: _currentBarIndex,
        onTap: _onBarTap,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Discover',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Post',
          ),
          BottomNavigationBarItem(
            icon: _notificationNavIcon(uid),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.menu),
            label: 'Menu',
          ),
        ],
        iconSize: 26,
        selectedFontSize: 12,
        unselectedFontSize: 11,
      ),
    );
  }
}
