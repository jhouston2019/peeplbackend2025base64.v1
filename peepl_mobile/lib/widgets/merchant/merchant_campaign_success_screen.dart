import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'merchant_interactions.dart';
import 'peepl_merchant_tokens.dart';

class MerchantCampaignSuccessScreen extends StatefulWidget {
  const MerchantCampaignSuccessScreen({
    super.key,
    required this.campaignTitle,
    this.scheduleLabel,
    this.radiusLabel,
    this.packageLabel,
    this.onViewCampaign,
    required this.onCreateAnother,
    required this.onReturnDashboard,
  });

  final String campaignTitle;
  final String? scheduleLabel;
  final String? radiusLabel;
  final String? packageLabel;
  final VoidCallback? onViewCampaign;
  final VoidCallback onCreateAnother;
  final VoidCallback onReturnDashboard;

  @override
  State<MerchantCampaignSuccessScreen> createState() =>
      _MerchantCampaignSuccessScreenState();
}

class _MerchantCampaignSuccessScreenState
    extends State<MerchantCampaignSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplMerchantTokens.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _controller,
                          curve: const Interval(0, 0.55, curve: Curves.elasticOut),
                        ),
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                PeeplMerchantTokens.success.withValues(alpha: 0.25),
                                PeeplMerchantTokens.accentBlue.withValues(alpha: 0.18),
                              ],
                            ),
                            border: Border.all(
                              color: PeeplMerchantTokens.success.withValues(alpha: 0.45),
                            ),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: PeeplMerchantTokens.success,
                            size: 52,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      MerchantFadeIn(
                        delay: const Duration(milliseconds: 180),
                        child: Text(
                          'Campaign Scheduled',
                          style: PeeplMerchantTokens.heroTitle(context),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                      MerchantFadeIn(
                        delay: const Duration(milliseconds: 260),
                        child: Text(
                          'Your promotion was submitted for review. We\'ll notify you when it goes live.',
                          textAlign: TextAlign.center,
                          style: PeeplMerchantTokens.body(context),
                        ),
                      ),
                      const SizedBox(height: 28),
                      MerchantFadeIn(
                        delay: const Duration(milliseconds: 340),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: PeeplMerchantTokens.gradientCardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Summary',
                                style: PeeplMerchantTokens.sectionTitle(context),
                              ),
                              const SizedBox(height: 16),
                              _SummaryRow('Promotion', widget.campaignTitle),
                              if (widget.scheduleLabel != null)
                                _SummaryRow('Schedule', widget.scheduleLabel!),
                              if (widget.radiusLabel != null)
                                _SummaryRow('Radius', widget.radiusLabel!),
                              if (widget.packageLabel != null)
                                _SummaryRow('Package', widget.packageLabel!),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              MerchantFadeIn(
                delay: const Duration(milliseconds: 420),
                child: Column(
                  children: [
                    if (widget.onViewCampaign != null) ...[
                      MerchantPrimaryButton(
                        label: 'View Campaign',
                        icon: Icons.visibility_rounded,
                        onTap: widget.onViewCampaign!,
                      ),
                      const SizedBox(height: 12),
                    ],
                    MerchantSecondaryButton(
                      label: 'Create Another',
                      icon: Icons.add_rounded,
                      onTap: widget.onCreateAnother,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: widget.onReturnDashboard,
                      child: const Text(
                        'Return to Dashboard',
                        style: TextStyle(
                          color: PeeplMerchantTokens.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: PeeplMerchantTokens.caption(context),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: PeeplMerchantTokens.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
