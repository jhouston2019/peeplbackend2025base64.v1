import 'package:flutter/material.dart';

import 'peepl_merchant_tokens.dart';

enum MerchantNotificationType {
  campaignStarting,
  campaignPaused,
  campaignCompleted,
  slotFilling,
  peakPricing,
  campaignEnded,
  paymentSuccessful,
  paymentFailed,
  highEngagement,
  lowInventory,
  opportunity,
}

class MerchantNotificationCard extends StatelessWidget {
  const MerchantNotificationCard({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    this.timestamp,
    this.onTap,
    this.onDismiss,
  });

  final MerchantNotificationType type;
  final String title;
  final String message;
  final String? timestamp;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final accent = _accentForType(type);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PeeplMerchantTokens.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PeeplMerchantTokens.card,
            borderRadius: BorderRadius.circular(PeeplMerchantTokens.cardRadius),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconForType(type), color: accent, size: 22),
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
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        color: PeeplMerchantTokens.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    if (timestamp != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        timestamp!,
                        style: const TextStyle(
                          color: PeeplMerchantTokens.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: PeeplMerchantTokens.textMuted,
                  onPressed: onDismiss,
                  tooltip: 'Dismiss',
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _accentForType(MerchantNotificationType type) => switch (type) {
        MerchantNotificationType.campaignStarting => PeeplMerchantTokens.accentBlue,
        MerchantNotificationType.campaignPaused => PeeplMerchantTokens.warning,
        MerchantNotificationType.campaignCompleted => PeeplMerchantTokens.success,
        MerchantNotificationType.slotFilling => PeeplMerchantTokens.warning,
        MerchantNotificationType.peakPricing => const Color(0xFFFF9F43),
        MerchantNotificationType.campaignEnded => PeeplMerchantTokens.textMuted,
        MerchantNotificationType.paymentSuccessful => PeeplMerchantTokens.success,
        MerchantNotificationType.paymentFailed => PeeplMerchantTokens.danger,
        MerchantNotificationType.highEngagement => PeeplMerchantTokens.success,
        MerchantNotificationType.lowInventory => PeeplMerchantTokens.warning,
        MerchantNotificationType.opportunity => PeeplMerchantTokens.accentBlue,
      };

  static IconData _iconForType(MerchantNotificationType type) => switch (type) {
        MerchantNotificationType.campaignStarting => Icons.play_circle_outline_rounded,
        MerchantNotificationType.campaignPaused => Icons.pause_circle_outline_rounded,
        MerchantNotificationType.campaignCompleted => Icons.check_circle_outline_rounded,
        MerchantNotificationType.slotFilling => Icons.hourglass_top_rounded,
        MerchantNotificationType.peakPricing => Icons.trending_up_rounded,
        MerchantNotificationType.campaignEnded => Icons.flag_rounded,
        MerchantNotificationType.paymentSuccessful => Icons.check_circle_outline_rounded,
        MerchantNotificationType.paymentFailed => Icons.error_outline_rounded,
        MerchantNotificationType.highEngagement => Icons.bolt_rounded,
        MerchantNotificationType.lowInventory => Icons.inventory_2_outlined,
        MerchantNotificationType.opportunity => Icons.auto_awesome_rounded,
      };
}
