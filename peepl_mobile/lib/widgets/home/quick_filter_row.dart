import 'package:flutter/material.dart';

import '../../notifiers/active_filter_notifier.dart';
import 'peepl_home_tokens.dart';

class QuickFilterChipData {
  const QuickFilterChipData({
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

class QuickFilterRow extends StatelessWidget {
  const QuickFilterRow({
    super.key,
    required this.chips,
    required this.onMoreTap,
  });

  final List<QuickFilterChipData> chips;
  final VoidCallback onMoreTap;

  static const _supportedChips = [
    QuickFilterChipData(
      label: 'Nearby',
      icon: Icons.near_me_outlined,
      iconColor: Color(0xFF34C759),
      filterValue: 'Nearby',
    ),
    QuickFilterChipData(
      label: 'Local',
      icon: Icons.store_outlined,
      iconColor: Color(0xFFFF9500),
      filterValue: 'Local',
    ),
    QuickFilterChipData(
      label: 'Newest',
      icon: Icons.schedule,
      iconColor: Color(0xFF64B5F6),
      filterValue: 'Newest',
    ),
    QuickFilterChipData(
      label: 'Region',
      icon: Icons.public,
      iconColor: Color(0xFFBA68C8),
      filterValue: 'Region',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final visibleChips = chips.isEmpty ? _supportedChips : chips;
    final chipWidgets = <Widget>[];

    for (var i = 0; i < visibleChips.length; i++) {
      if (i > 0) chipWidgets.add(const SizedBox(width: 8));
      final chip = visibleChips[i];
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
      _FilterChip(
        label: 'More',
        icon: Icons.more_horiz,
        iconColor: PeeplHomeTokens.white,
        selected: false,
        onTap: onMoreTap,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? PeeplHomeTokens.white.withValues(alpha: 0.16)
              : PeeplHomeTokens.chipBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? PeeplHomeTokens.white.withValues(alpha: 0.45)
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
                color: PeeplHomeTokens.white,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
