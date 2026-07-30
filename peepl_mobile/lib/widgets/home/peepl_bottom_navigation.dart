import 'package:flutter/material.dart';

import 'peepl_home_tokens.dart';

class PeeplBottomNavigation extends StatelessWidget {
  const PeeplBottomNavigation({
    super.key,
    required this.onExploreTap,
    required this.onSearchTap,
    required this.onPostTap,
    required this.onAlertsTap,
    required this.onProfileTap,
    this.showAlertDot = false,
  });

  final VoidCallback onExploreTap;
  final VoidCallback onSearchTap;
  final VoidCallback onPostTap;
  final VoidCallback onAlertsTap;
  final VoidCallback onProfileTap;
  final bool showAlertDot;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: PeeplHomeTokens.navyHeader,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: PeeplHomeTokens.bottomNavHeight,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  label: 'Explore',
                  icon: Icons.home_rounded,
                  selected: true,
                  accentColor: PeeplHomeTokens.yellow,
                  onTap: onExploreTap,
                ),
              ),
              Expanded(
                child: _NavItem(
                  label: 'Search',
                  icon: Icons.search,
                  onTap: onSearchTap,
                ),
              ),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: onPostTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: PeeplHomeTokens.yellow,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: PeeplHomeTokens.yellow.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Color(0xFF111111),
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _NavItem(
                  label: 'Alerts',
                  icon: Icons.notifications_outlined,
                  onTap: onAlertsTap,
                  showDot: showAlertDot,
                ),
              ),
              Expanded(
                child: _NavItem(
                  label: 'Profile',
                  icon: Icons.person_outline,
                  onTap: onProfileTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.accentColor,
    this.showDot = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  final Color? accentColor;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? (accentColor ?? PeeplHomeTokens.yellow)
        : PeeplHomeTokens.white.withValues(alpha: 0.88);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 22),
                if (showDot)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
