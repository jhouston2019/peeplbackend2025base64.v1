import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'merchant_empty_state.dart';
import 'merchant_interactions.dart';
import 'peepl_merchant_tokens.dart';

class MerchantLiveStatusCard extends StatelessWidget {
  const MerchantLiveStatusCard({
    super.key,
    this.isLive = false,
    this.campaignTitle,
    this.timeRange,
    this.timeRemaining,
    this.onPause,
    this.onViewDetails,
    this.onCreate,
  });

  final bool isLive;
  final String? campaignTitle;
  final String? timeRange;
  final String? timeRemaining;
  final VoidCallback? onPause;
  final VoidCallback? onViewDetails;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    if (!isLive) {
      return MerchantEmptyState(
        variant: MerchantEmptyStateVariant.noPromotions,
        actionLabel: 'Create Promotion',
        onAction: onCreate,
      );
    }

    return MerchantFadeIn(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PeeplMerchantTokens.liveGreen.withValues(alpha: 0.18),
              PeeplMerchantTokens.cardElevated,
            ],
          ),
          borderRadius: BorderRadius.circular(PeeplMerchantTokens.cardRadius),
          border: Border.all(
            color: PeeplMerchantTokens.liveGreen.withValues(alpha: 0.45),
          ),
          boxShadow: PeeplMerchantTokens.premiumShadow,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PulsingLiveDot(color: PeeplMerchantTokens.liveGreen),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: PeeplMerchantTokens.liveGreen.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: PeeplMerchantTokens.liveGreen.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: PeeplMerchantTokens.liveGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const Spacer(),
                if (timeRemaining != null)
                  _PremiumPill(label: timeRemaining!, icon: Icons.schedule_rounded),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              campaignTitle ?? 'Active Campaign',
              style: PeeplMerchantTokens.cardTitle(context),
            ),
            if (timeRange != null) ...[
              const SizedBox(height: 6),
              Text(
                timeRange!,
                style: PeeplMerchantTokens.body(context),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                if (onPause != null)
                  Expanded(
                    child: MerchantSecondaryButton(
                      label: 'Pause',
                      icon: Icons.pause_rounded,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        onPause!();
                      },
                    ),
                  ),
                if (onPause != null && onViewDetails != null) const SizedBox(width: 10),
                if (onViewDetails != null)
                  Expanded(
                    child: MerchantPrimaryButton(
                      label: 'View Details',
                      icon: Icons.visibility_rounded,
                      onTap: onViewDetails!,
                      expanded: true,
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

class _PremiumPill extends StatelessWidget {
  const _PremiumPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: PeeplMerchantTokens.glassDecoration(radius: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: PeeplMerchantTokens.iconSm, color: PeeplMerchantTokens.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: PeeplMerchantTokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingLiveDot extends StatefulWidget {
  const _PulsingLiveDot({required this.color});

  final Color color;

  @override
  State<_PulsingLiveDot> createState() => _PulsingLiveDotState();
}

class _PulsingLiveDotState extends State<_PulsingLiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.35 + _controller.value * 0.35),
                blurRadius: 6 + _controller.value * 6,
              ),
            ],
          ),
        );
      },
    );
  }
}
