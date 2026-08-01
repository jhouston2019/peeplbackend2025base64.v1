import 'package:flutter/material.dart';

import 'peepl_home_tokens.dart';

class PeeplBottomNavigation extends StatelessWidget {
  const PeeplBottomNavigation({
    super.key,
    required this.onExploreTap,
    required this.onSearchTap,
    required this.onDealsTap,
    required this.onAlertsTap,
    required this.onProfileTap,
    this.showAlertDot = false,
  });

  static const _dealsButtonHeight = 43.2;
  static const _dealsButtonRadius = 21.6;
  static const _dealsHorizontalPadding = 16.8;
  static const _dealsIconSize = 21.6;
  static const _dealsFontSize = 15.6;
  static const _dealsCenterReserve = 109.0;
  static const _navGroupInset = 10.0;

  final VoidCallback onExploreTap;
  final VoidCallback onSearchTap;
  final VoidCallback onDealsTap;
  final VoidCallback onAlertsTap;
  final VoidCallback onProfileTap;
  final bool showAlertDot;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: PeeplHomeTokens.shellNavy,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: PeeplHomeTokens.bottomNavHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: _navGroupInset),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _NavItem(
                              label: 'Explore',
                              icon: Icons.home_rounded,
                              selected: true,
                              onTap: onExploreTap,
                            ),
                            _NavItem(
                              label: 'Search',
                              icon: Icons.search,
                              onTap: onSearchTap,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: _dealsCenterReserve),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: _navGroupInset),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _NavItem(
                              label: 'Alerts',
                              icon: Icons.notifications_outlined,
                              onTap: onAlertsTap,
                              showDot: showAlertDot,
                            ),
                            _NavItem(
                              label: 'Profile',
                              icon: Icons.person_outline,
                              onTap: onProfileTap,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Semantics(
              label: 'Deals',
              button: true,
              child: GestureDetector(
                onTap: onDealsTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: _dealsButtonHeight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: _dealsHorizontalPadding,
                  ),
                  decoration: BoxDecoration(
                    color: PeeplHomeTokens.dealsYellow.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(_dealsButtonRadius),
                    border: Border.all(
                      color: PeeplHomeTokens.dealsYellow.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_offer_outlined,
                        color: PeeplHomeTokens.dealsForeground,
                        size: _dealsIconSize,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Deals',
                        style: TextStyle(
                          color: PeeplHomeTokens.dealsForeground,
                          fontSize: _dealsFontSize,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
        ? (accentColor ?? PeeplHomeTokens.white)
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
