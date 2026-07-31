import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/merchant_pricing_service.dart';
import 'merchant_calendar.dart' show merchantDemandLabel;
import 'merchant_metric_card.dart';
import 'peepl_merchant_tokens.dart';

class MerchantTimeSelector extends StatelessWidget {
  const MerchantTimeSelector({
    super.key,
    required this.selectedSlots,
    required this.radiusMiles,
    this.onClear,
  });

  final Set<DateTime> selectedSlots;
  final double radiusMiles;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final sorted = selectedSlots.toList()..sort();
    final quote = MerchantPricingService.quoteHourlySlots(
      slots: sorted,
      radiusMiles: radiusMiles,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Selected Hours',
                style: PeeplMerchantTokens.sectionTitle(context),
              ),
            ),
            if (onClear != null && sorted.isNotEmpty)
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onClear!();
                },
                child: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: PeeplMerchantTokens.glassDecoration(),
            child: const Text(
              'Tap hours on the calendar to select your campaign schedule.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PeeplMerchantTokens.textSecondary, height: 1.4),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sorted.map((slot) {
              final demand = MerchantPricingService.demandForSlot(slot);
              final price = MerchantPricingService.hourlyRateForSlot(
                slot: slot,
                radiusMiles: radiusMiles,
                demand: demand,
              );
              return _SelectedHourChip(slot: slot, price: price, demand: demand);
            }).toList(),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: MerchantMetricCard(
                label: 'Total Hours',
                value: '${quote.hours}',
                icon: Icons.schedule_rounded,
                animate: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MerchantMetricCard(
                label: 'Est. Reach',
                value: merchantFormatCount(quote.estimatedReach),
                icon: Icons.people_outline_rounded,
                animate: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MerchantMetricCard(
                label: 'Current Demand',
                value: sorted.isEmpty
                    ? '—'
                    : merchantDemandLabel(
                        MerchantPricingService.demandForSlot(sorted.last),
                      ),
                icon: Icons.speed_rounded,
                animate: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MerchantMetricCard(
                label: 'Dynamic Price',
                value: MerchantPricingService.formatCurrency(quote.total),
                icon: Icons.payments_outlined,
                animate: false,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SelectedHourChip extends StatelessWidget {
  const _SelectedHourChip({
    required this.slot,
    required this.price,
    required this.demand,
  });

  final DateTime slot;
  final double price;
  final SlotDemand demand;

  @override
  Widget build(BuildContext context) {
    final hour = slot.hour % 12 == 0 ? 12 : slot.hour % 12;
    final period = slot.hour >= 12 ? 'PM' : 'AM';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            PeeplMerchantTokens.accentBlue.withValues(alpha: 0.25),
            PeeplMerchantTokens.cardElevated,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PeeplMerchantTokens.accentBlue.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${slot.month}/${slot.day} · $hour$period',
            style: const TextStyle(
              color: PeeplMerchantTokens.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${MerchantPricingService.formatCurrency(price)}/hr · ${merchantDemandLabel(demand)}',
            style: const TextStyle(
              color: PeeplMerchantTokens.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
