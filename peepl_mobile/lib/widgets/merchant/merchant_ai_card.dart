import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'peepl_merchant_tokens.dart';

class MerchantAiCard extends StatelessWidget {
  const MerchantAiCard({
    super.key,
    this.title = 'Peepl AI',
    this.subtitle = 'Your campaign co-pilot',
    this.suggestions = const [],
    this.onGeneratePromotion,
    this.onImproveWording,
    this.onRecommendTimes,
    this.onRecommendPricing,
    this.onOptimize,
  });

  final String title;
  final String subtitle;
  final List<String> suggestions;
  final VoidCallback? onGeneratePromotion;
  final VoidCallback? onImproveWording;
  final VoidCallback? onRecommendTimes;
  final VoidCallback? onRecommendPricing;
  final VoidCallback? onOptimize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PeeplMerchantTokens.accentBlue.withValues(alpha: 0.22),
            PeeplMerchantTokens.cardElevated,
          ],
        ),
        borderRadius: BorderRadius.circular(PeeplMerchantTokens.cardRadius),
        border: Border.all(color: PeeplMerchantTokens.accentBlue.withValues(alpha: 0.35)),
        boxShadow: PeeplMerchantTokens.premiumShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      PeeplMerchantTokens.accentGradientStart,
                      PeeplMerchantTokens.accentGradientEnd,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: PeeplMerchantTokens.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: PeeplMerchantTokens.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onGeneratePromotion != null)
                _AiActionChip(
                  label: 'Generate promotion',
                  onTap: onGeneratePromotion!,
                ),
              if (onImproveWording != null)
                _AiActionChip(label: 'Improve wording', onTap: onImproveWording!),
              if (onRecommendTimes != null)
                _AiActionChip(label: 'Best times', onTap: onRecommendTimes!),
              if (onRecommendPricing != null)
                _AiActionChip(label: 'Pricing tips', onTap: onRecommendPricing!),
              if (onOptimize != null)
                _AiActionChip(label: 'Optimize', onTap: onOptimize!),
            ],
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...suggestions.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 16,
                      color: PeeplMerchantTokens.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s,
                        style: const TextStyle(
                          color: PeeplMerchantTokens.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AiActionChip extends StatelessWidget {
  const _AiActionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PeeplMerchantTokens.glassFill,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: const TextStyle(
              color: PeeplMerchantTokens.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
