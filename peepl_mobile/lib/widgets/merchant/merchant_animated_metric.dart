import 'package:flutter/material.dart';

import 'merchant_metric_card.dart';
import 'peepl_merchant_tokens.dart';

/// Metric card that animates numeric values on first paint.
class MerchantAnimatedMetric extends StatefulWidget {
  const MerchantAnimatedMetric({
    super.key,
    required this.label,
    this.numericValue,
    this.displayValue,
    this.icon,
    this.delay = Duration.zero,
  }) : assert(numericValue != null || displayValue != null);

  final String label;
  final num? numericValue;
  final String? displayValue;
  final IconData? icon;
  final Duration delay;

  @override
  State<MerchantAnimatedMetric> createState() => _MerchantAnimatedMetricState();
}

class _MerchantAnimatedMetricState extends State<MerchantAnimatedMetric>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _tween;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final target = (widget.numericValue ?? 0).toDouble();
    _tween = Tween<double>(begin: 0, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(MerchantAnimatedMetric oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.numericValue != widget.numericValue &&
        widget.numericValue != null) {
      _tween = Tween<double>(
        begin: _tween.value,
        end: widget.numericValue!.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatAnimated(double v) {
    if (widget.displayValue != null) return widget.displayValue!;
    if (widget.label.toLowerCase().contains('ctr') ||
        widget.label.contains('%')) {
      return merchantFormatPercent(v);
    }
    if (widget.label.toLowerCase().contains('spend') ||
        v.toString().contains('.')) {
      return merchantFormatCurrency(v);
    }
    return merchantFormatCount(v.round());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.displayValue != null) {
      return MerchantMetricCard(
        label: widget.label,
        value: widget.displayValue!,
        icon: widget.icon,
      );
    }

    return AnimatedBuilder(
      animation: _tween,
      builder: (context, _) {
        return MerchantMetricCard(
          label: widget.label,
          value: _formatAnimated(_tween.value),
          icon: widget.icon,
          animate: false,
        );
      },
    );
  }
}

class MerchantMetricSkeleton extends StatelessWidget {
  const MerchantMetricSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: PeeplMerchantTokens.glassDecoration(),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: PeeplMerchantTokens.accentBlue,
        ),
      ),
    );
  }
}
