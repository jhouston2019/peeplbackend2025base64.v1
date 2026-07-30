import 'package:flutter/material.dart';

import '../shell_tab_bus.dart';
import '../widgets/home/peepl_bottom_navigation.dart';
import '../widgets/home/peepl_home_tokens.dart';
import 'feed_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialBodyIndex = 0});

  final int initialBodyIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  void initState() {
    super.initState();
    final i = widget.initialBodyIndex;
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
      }
      ShellTabBus.pendingBodyIndex.value = null;
    });
  }

  @override
  void dispose() {
    ShellTabBus.pendingBodyIndex.removeListener(_onShellTabBus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplHomeTokens.feedBackground,
      body: const IndexedStack(index: 0, children: [FeedScreen()]),
      bottomNavigationBar: PeeplBottomNavigation(
        onExploreTap: () {},
        onSearchTap: () => Navigator.pushNamed(context, '/search'),
        onPostTap: () => Navigator.pushNamed(context, '/post'),
        onAlertsTap: () => Navigator.pushNamed(context, '/alerts'),
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
      ),
    );
  }
}
