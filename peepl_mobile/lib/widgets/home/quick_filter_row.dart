import 'package:flutter/material.dart';

import '../../notifiers/active_filter_notifier.dart';
import 'peepl_home_tokens.dart';

class QuickFilterRow extends StatelessWidget {
  const QuickFilterRow({
    super.key,
    required this.onDealsTap,
    required this.onMapTap,
    required this.onMoreTap,
    this.onRegionTap,
  });

  final VoidCallback onDealsTap;
  final VoidCallback onMapTap;
  final VoidCallback onMoreTap;
  final VoidCallback? onRegionTap;

  static const _filterChips = [
    _ChipSpec(
      label: 'Nearby',
      icon: Icons.near_me_outlined,
      iconColor: Color(0xFF34C759),
      filterValue: 'Nearby',
    ),
    _ChipSpec(
      label: 'Local',
      icon: Icons.store_outlined,
      iconColor: Color(0xFFFF9500),
      filterValue: 'Local',
    ),
    _ChipSpec(
      label: 'Newest',
      icon: Icons.schedule,
      iconColor: Color(0xFF64B5F6),
      filterValue: 'Newest',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final chipWidgets = <Widget>[
      _FilterChip(
        label: 'Deals',
        icon: Icons.local_offer_outlined,
        iconColor: PeeplHomeTokens.dealsGreen,
        labelColor: PeeplHomeTokens.dealsGreen,
        emphasized: true,
        onTap: onDealsTap,
      ),
      const SizedBox(width: 8),
      _FilterChip(
        label: 'Map',
        icon: Icons.map_outlined,
        iconColor: PeeplHomeTokens.white,
        onTap: onMapTap,
      ),
    ];

    for (final chip in _filterChips) {
      chipWidgets.add(const SizedBox(width: 8));
      chipWidgets.add(
        ValueListenableBuilder<String>(
          valueListenable: activeFilterNotifier,
          builder: (context, active, _) {
            return _FilterChip(
              label: chip.label,
              icon: chip.icon,
              iconColor: chip.iconColor,
              selected: active == chip.filterValue,
              onTap: () => activeFilterNotifier.value = chip.filterValue,
            );
          },
        ),
      );
    }

    chipWidgets.add(const SizedBox(width: 8));
    chipWidgets.add(
      ValueListenableBuilder<String>(
        valueListenable: activeFilterNotifier,
        builder: (context, active, _) {
          return _FilterChip(
            label: 'Region',
            icon: Icons.public_outlined,
            iconColor: const Color(0xFFAB47BC),
            selected: active == 'Region',
            onTap: () => onRegionTap?.call(),
          );
        },
      ),
    );

    chipWidgets.add(const SizedBox(width: 8));
    chipWidgets.add(
      _FilterChip(
        label: 'More',
        icon: Icons.more_horiz,
        iconColor: PeeplHomeTokens.white,
        onTap: onMoreTap,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: chipWidgets,
          ),
        ),
      ),
    );
  }
}

class _ChipSpec {
  const _ChipSpec({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.filterValue,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final String filterValue;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.labelColor,
    this.emphasized = false,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Color? labelColor;
  final bool emphasized;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = labelColor ?? PeeplHomeTokens.white;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: emphasized
              ? PeeplHomeTokens.dealsGreen.withValues(alpha: 0.12)
              : selected
                  ? PeeplHomeTokens.white.withValues(alpha: 0.14)
                  : PeeplHomeTokens.chipSurface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: emphasized
                ? PeeplHomeTokens.dealsGreen.withValues(alpha: 0.25)
                : selected
                    ? PeeplHomeTokens.white.withValues(alpha: 0.20)
                    : PeeplHomeTokens.chipBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: emphasized || selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
