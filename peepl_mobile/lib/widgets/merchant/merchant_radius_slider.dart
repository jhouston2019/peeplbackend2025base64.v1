import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/merchant_pricing_service.dart';
import 'merchant_metric_card.dart';
import 'peepl_merchant_tokens.dart';

class MerchantRadiusSlider extends StatelessWidget {
  const MerchantRadiusSlider({
    super.key,
    required this.radiusMiles,
    required this.onChanged,
    this.showMetrics = true,
  });

  final double radiusMiles;
  final ValueChanged<double> onChanged;
  final bool showMetrics;

  @override
  Widget build(BuildContext context) {
    final audience = MerchantPricingService.estimatedAudience(radiusMiles);
    final multiplier = MerchantPricingService.radiusMultiplier(radiusMiles);
    final tier = _pricingTier(radiusMiles);
    final coverage = _coverageLabel(radiusMiles);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Target Radius', style: PeeplMerchantTokens.sectionTitle(context)),
        const SizedBox(height: 20),
        _RadiusVisualCircle(radiusMiles: radiusMiles),
        const SizedBox(height: 24),
        Row(
          children: MerchantPricingService.radiusOptions.map((miles) {
            final selected = (radiusMiles - miles).abs() < 0.01;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: miles != MerchantPricingService.radiusOptions.last ? 8 : 0,
                ),
                child: _RadiusOption(
                  miles: miles,
                  selected: selected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(miles);
                  },
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: PeeplMerchantTokens.accentBlue,
            inactiveTrackColor: PeeplMerchantTokens.glassFill,
            thumbColor: PeeplMerchantTokens.textPrimary,
            overlayColor: PeeplMerchantTokens.accentBlue.withValues(alpha: 0.15),
            trackHeight: 6,
          ),
          child: Slider(
            value: radiusMiles,
            min: 0.5,
            max: 2.0,
            divisions: 3,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ),
        Text(
          'Selected Radius',
          style: TextStyle(
            color: PeeplMerchantTokens.textMuted.withValues(alpha: 0.9),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${radiusMiles.toStringAsFixed(radiusMiles == radiusMiles.roundToDouble() ? 0 : 1)} Mile',
          style: const TextStyle(
            color: PeeplMerchantTokens.accentBlue,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        if (showMetrics) ...[
          const SizedBox(height: 20),
          _MetricRow(
            label: 'Audience Reach',
            value: merchantFormatCount(audience),
          ),
          const SizedBox(height: 10),
          _MetricRow(label: 'Pricing Tier', value: tier),
          const SizedBox(height: 10),
          _MetricRow(
            label: 'Radius Multiplier',
            value: '${multiplier.toStringAsFixed(2)}×',
          ),
          const SizedBox(height: 10),
          _MetricRow(label: 'Estimated Coverage', value: coverage),
        ],
      ],
    );
  }

  static String _pricingTier(double miles) => switch (miles) {
        0.5 => 'Local',
        1.0 => 'Standard',
        1.5 => 'Extended',
        _ => 'Maximum',
      };

  static String _coverageLabel(double miles) {
    if (miles <= 0.5) return 'Neighborhood';
    if (miles <= 1.0) return 'District';
    if (miles <= 1.5) return 'City zone';
    return 'Wide area';
  }
}

class _RadiusVisualCircle extends StatelessWidget {
  const _RadiusVisualCircle({required this.radiusMiles});

  final double radiusMiles;

  @override
  Widget build(BuildContext context) {
    final scale = 0.35 + (radiusMiles / 2.0) * 0.65;
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(180, 180),
            painter: _RadiusRingPainter(scale: scale),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PeeplMerchantTokens.accentBlue,
              shape: BoxShape.circle,
              boxShadow: PeeplMerchantTokens.premiumShadow,
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}

class _RadiusRingPainter extends CustomPainter {
  _RadiusRingPainter({required this.scale});

  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) / 2 * 0.92;

    for (var i = 3; i >= 1; i--) {
      final r = maxR * scale * (i / 3);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == 3 ? 2 : 1
        ..color = PeeplMerchantTokens.accentBlue.withValues(alpha: 0.08 + i * 0.06);
      canvas.drawCircle(center, r, paint);
    }

    final fill = Paint()
      ..shader = RadialGradient(
        colors: [
          PeeplMerchantTokens.accentBlue.withValues(alpha: 0.18),
          PeeplMerchantTokens.accentBlue.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxR * scale));
    canvas.drawCircle(center, maxR * scale, fill);
  }

  @override
  bool shouldRepaint(covariant _RadiusRingPainter oldDelegate) =>
      oldDelegate.scale != scale;
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: PeeplMerchantTokens.glassDecoration(radius: 14),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: PeeplMerchantTokens.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: PeeplMerchantTokens.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadiusOption extends StatelessWidget {
  const _RadiusOption({
    required this.miles,
    required this.selected,
    required this.onTap,
  });

  final double miles;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = miles == miles.roundToDouble()
        ? '${miles.toInt()}'
        : miles.toString();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                colors: [
                  PeeplMerchantTokens.accentGradientStart,
                  PeeplMerchantTokens.accentGradientEnd,
                ],
              )
            : null,
        color: selected ? null : PeeplMerchantTokens.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? PeeplMerchantTokens.accentBlue
              : PeeplMerchantTokens.glassBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: PeeplMerchantTokens.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'mi',
                  style: TextStyle(
                    color: PeeplMerchantTokens.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
