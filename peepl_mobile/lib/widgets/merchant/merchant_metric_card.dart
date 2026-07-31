import 'package:flutter/material.dart';

import 'peepl_merchant_tokens.dart';

class MerchantMetricCard extends StatefulWidget {
  const MerchantMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.trend,
    this.trendUp,
    this.animate = true,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? trend;
  final bool? trendUp;
  final bool animate;
  final VoidCallback? onTap;

  @override
  State<MerchantMetricCard> createState() => _MerchantMetricCardState();
}

class _MerchantMetricCardState extends State<MerchantMetricCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    if (widget.animate) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = PeeplMerchantTokens.blurredBackdrop(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: PeeplMerchantTokens.glassDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                color: PeeplMerchantTokens.accentBlue,
                size: 20,
                semanticLabel: widget.label,
              ),
              const SizedBox(height: 12),
            ],
            Text(
              widget.value,
              style: PeeplMerchantTokens.metricValue(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: PeeplMerchantTokens.metricLabel(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.trend != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    widget.trendUp == true
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 14,
                    color: widget.trendUp == true
                        ? PeeplMerchantTokens.success
                        : PeeplMerchantTokens.danger,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.trend!,
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.trendUp == true
                            ? PeeplMerchantTokens.success
                            : PeeplMerchantTokens.danger,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    final content = widget.animate
        ? FadeTransition(
            opacity: _fade,
            child: SlideTransition(position: _slide, child: card),
          )
        : card;

    if (widget.onTap == null) return content;

    return Semantics(
      button: true,
      label: '${widget.label}: ${widget.value}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(PeeplMerchantTokens.cardRadius),
          child: content,
        ),
      ),
    );
  }
}

String merchantFormatCount(num value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}

String merchantFormatCurrency(num value) =>
    '\$${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}';

String merchantFormatPercent(double value) => '${value.toStringAsFixed(1)}%';
