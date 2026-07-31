import 'package:flutter/material.dart';

import 'peepl_merchant_tokens.dart';

class MerchantCampaignStepper extends StatelessWidget {
  const MerchantCampaignStepper({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.labels = const [],
  });

  final int currentStep;
  final int totalSteps;
  final List<String> labels;

  static const defaultLabels = [
    'Type',
    'Offer',
    'Schedule',
    'Audience',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    final stepLabels = labels.isNotEmpty ? labels : defaultLabels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Step $currentStep of $totalSteps',
          style: const TextStyle(
            color: PeeplMerchantTokens.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(totalSteps, (i) {
            final step = i + 1;
            final active = step <= currentStep;
            final isCurrent = step == currentStep;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  height: isCurrent ? 6 : 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: active
                        ? const LinearGradient(
                            colors: [
                              PeeplMerchantTokens.accentGradientStart,
                              PeeplMerchantTokens.accentGradientEnd,
                            ],
                          )
                        : null,
                    color: active ? null : PeeplMerchantTokens.glassFill,
                    boxShadow: isCurrent ? PeeplMerchantTokens.premiumShadow : null,
                  ),
                ),
              ),
            );
          }),
        ),
        if (stepLabels.length >= currentStep) ...[
          const SizedBox(height: 10),
          Text(
            stepLabels[currentStep - 1],
            style: const TextStyle(
              color: PeeplMerchantTokens.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class MerchantWizardNav extends StatelessWidget {
  const MerchantWizardNav({
    super.key,
    this.onBack,
    required this.onContinue,
    this.continueLabel = 'Continue',
    this.canContinue = true,
    this.isLoading = false,
    this.showContinue = true,
  });

  final VoidCallback? onBack;
  final VoidCallback onContinue;
  final String continueLabel;
  final bool canContinue;
  final bool isLoading;
  final bool showContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Row(
        children: [
          if (onBack != null)
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading ? null : onBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor: PeeplMerchantTokens.textPrimary,
                  side: const BorderSide(color: PeeplMerchantTokens.glassBorder),
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
          if (onBack != null) const SizedBox(width: 12),
          if (showContinue)
            Expanded(
              flex: onBack != null ? 2 : 1,
              child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: canContinue
                    ? const LinearGradient(
                        colors: [
                          PeeplMerchantTokens.accentGradientStart,
                          PeeplMerchantTokens.accentGradientEnd,
                        ],
                      )
                    : null,
                color: canContinue ? null : PeeplMerchantTokens.glassFill,
                borderRadius: BorderRadius.circular(16),
                boxShadow: canContinue ? PeeplMerchantTokens.premiumShadow : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canContinue && !isLoading ? onContinue : null,
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 52,
                    child: Center(
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              continueLabel,
                              style: TextStyle(
                                color: canContinue
                                    ? Colors.white
                                    : PeeplMerchantTokens.textMuted,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
