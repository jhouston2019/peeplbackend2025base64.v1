import 'package:flutter/material.dart';

import '../../services/merchant_pricing_service.dart';
import 'peepl_merchant_tokens.dart';

class MerchantPriceSummary extends StatelessWidget {
  const MerchantPriceSummary({
    super.key,
    required this.quote,
    this.promotionTitle,
    this.dateLabel,
    this.timeLabel,
    this.radiusLabel,
    this.paymentMethodLabel,
    this.packageLabel,
    this.onLaunch,
    this.launchLabel = 'Launch Campaign',
    this.isLaunching = false,
  });

  final CampaignQuote quote;
  final String? promotionTitle;
  final String? dateLabel;
  final String? timeLabel;
  final String? radiusLabel;
  final String? paymentMethodLabel;
  final String? packageLabel;
  final VoidCallback? onLaunch;
  final String launchLabel;
  final bool isLaunching;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: PeeplMerchantTokens.gradientCardDecoration(),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Review & Pay',
            style: TextStyle(
              color: PeeplMerchantTokens.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Confirm your campaign before launch.',
            style: TextStyle(color: PeeplMerchantTokens.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
          if (promotionTitle != null)
            _SectionBlock(
              title: 'Promotion',
              child: Text(
                promotionTitle!,
                style: const TextStyle(
                  color: PeeplMerchantTokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          if (dateLabel != null || timeLabel != null)
            _SectionBlock(
              title: 'Schedule',
              child: Text(
                [dateLabel, timeLabel].whereType<String>().join(' · '),
                style: const TextStyle(
                  color: PeeplMerchantTokens.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (radiusLabel != null)
            _SectionBlock(title: 'Radius', child: _valueText(radiusLabel!)),
          if (packageLabel != null)
            _SectionBlock(title: 'Package', child: _valueText(packageLabel!)),
          _SectionBlock(
            title: 'Pricing',
            child: Column(
              children: [
                if (quote.isSubscription) ...[
                  _SummaryRow(
                    'Plan',
                    '${quote.subscriptionTier} · ${quote.subscriptionMonths} mo',
                  ),
                  _SummaryRow(
                    'Monthly rate',
                    MerchantPricingService.formatCurrency(
                      MerchantPricingService.subscriptionTiers[
                              quote.subscriptionTier?.toLowerCase() ?? 'standard'] ??
                          99,
                    ),
                  ),
                ] else if (quote.lineItems.isNotEmpty) ...[
                  _SummaryRow('Total hours', '${quote.hours}'),
                  _SummaryRow(
                    'Subtotal',
                    MerchantPricingService.formatCurrency(quote.subtotal),
                  ),
                  _SummaryRow(
                    'Avg hourly rate',
                    MerchantPricingService.formatCurrency(
                      quote.subtotal / quote.lineItems.length,
                    ),
                  ),
                ],
                if (quote.packageDiscountAmount > 0)
                  _SummaryRow(
                    quote.packageLabel,
                    '-${MerchantPricingService.formatCurrency(quote.packageDiscountAmount)}',
                    valueColor: PeeplMerchantTokens.success,
                  ),
                if (quote.tax > 0)
                  _SummaryRow('Taxes', MerchantPricingService.formatCurrency(quote.tax)),
              ],
            ),
          ),
          if (paymentMethodLabel != null)
            _SectionBlock(title: 'Payment Method', child: _valueText(paymentMethodLabel!)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: PeeplMerchantTokens.glassDecoration(radius: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Campaign Total',
                  style: TextStyle(
                    color: PeeplMerchantTokens.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  MerchantPricingService.formatCurrency(quote.total),
                  style: const TextStyle(
                    color: PeeplMerchantTokens.accentBlue,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
          if (onLaunch != null) ...[
            const SizedBox(height: 20),
            _LaunchButton(
              label: launchLabel,
              isLaunching: isLaunching,
              onTap: onLaunch!,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: PeeplMerchantTokens.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

Widget _valueText(String value) => Text(
      value,
      style: const TextStyle(
        color: PeeplMerchantTokens.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    );

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: PeeplMerchantTokens.textMuted,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? PeeplMerchantTokens.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LaunchButton extends StatelessWidget {
  const _LaunchButton({
    required this.label,
    required this.isLaunching,
    required this.onTap,
  });

  final String label;
  final bool isLaunching;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              PeeplMerchantTokens.accentGradientStart,
              PeeplMerchantTokens.accentGradientEnd,
            ],
          ),
          borderRadius: BorderRadius.circular(PeeplMerchantTokens.buttonRadius),
          boxShadow: PeeplMerchantTokens.premiumShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLaunching ? null : onTap,
            borderRadius: BorderRadius.circular(PeeplMerchantTokens.buttonRadius),
            child: Center(
              child: isLaunching
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
