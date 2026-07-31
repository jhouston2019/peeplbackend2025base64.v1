import 'package:flutter/material.dart';

import 'merchant_interactions.dart';
import 'peepl_merchant_tokens.dart';

enum MerchantEmptyStateVariant {
  noCampaigns,
  noAnalytics,
  noNotifications,
  noBilling,
  noPromotions,
  noTemplates,
}

class MerchantEmptyState extends StatelessWidget {
  const MerchantEmptyState({
    super.key,
    required this.variant,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final MerchantEmptyStateVariant variant;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final config = _configFor(variant);

    return MerchantFadeIn(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: PeeplMerchantTokens.glassDecoration(radius: PeeplMerchantTokens.cardRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Illustration(config: config),
            const SizedBox(height: 22),
            Text(
              config.title,
              textAlign: TextAlign.center,
              style: PeeplMerchantTokens.cardTitle(context),
            ),
            const SizedBox(height: 10),
            Text(
              config.message,
              textAlign: TextAlign.center,
              style: PeeplMerchantTokens.body(context),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              MerchantPrimaryButton(
                label: actionLabel!,
                icon: config.actionIcon,
                onTap: onAction!,
              ),
            ],
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: 12),
              MerchantSecondaryButton(
                label: secondaryActionLabel!,
                onTap: onSecondaryAction!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static _EmptyConfig _configFor(MerchantEmptyStateVariant variant) =>
      switch (variant) {
        MerchantEmptyStateVariant.noCampaigns => const _EmptyConfig(
            title: 'No Campaigns Yet',
            message:
                'Launch your first promotion to start reaching customers in your area.',
            icon: Icons.campaign_outlined,
            accent: PeeplMerchantTokens.accentBlue,
            actionIcon: Icons.add_rounded,
          ),
        MerchantEmptyStateVariant.noAnalytics => const _EmptyConfig(
            title: 'No Analytics Yet',
            message:
                'Performance data will appear here once your campaigns start running.',
            icon: Icons.insights_outlined,
            accent: Color(0xFF7C9CFF),
            actionIcon: Icons.add_rounded,
          ),
        MerchantEmptyStateVariant.noNotifications => const _EmptyConfig(
            title: 'No Notifications',
            message:
                'Campaign updates, billing alerts, and status changes will show up here.',
            icon: Icons.notifications_none_rounded,
            accent: PeeplMerchantTokens.textSecondary,
            actionIcon: Icons.refresh_rounded,
          ),
        MerchantEmptyStateVariant.noBilling => const _EmptyConfig(
            title: 'No Billing History',
            message:
                'Invoices and payment receipts will appear here after your first charge.',
            icon: Icons.receipt_long_outlined,
            accent: PeeplMerchantTokens.success,
            actionIcon: Icons.credit_card_rounded,
          ),
        MerchantEmptyStateVariant.noPromotions => const _EmptyConfig(
            title: 'No Active Promotion',
            message:
                'Create a promotion to fill seats, drive traffic, and grow repeat visits.',
            icon: Icons.local_offer_outlined,
            accent: PeeplMerchantTokens.warning,
            actionIcon: Icons.auto_awesome_rounded,
          ),
        MerchantEmptyStateVariant.noTemplates => const _EmptyConfig(
            title: 'No Saved Templates',
            message:
                'Save a campaign configuration after launch to reuse it next time.',
            icon: Icons.bookmark_border_rounded,
            accent: PeeplMerchantTokens.accentBlue,
            actionIcon: Icons.add_rounded,
          ),
      };
}

class _EmptyConfig {
  const _EmptyConfig({
    required this.title,
    required this.message,
    required this.icon,
    required this.accent,
    required this.actionIcon,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color accent;
  final IconData actionIcon;
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.config});

  final _EmptyConfig config;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  config.accent.withValues(alpha: 0.28),
                  config.accent.withValues(alpha: 0.04),
                ],
              ),
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: PeeplMerchantTokens.cardElevated,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: config.accent.withValues(alpha: 0.35)),
              boxShadow: PeeplMerchantTokens.premiumShadow,
            ),
            child: Icon(
              config.icon,
              size: PeeplMerchantTokens.iconXl,
              color: config.accent,
            ),
          ),
          Positioned(
            right: 8,
            bottom: 10,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: PeeplMerchantTokens.accentBlue,
                shape: BoxShape.circle,
                border: Border.all(color: PeeplMerchantTokens.background, width: 2),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
