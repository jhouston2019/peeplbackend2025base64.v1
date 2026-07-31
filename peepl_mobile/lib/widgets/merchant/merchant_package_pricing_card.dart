import 'package:flutter/material.dart';

import '../../services/merchant_pricing_service.dart';
import 'merchant_interactions.dart';
import 'peepl_merchant_tokens.dart';

class MerchantPackagePricingCard extends StatelessWidget {
  const MerchantPackagePricingCard({
    super.key,
    required this.durationKey,
    required this.title,
    required this.description,
    required this.package,
    required this.selected,
    required this.onTap,
    this.badge,
    this.highlighted = false,
  });

  final String durationKey;
  final String title;
  final String description;
  final PackageDuration package;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;
  final bool highlighted;

  int get _discountPercent {
    final rate = MerchantPricingService.packageDiscountRate(package);
    return ((1 - rate) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return MerchantLiftCard(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [
                    PeeplMerchantTokens.accentGradientStart,
                    PeeplMerchantTokens.accentGradientEnd,
                  ],
                )
              : null,
          color: selected
              ? null
              : highlighted
                  ? PeeplMerchantTokens.cardElevated
                  : PeeplMerchantTokens.card,
          borderRadius: BorderRadius.circular(PeeplMerchantTokens.cardRadius),
          border: Border.all(
            color: selected
                ? PeeplMerchantTokens.accentBlue
                : highlighted
                    ? PeeplMerchantTokens.accentBlue.withValues(alpha: 0.45)
                    : PeeplMerchantTokens.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? PeeplMerchantTokens.premiumShadow : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: PeeplMerchantTokens.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.18)
                          : PeeplMerchantTokens.accentBlue.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: selected ? Colors.white : PeeplMerchantTokens.accentBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: PeeplMerchantTokens.success.withValues(alpha: selected ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_discountPercent% OFF',
                style: const TextStyle(
                  color: PeeplMerchantTokens.success,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                color: selected
                    ? Colors.white.withValues(alpha: 0.88)
                    : PeeplMerchantTokens.textSecondary,
                height: 1.45,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? Colors.white : PeeplMerchantTokens.textMuted,
                  size: PeeplMerchantTokens.iconMd,
                ),
                const SizedBox(width: 8),
                Text(
                  MerchantPricingService.packageLabel(package),
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : PeeplMerchantTokens.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MerchantPackageSelector extends StatelessWidget {
  const MerchantPackageSelector({
    super.key,
    required this.selectedDuration,
    required this.onChanged,
  });

  final String selectedDuration;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MerchantPackagePricingCard(
          durationKey: '1',
          title: 'Weekly',
          description: '5 recurring slots · ideal for recurring happy hours.',
          package: PackageDuration.weekly,
          selected: selectedDuration == '1',
          onTap: () => onChanged('1'),
        ),
        const SizedBox(height: 12),
        MerchantPackagePricingCard(
          durationKey: '3',
          title: 'Monthly',
          description: 'Best balance of reach and savings for steady promotions.',
          package: PackageDuration.monthly,
          selected: selectedDuration == '3',
          highlighted: true,
          badge: 'Recommended',
          onTap: () => onChanged('3'),
        ),
        const SizedBox(height: 12),
        MerchantPackagePricingCard(
          durationKey: '6',
          title: 'Quarterly',
          description: 'Maximum savings for merchants running ongoing campaigns.',
          package: PackageDuration.quarterly,
          selected: selectedDuration == '6',
          badge: 'Most Popular',
          onTap: () => onChanged('6'),
        ),
      ],
    );
  }
}
