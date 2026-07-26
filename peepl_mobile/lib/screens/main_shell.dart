import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../shell_tab_bus.dart';
import 'discover_screen.dart';
import 'feed_screen.dart';
import 'notifications_screen.dart';

const Color _kSelectedBlue = Color(0xFF0A66FF);

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialBodyIndex = 0});

  /// Legacy indices: 0 Feed, 1 Discover, 2 Post (opens /post), 3 Notifications, 4 Profile (menu).
  /// Bottom bar indices: 0 Home, 1 Discover, 2 Notifications.
  final int initialBodyIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  static const List<Widget> _tabBodies = [
    FeedScreen(),
    DiscoverScreen(),
    NotificationsScreen(),
  ];

  /// Maps legacy body indices (incl. Post=2 / Menu=4) onto the 3-tab bar.
  int _barIndexFromLegacy(int legacy) {
    switch (legacy) {
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
    _currentIndex = _barIndexFromLegacy(i);
    if (i == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushNamed('/post');
      });
    } else if (i == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushNamed('/menu');
      });
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
        setState(() => _currentIndex = _barIndexFromLegacy(v));
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
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabBodies,
      ),
      bottomNavigationBar: Container(
        height: 41 + bottomInset,
        padding: EdgeInsets.only(bottom: bottomInset),
        color: _kSelectedBlue,
        child: Row(
          children: [
            _CompactBottomNavItem(
              icon: Icons.home,
              label: 'Home',
              selected: _currentIndex == 0,
              onTap: () => _onBarTap(0),
            ),
            _CompactBottomNavItem(
              icon: Icons.explore,
              label: 'Discover',
              selected: _currentIndex == 1,
              onTap: () => _onBarTap(1),
            ),
            _CompactBottomNavItem(
              icon: Icons.notifications_outlined,
              label: 'Alerts',
              selected: _currentIndex == 2,
              onTap: () => _onBarTap(2),
              notificationUid: uid,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactBottomNavItem extends StatelessWidget {
  const _CompactBottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.notificationUid,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? notificationUid;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.6);

    Widget iconWidget = Icon(icon, size: 16, color: color);

    if (notificationUid != null) {
      iconWidget = StreamBuilder<int>(
        stream: NotificationsScreen.unreadCountStream(notificationUid!),
        builder: (context, snap) {
          final count = snap.data ?? 0;
          final iconChild = Icon(icon, size: 16, color: color);
          if (count <= 0) return iconChild;
          return Badge(
            label: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(fontSize: 7, height: 1.0),
            ),
            backgroundColor: Colors.red,
            child: iconChild,
          );
        },
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
