import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/merchant_pricing_service.dart';
import 'peepl_merchant_tokens.dart';

enum MerchantCalendarView { week, month, agenda }

class MerchantCalendar extends StatefulWidget {
  const MerchantCalendar({
    super.key,
    required this.selectedSlots,
    required this.onSlotsChanged,
    this.view = MerchantCalendarView.agenda,
    this.onViewChanged,
    this.onSlotTap,
    this.radiusMiles = 1.0,
  });

  final Set<DateTime> selectedSlots;
  final ValueChanged<Set<DateTime>> onSlotsChanged;
  final MerchantCalendarView view;
  final ValueChanged<MerchantCalendarView>? onViewChanged;
  final void Function(DateTime slot, SlotDemand demand, double price)? onSlotTap;
  final double radiusMiles;

  @override
  State<MerchantCalendar> createState() => _MerchantCalendarState();
}

class _MerchantCalendarState extends State<MerchantCalendar>
    with SingleTickerProviderStateMixin {
  late DateTime _focusedWeekStart;
  late AnimationController _weekController;

  @override
  void initState() {
    super.initState();
    _focusedWeekStart = _weekStart(DateTime.now());
    _weekController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..value = 1;
  }

  @override
  void dispose() {
    _weekController.dispose();
    super.dispose();
  }

  void _changeWeek(int delta) {
    _weekController
      ..value = 0
      ..forward();
    setState(() {
      _focusedWeekStart = _focusedWeekStart.add(Duration(days: 7 * delta));
    });
  }

  DateTime _weekStart(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  void _toggleSlot(DateTime slot, SlotDemand demand) {
    if (demand == SlotDemand.soldOut) return;
    HapticFeedback.selectionClick();
    final normalized = DateTime(slot.year, slot.month, slot.day, slot.hour);
    final next = Set<DateTime>.from(widget.selectedSlots);

    if (next.contains(normalized)) {
      next.remove(normalized);
    } else {
      next.add(normalized);
      if (next.length > 1) {
        final sorted = next.toList()..sort();
        final contiguous = <DateTime>{sorted.first};
        for (var i = 1; i < sorted.length; i++) {
          final prev = sorted[i - 1];
          final cur = sorted[i];
          if (cur.difference(prev).inHours == 1) {
            contiguous.add(cur);
          }
        }
        if (contiguous.contains(normalized)) {
          next
            ..clear()
            ..addAll(contiguous);
        }
      }
    }

    widget.onSlotsChanged(next);
    widget.onSlotTap?.call(
      normalized,
      demand,
      MerchantPricingService.hourlyRateForSlot(
        slot: normalized,
        radiusMiles: widget.radiusMiles,
        demand: demand,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DemandLegend(),
        const SizedBox(height: 14),
        _WeekNavigator(
          label: _weekLabel(_focusedWeekStart),
          onPrev: () => _changeWeek(-1),
          onNext: () => _changeWeek(1),
        ),
        const SizedBox(height: 16),
        FadeTransition(
          opacity: _weekController,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.03, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _weekController,
              curve: Curves.easeOutCubic,
            )),
            child: _SlotCardList(
              weekStart: _focusedWeekStart,
              selected: widget.selectedSlots,
              radiusMiles: widget.radiusMiles,
              onToggle: _toggleSlot,
            ),
          ),
        ),
      ],
    );
  }

  String _weekLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[start.month - 1]} ${start.day} – ${months[end.month - 1]} ${end.day}';
  }
}

class _DemandLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      (SlotDemand.available, 'Available'),
      (SlotDemand.highDemand, 'High Demand'),
      (SlotDemand.soldOut, 'Sold Out'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: PeeplMerchantTokens.glassDecoration(radius: 14),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        children: items
            .map(
              (item) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: merchantDemandColor(item.$1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      color: PeeplMerchantTokens.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _WeekNavigator extends StatelessWidget {
  const _WeekNavigator({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NavButton(icon: Icons.chevron_left_rounded, onTap: onPrev),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PeeplMerchantTokens.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        _NavButton(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PeeplMerchantTokens.glassFill,
      shape: const CircleBorder(side: BorderSide(color: PeeplMerchantTokens.glassBorder)),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: PeeplMerchantTokens.textPrimary),
        ),
      ),
    );
  }
}

class _SlotCardList extends StatelessWidget {
  const _SlotCardList({
    required this.weekStart,
    required this.selected,
    required this.radiusMiles,
    required this.onToggle,
  });

  final DateTime weekStart;
  final Set<DateTime> selected;
  final double radiusMiles;
  final void Function(DateTime, SlotDemand) onToggle;

  @override
  Widget build(BuildContext context) {
    final slots = <DateTime>[];
    for (var d = 0; d < 7; d++) {
      for (var h = 12; h <= 23; h++) {
        slots.add(DateTime(weekStart.year, weekStart.month, weekStart.day + d, h));
      }
    }

    return Column(
      children: slots.map((slot) {
        final demand = MerchantPricingService.demandForSlot(slot);
        final normalized = DateTime(slot.year, slot.month, slot.day, slot.hour);
        final isSelected = selected.contains(normalized);
        final price = MerchantPricingService.hourlyRateForSlot(
          slot: slot,
          radiusMiles: radiusMiles,
          demand: demand,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: MerchantSlotCard(
            slot: slot,
            demand: demand,
            price: price,
            radiusMiles: radiusMiles,
            selected: isSelected,
            isToday: _isSameDay(slot, DateTime.now()),
            onTap: demand == SlotDemand.soldOut
                ? null
                : () => onToggle(slot, demand),
          ),
        );
      }).toList(),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class MerchantSlotCard extends StatefulWidget {
  const MerchantSlotCard({
    super.key,
    required this.slot,
    required this.demand,
    required this.price,
    required this.radiusMiles,
    this.selected = false,
    this.isToday = false,
    this.onTap,
  });

  final DateTime slot;
  final SlotDemand demand;
  final double price;
  final double radiusMiles;
  final bool selected;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  State<MerchantSlotCard> createState() => _MerchantSlotCardState();
}

class _MerchantSlotCardState extends State<MerchantSlotCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    if (widget.selected) _pulseController.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant MerchantSlotCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final soldOut = widget.demand == SlotDemand.soldOut;
    final accent = merchantDemandColor(widget.demand);

    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.015).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: soldOut
              ? PeeplMerchantTokens.card.withValues(alpha: 0.5)
              : widget.selected
                  ? PeeplMerchantTokens.accentBlue.withValues(alpha: 0.18)
                  : widget.isToday
                      ? PeeplMerchantTokens.cardElevated
                      : PeeplMerchantTokens.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.selected
                ? PeeplMerchantTokens.accentBlue
                : widget.isToday
                    ? PeeplMerchantTokens.accentBlue.withValues(alpha: 0.35)
                    : soldOut
                        ? PeeplMerchantTokens.border
                        : accent.withValues(alpha: 0.35),
            width: widget.selected ? 2 : 1,
          ),
          boxShadow: widget.selected ? PeeplMerchantTokens.premiumShadow : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(18),
            child: Opacity(
              opacity: soldOut ? 0.45 : 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _dayName(widget.slot.weekday),
                                style: TextStyle(
                                  color: soldOut
                                      ? PeeplMerchantTokens.textMuted
                                      : PeeplMerchantTokens.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (widget.isToday) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: PeeplMerchantTokens.accentBlue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Today',
                                    style: TextStyle(
                                      color: PeeplMerchantTokens.accentBlue,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatHour(widget.slot),
                            style: const TextStyle(
                              color: PeeplMerchantTokens.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            merchantDemandLabel(widget.demand),
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          MerchantPricingService.formatCurrency(widget.price),
                          style: TextStyle(
                            color: soldOut
                                ? PeeplMerchantTokens.textMuted
                                : PeeplMerchantTokens.accentBlue,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          '/hr',
                          style: TextStyle(
                            color: PeeplMerchantTokens.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Reach · ${widget.radiusMiles.toStringAsFixed(widget.radiusMiles == 1 ? 0 : 1)} mi',
                          style: const TextStyle(
                            color: PeeplMerchantTokens.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _dayName(int weekday) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return days[weekday - 1];
  }

  static String _formatHour(DateTime slot) {
    final hour = slot.hour % 12 == 0 ? 12 : slot.hour % 12;
    final period = slot.hour >= 12 ? 'PM' : 'AM';
    return '$hour $period';
  }
}

Color merchantDemandColor(SlotDemand demand) => switch (demand) {
      SlotDemand.available => PeeplMerchantTokens.success,
      SlotDemand.filling => PeeplMerchantTokens.success,
      SlotDemand.limited => PeeplMerchantTokens.warning,
      SlotDemand.highDemand => const Color(0xFFFF9F43),
      SlotDemand.soldOut => PeeplMerchantTokens.danger,
    };

String merchantDemandLabel(SlotDemand demand) => switch (demand) {
      SlotDemand.available => 'Available',
      SlotDemand.filling => 'Filling',
      SlotDemand.limited => 'Limited',
      SlotDemand.highDemand => 'High Demand',
      SlotDemand.soldOut => 'Sold Out',
    };
