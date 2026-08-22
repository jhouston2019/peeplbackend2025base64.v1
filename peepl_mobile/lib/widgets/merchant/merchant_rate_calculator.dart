import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/merchant_pricing_service.dart';
import 'merchant_metric_card.dart';
import 'merchant_screen_scaffold.dart';
import 'peepl_merchant_tokens.dart';

/// Interactive pricing explorer — uses [MerchantPricingService] only.
class MerchantRateCalculator extends StatefulWidget {
  const MerchantRateCalculator({super.key});

  @override
  State<MerchantRateCalculator> createState() => _MerchantRateCalculatorState();
}

class MerchantRateCalculatorScreen extends StatelessWidget {
  const MerchantRateCalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MerchantScreenScaffold(
      title: 'Rate Calculator',
      onBack: () => Navigator.pop(context),
      body: const MerchantRateCalculator(),
    );
  }
}

class _MerchantRateCalculatorState extends State<MerchantRateCalculator> {
  DateTime _slot = DateTime.now();
  double _radiusMiles = 1.0;
  PackageDuration _package = PackageDuration.none;
  int _hours = 2;

  CampaignQuote get _quote {
    final slots = List.generate(
      _hours,
      (i) => DateTime(_slot.year, _slot.month, _slot.day, _slot.hour + i),
    );
    return MerchantPricingService.quoteHourlySlots(
      slots: slots,
      radiusMiles: _radiusMiles,
      package: _package,
    );
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    final slotType = MerchantPricingService.resolveSlotType(_slot);
    final hourly = MerchantPricingService.hourlyRateForSlot(
      slot: _slot,
      radiusMiles: _radiusMiles,
    );

    return ListView(
      children: [
        Text(
          'Experiment with pricing before you purchase.',
          style: TextStyle(
            color: PeeplMerchantTokens.textSecondary.withValues(alpha: 0.95),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        _InputCard(
          title: 'Day & Time',
          child: Column(
            children: [
              _PickerRow(
                label: 'Day',
                value: _formatDay(_slot),
                onTap: () => _pickDate(context),
              ),
              const SizedBox(height: 10),
              _PickerRow(
                label: 'Time',
                value: _formatTime(_slot),
                onTap: () => _pickTime(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _InputCard(
          title: 'Radius',
          child: Slider(
            value: _radiusMiles,
            min: 0.5,
            max: 2.0,
            divisions: 3,
            label: '${_radiusMiles.toStringAsFixed(1)} mi',
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _radiusMiles = v);
            },
          ),
        ),
        const SizedBox(height: 12),
        _InputCard(
          title: 'Package',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PackageDuration.values.map((p) {
              final selected = _package == p;
              return ChoiceChip(
                label: Text(_packageLabel(p)),
                selected: selected,
                onSelected: (_) => setState(() => _package = p),
                selectedColor: PeeplMerchantTokens.accentBlue.withValues(alpha: 0.25),
                backgroundColor: PeeplMerchantTokens.glassFill,
                labelStyle: TextStyle(
                  color: selected
                      ? PeeplMerchantTokens.textPrimary
                      : PeeplMerchantTokens.textSecondary,
                ),
                side: BorderSide(
                  color: selected
                      ? PeeplMerchantTokens.accentBlue
                      : PeeplMerchantTokens.glassBorder,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _InputCard(
          title: 'Promotion Length',
          child: Row(
            children: [1, 2, 3, 4, 6].map((h) {
              final selected = _hours == h;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: h != 6 ? 6 : 0),
                  child: Material(
                    color: selected
                        ? PeeplMerchantTokens.accentBlue
                        : PeeplMerchantTokens.glassFill,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => setState(() => _hours = h),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '${h}h',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: PeeplMerchantTokens.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: PeeplMerchantTokens.gradientCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Estimate',
                style: TextStyle(
                  color: PeeplMerchantTokens.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              _QuoteRow('Rate type', MerchantPricingService.slotTypeLabel(slotType)),
              _QuoteRow('Hourly rate', MerchantPricingService.formatCurrency(hourly)),
              _QuoteRow(
                'Radius multiplier',
                '${MerchantPricingService.radiusMultiplier(_radiusMiles).toStringAsFixed(2)}×',
              ),
              _QuoteRow('Package discount', quote.packageLabel),
              _QuoteRow('Total hours', '${quote.hours}'),
              if (quote.packageDiscountAmount > 0)
                _QuoteRow(
                  'Discount',
                  '-${MerchantPricingService.formatCurrency(quote.packageDiscountAmount)}',
                ),
              if (quote.tax > 0)
                _QuoteRow('Taxes', MerchantPricingService.formatCurrency(quote.tax)),
              const Divider(color: PeeplMerchantTokens.border, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Final Total',
                    style: TextStyle(
                      color: PeeplMerchantTokens.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    MerchantPricingService.formatCurrency(quote.total),
                    style: const TextStyle(
                      color: PeeplMerchantTokens.accentBlue,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: MerchantMetricCard(
                label: 'Est. audience',
                value: merchantFormatCount(quote.estimatedAudience),
                animate: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MerchantMetricCard(
                label: 'Est. reach',
                value: merchantFormatCount(quote.estimatedReach),
                animate: false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _packageLabel(PackageDuration p) => switch (p) {
        PackageDuration.none => 'None',
        PackageDuration.weekly => 'Weekly',
        PackageDuration.monthly => 'Monthly',
        PackageDuration.quarterly => 'Quarterly',
      };

  String _formatDay(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.month}/${d.day}/${d.year}';
  }

  String _formatTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final p = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:00 $p';
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _slot,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && mounted) {
      setState(() => _slot = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _slot.hour,
          ));
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _slot.hour, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() => _slot = DateTime(
            _slot.year,
            _slot.month,
            _slot.day,
            picked.hour,
          ));
    }
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PeeplMerchantTokens.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: PeeplMerchantTokens.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PeeplMerchantTokens.glassFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text(label, style: const TextStyle(color: PeeplMerchantTokens.textMuted)),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  color: PeeplMerchantTokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  color: PeeplMerchantTokens.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: PeeplMerchantTokens.textMuted)),
          ),
          Text(
            value,
            style: const TextStyle(
              color: PeeplMerchantTokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
