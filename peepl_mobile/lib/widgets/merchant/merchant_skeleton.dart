import 'package:flutter/material.dart';

import 'peepl_merchant_tokens.dart';

class MerchantDashboardSkeleton extends StatelessWidget {
  const MerchantDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(PeeplMerchantTokens.pagePadding),
      children: const [
        MerchantSkeletonBox(height: 180, radius: PeeplMerchantTokens.cardRadius),
        SizedBox(height: 16),
        MerchantSkeletonBox(height: 140, radius: PeeplMerchantTokens.cardRadius),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: MerchantSkeletonBox(height: 92)),
            SizedBox(width: 12),
            Expanded(child: MerchantSkeletonBox(height: 92)),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: MerchantSkeletonBox(height: 92)),
            SizedBox(width: 12),
            Expanded(child: MerchantSkeletonBox(height: 92)),
          ],
        ),
        SizedBox(height: 24),
        MerchantSkeletonBox(height: 220, radius: PeeplMerchantTokens.cardRadius),
      ],
    );
  }
}

class MerchantSkeletonBox extends StatefulWidget {
  const MerchantSkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.radius = 16,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<MerchantSkeletonBox> createState() => _MerchantSkeletonBoxState();
}

class _MerchantSkeletonBoxState extends State<MerchantSkeletonBox>
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
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                PeeplMerchantTokens.glassFill,
                PeeplMerchantTokens.cardElevated.withValues(
                  alpha: 0.35 + _controller.value * 0.25,
                ),
                PeeplMerchantTokens.glassFill,
              ],
            ),
            border: Border.all(color: PeeplMerchantTokens.glassBorder),
          ),
        );
      },
    );
  }
}
