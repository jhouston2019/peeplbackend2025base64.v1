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

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialBodyIndex = 0});

  /// 0 Feed, 1 Discover, 2 Post, 3 Chat, 4 Profile
  final int initialBodyIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  static final List<Widget> _screens = [
    const FeedScreen(),
    const DiscoverScreen(),
    const PostScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialBodyIndex.clamp(0, _screens.length - 1);
    ShellTabBus.pendingBodyIndex.addListener(_onShellTabBus);
  }

  void _onShellTabBus() {
    final v = ShellTabBus.pendingBodyIndex.value;
    if (v == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _currentIndex = v.clamp(0, _screens.length - 1);
      });
      ShellTabBus.pendingBodyIndex.value = null;
    });
  }

  @override
  void dispose() {
    ShellTabBus.pendingBodyIndex.removeListener(_onShellTabBus);
    super.dispose();
  }

  void _onBarTap(int index, bool isAdmin) {
    if (isAdmin && index == _screens.length) {
      Navigator.of(context).pushNamed('/admin');
      return;
    }
    setState(() => _currentIndex = index);
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
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: _kBarBlue,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withValues(alpha: 0.5),
        currentIndex: _currentIndex,
        onTap: (i) => _onBarTap(i, isAdmin),
        items: _barItems(isAdmin),
        iconSize: 26,
        selectedFontSize: 12,
        unselectedFontSize: 11,
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
        if (snap.hasError) return _scaffoldForAdmin(false);
        final isAdmin = snap.data?.data()?['isAdmin'] == true;
        return _scaffoldForAdmin(isAdmin);
      },
    );
  }
}
