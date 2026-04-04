import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../shell_tab_bus.dart';
import 'chat_screen.dart';
import 'discover_screen.dart';
import 'feed_screen.dart';
import 'post_screen.dart';
import 'profile_screen.dart';

const Color _kBarBlue = Color(0xFF1565C0);
const Color _kBarSelected = Color(0xFF1565C0);
const Color _kBarUnselected = Color(0xFF9E9E9E);
const int _postBarIndex = 2;

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialBodyIndex = 0});

  /// 0 Feed, 1 Discover, 2 Chat, 3 Profile
  final int initialBodyIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _bodyIndex;
  final List<GlobalKey<NavigatorState>> _navigatorKeys =
      List<GlobalKey<NavigatorState>>.generate(4, (_) => GlobalKey());

  static final List<Widget> _tabRoots = <Widget>[
    const FeedScreen(),
    DiscoverScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _bodyIndex = widget.initialBodyIndex.clamp(0, _tabRoots.length - 1);
    ShellTabBus.pendingBodyIndex.addListener(_onShellTabBus);
  }

  void _onShellTabBus() {
    final v = ShellTabBus.pendingBodyIndex.value;
    if (v == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _bodyIndex = v.clamp(0, _tabRoots.length - 1);
      });
      ShellTabBus.pendingBodyIndex.value = null;
    });
  }

  @override
  void dispose() {
    ShellTabBus.pendingBodyIndex.removeListener(_onShellTabBus);
    super.dispose();
  }

  int _bodyIndexToBarIndex(bool isAdmin) {
    if (_bodyIndex <= 1) return _bodyIndex;
    return _bodyIndex + 1;
  }

  void _onBarTap(int barIndex, bool isAdmin) {
    final adminBarIndex = isAdmin ? 5 : -1;

    if (barIndex == _postBarIndex) {
      _openPostModal();
      return;
    }
    if (isAdmin && barIndex == adminBarIndex) {
      Navigator.of(context).pushNamed('/admin');
      return;
    }

    int body;
    if (barIndex < _postBarIndex) {
      body = barIndex;
    } else {
      body = barIndex - 1;
    }
    setState(() => _bodyIndex = body);
  }

  void _openPostModal() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const PostScreen(),
      ),
    );
  }

  Widget _tabNavigator(int index) {
    return Navigator(
      key: _navigatorKeys[index],
      initialRoute: '/',
      onGenerateRoute: (RouteSettings settings) {
        final name = settings.name;
        if (name == '/' || name == null) {
          return MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/'),
            builder: (_) => _tabRoots[index],
          );
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => _tabRoots[index],
        );
      },
    );
  }

  List<BottomNavigationBarItem> _barItems(bool isAdmin) {
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        label: 'Feed',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.explore_outlined),
        label: 'Discover',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.add_circle),
        label: 'Post',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.chat_bubble_outline),
        label: 'Chat',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        label: 'Profile',
      ),
    ];
    if (isAdmin) {
      items.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.shield_outlined),
          label: 'Admin',
        ),
      );
    }
    return items;
  }

  Widget _scaffoldForAdmin(bool isAdmin) {
    final barIndex = _bodyIndexToBarIndex(isAdmin);
    return Scaffold(
      body: IndexedStack(
        index: _bodyIndex,
        children: List<Widget>.generate(
          _tabRoots.length,
          (i) => _tabNavigator(i),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: _kBarSelected,
        unselectedItemColor: _kBarUnselected,
        currentIndex: barIndex,
        onTap: (i) => _onBarTap(i, isAdmin),
        items: _barItems(isAdmin),
        iconSize: 26,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        elevation: 8,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _scaffoldForAdmin(false);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        final isAdmin = snap.data?.data()?['isAdmin'] == true;
        return _scaffoldForAdmin(isAdmin);
      },
    );
  }
}
