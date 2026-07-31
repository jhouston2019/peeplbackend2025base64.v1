import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'merchant_interactions.dart';
import 'merchant_metric_card.dart';
import 'peepl_merchant_tokens.dart';

class MerchantCampaignCard extends StatelessWidget {
  const MerchantCampaignCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.dateLabel,
    this.isLive = false,
    this.timeRemaining,
    this.spend,
    this.views,
    this.clicks,
    this.ctr,
    this.costPerView,
    this.radius,
    this.compact = false,
    this.onPause,
    this.onResume,
    this.onDuplicate,
    this.onEdit,
    this.onEnd,
    this.onDetails,
  });

  final String title;
  final String? imageUrl;
  final String? dateLabel;
  final bool isLive;
  final String? timeRemaining;
  final String? spend;
  final int? views;
  final int? clicks;
  final double? ctr;
  final String? costPerView;
  final String? radius;
  final bool compact;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onDuplicate;
  final VoidCallback? onEdit;
  final VoidCallback? onEnd;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    return MerchantLiftCard(
      child: Container(
        decoration: PeeplMerchantTokens.gradientCardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: compact ? 16 / 7 : 16 / 8,
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          cacheWidth: 800,
                          errorBuilder: (_, __, ___) => _imageFallback(),
                        )
                      : _imageFallback(),
                ),
                if (isLive)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _LiveBadge(timeRemaining: timeRemaining),
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 14 : 16, compact ? 12 : 14, compact ? 14 : 16, compact ? 14 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: PeeplMerchantTokens.textPrimary,
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (dateLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(dateLabel!, style: PeeplMerchantTokens.caption(context)),
                  ],
                  if (spend != null || views != null || ctr != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (spend != null) _MetricPill(label: 'Spend', value: spend!),
                        if (views != null)
                          _MetricPill(
                            label: 'Views',
                            value: merchantFormatCount(views!),
                          ),
                        if (clicks != null && !compact)
                          _MetricPill(
                            label: 'Clicks',
                            value: merchantFormatCount(clicks!),
                          ),
                        if (ctr != null)
                          _MetricPill(
                            label: 'CTR',
                            value: merchantFormatPercent(ctr!),
                          ),
                        if (!compact && costPerView != null)
                          _MetricPill(label: 'CPV', value: costPerView!),
                        if (!compact && radius != null)
                          _MetricPill(label: 'Radius', value: radius!),
                      ],
                    ),
                  ],
                  if (!compact) ...[
                    const SizedBox(height: 14),
                    _ActionRow(
                      isLive: isLive,
                      onPause: onPause,
                      onResume: onResume,
                      onDuplicate: onDuplicate,
                      onEdit: onEdit,
                      onDetails: onDetails,
                    ),
                  ] else if (onDuplicate != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _ActionButton(
                        label: 'Duplicate',
                        icon: Icons.copy_rounded,
                        onTap: onDuplicate!,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() => Container(
        color: PeeplMerchantTokens.cardElevated,
        child: const Center(
          child: Icon(
            Icons.campaign_outlined,
            color: PeeplMerchantTokens.textMuted,
            size: 44,
          ),
        ),
      );
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({this.timeRemaining});

  final String? timeRemaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PeeplMerchantTokens.liveGreen.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: PeeplMerchantTokens.liveGreen.withValues(alpha: 0.35),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            timeRemaining != null ? 'LIVE · $timeRemaining' : 'LIVE',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: PeeplMerchantTokens.glassFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PeeplMerchantTokens.glassBorder),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: PeeplMerchantTokens.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.isLive,
    this.onPause,
    this.onResume,
    this.onDuplicate,
    this.onEdit,
    this.onDetails,
  });

  final bool isLive;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onDuplicate;
  final VoidCallback? onEdit;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (isLive && onPause != null)
          _ActionButton(label: 'Pause', icon: Icons.pause_rounded, onTap: onPause!),
        if (!isLive && onResume != null)
          _ActionButton(label: 'Resume', icon: Icons.play_arrow_rounded, onTap: onResume!),
        if (onDuplicate != null)
          _ActionButton(label: 'Duplicate', icon: Icons.copy_rounded, onTap: onDuplicate!),
        if (onEdit != null)
          _ActionButton(label: 'Edit', icon: Icons.edit_rounded, onTap: onEdit!),
        if (onDetails != null)
          _ActionButton(label: 'Details', icon: Icons.insights_rounded, onTap: onDetails!),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MerchantScaleButton(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: PeeplMerchantTokens.accentBlue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PeeplMerchantTokens.accentBlue.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: PeeplMerchantTokens.iconSm, color: PeeplMerchantTokens.accentBlue),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: PeeplMerchantTokens.accentBlue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
