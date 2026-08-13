import 'package:flutter/material.dart';

import '../shell_tab_bus.dart';
import '../widgets/home/peepl_bottom_navigation.dart';
import 'discover_screen.dart';
import 'feed_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialBodyIndex = 0});

  final int initialBodyIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _bodyIndex = 0;

  @override
  void initState() {
    super.initState();
    _bodyIndex = widget.initialBodyIndex.clamp(0, 1);
    final i = widget.initialBodyIndex;
    if (i == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushNamed('/deals');
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
        Navigator.of(context).pushNamed('/deals');
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
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: _bodyIndex,
        children: const [FeedScreen(), DiscoverScreen()],
      ),
      bottomNavigationBar: PeeplBottomNavigation(
        onExploreTap: () => Navigator.pushNamed(context, '/explore'),
        onSearchTap: () => Navigator.pushNamed(context, '/search'),
        onDealsTap: () => Navigator.pushNamed(context, '/deals'),
        onAlertsTap: () => Navigator.pushNamed(context, '/alerts'),
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
      ),
    );
  }
}
