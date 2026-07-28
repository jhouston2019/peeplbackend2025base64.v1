import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../notifiers/active_filter_notifier.dart';
import '../shell_tab_bus.dart';
import 'alerts_screen.dart';
import 'discover_screen.dart';
import 'feed_screen.dart';

const Color _kSelectedBlue = Color(0xFF0A66FF);

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialBodyIndex = 0});

  /// Legacy indices: 0 Feed, 1 Discover, 2 Post (opens /post), 3 Notifications, 4 Profile (menu).
  /// Bottom bar indices: 0 Home, 1 Discover, 2 Alerts.
  final int initialBodyIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  static const List<Widget> _tabBodies = [
    FeedScreen(),
    DiscoverScreen(),
    AlertsScreen(),
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

  Widget _shellPill(String label, IconData icon) {
    return GestureDetector(
      onTap: () {
        activeFilterNotifier.value = label;
        if (label == 'Map') {
          Navigator.pushNamed(context, '/map');
        }
      },
      child: ValueListenableBuilder<String>(
        valueListenable: activeFilterNotifier,
        builder: (context, activeFilter, _) {
          final isActive = activeFilter == label;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF1565C0) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF1565C0)
                    : Colors.grey[400]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 11,
                  color: isActive ? Colors.white : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? Colors.white : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 36,
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _shellPill('Newest', Icons.calendar_today),
                    const SizedBox(width: 6),
                    _shellPill('Nearby', Icons.location_on),
                    const SizedBox(width: 6),
                    _shellPill('Local', Icons.store),
                    const SizedBox(width: 6),
                    _shellPill('Map', Icons.map),
                    const SizedBox(width: 6),
                    _shellPill('Region', Icons.public),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            height: 52 + bottomInset,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                backgroundColor: _kSelectedBlue,
                elevation: 0,
                iconSize: 20,
                selectedFontSize: 10,
                unselectedFontSize: 10,
                selectedItemColor: Colors.white,
                unselectedItemColor: Colors.white.withValues(alpha: 0.6),
                currentIndex: _currentIndex,
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
                  BottomNavigationBarItem(
                    icon: _AlertsNavIcon(notificationUid: uid),
                    label: 'Alerts',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsNavIcon extends StatelessWidget {
  const _AlertsNavIcon({this.notificationUid});

  final String? notificationUid;

  @override
  Widget build(BuildContext context) {
    const icon = Icon(Icons.notifications_outlined, size: 20);

    if (notificationUid == null) return icon;

    return StreamBuilder<int>(
      stream: AlertsScreen.unreadCountStream(notificationUid!),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        if (count <= 0) return icon;
        return Badge(
          label: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(fontSize: 8, height: 1.0),
          ),
          backgroundColor: Colors.red,
          child: icon,
        );
      },
    );
  }
}
