import 'package:flutter/material.dart';
import '../notifiers/active_filter_notifier.dart';
import '../shell_tab_bus.dart';
import 'feed_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialBodyIndex = 0});

  final int initialBodyIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

/// Home feed shell navy — matches feed header.
const _kFeedShellNavy = Color(0xFF153E75);

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
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isActive ? 8 : 6,
                  vertical: isActive ? 4 : 2,
                ),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                    width: 1,
                  ),
                  boxShadow: isActive
                      ? const [
                          BoxShadow(
                            color: Color(0x18000000),
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 11,
                      color: isActive ? _kFeedShellNavy : Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isActive ? _kFeedShellNavy : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: IndexedStack(index: 0, children: const [FeedScreen()]),
      bottomNavigationBar: ColoredBox(
        color: _kFeedShellNavy,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: 44,
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
        ),
      ),
    );
  }
}
