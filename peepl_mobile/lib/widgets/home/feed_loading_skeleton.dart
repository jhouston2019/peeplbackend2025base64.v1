import 'package:flutter/material.dart';

import 'peepl_home_tokens.dart';

/// Editorial feed skeleton shown while feed data loads.
class FeedLoadingSkeleton extends StatelessWidget {
  const FeedLoadingSkeleton({super.key});

  static const _rowPattern = [
    _SkeletonRowKind.featured,
    _SkeletonRowKind.halfPair,
    _SkeletonRowKind.featured,
    _SkeletonRowKind.halfPair,
    _SkeletonRowKind.featured,
    _SkeletonRowKind.sponsored,
    _SkeletonRowKind.featured,
    _SkeletonRowKind.halfPair,
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      itemCount: _rowPattern.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: index < _rowPattern.length - 1
                ? PeeplHomeTokens.rowVerticalGap
                : 0,
          ),
          child: _SkeletonRow(kind: _rowPattern[index]),
        );
      },
    );
  }
}

enum _SkeletonRowKind { featured, halfPair, sponsored }

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.kind});

  final _SkeletonRowKind kind;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case _SkeletonRowKind.featured:
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PeeplHomeTokens.cardHorizontalMargin,
          ),
          child: _SkeletonCard(height: PeeplHomeTokens.featuredCardHeight),
        );
      case _SkeletonRowKind.halfPair:
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PeeplHomeTokens.cardHorizontalMargin,
          ),
          child: Row(
            children: [
              Expanded(
                child: _SkeletonCard(height: PeeplHomeTokens.halfCardHeight),
              ),
              const SizedBox(width: PeeplHomeTokens.halfCardGap),
              Expanded(
                child: _SkeletonCard(height: PeeplHomeTokens.halfCardHeight),
              ),
            ],
          ),
        );
      case _SkeletonRowKind.sponsored:
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PeeplHomeTokens.cardHorizontalMargin,
          ),
          child: _SkeletonCard(
            height: PeeplHomeTokens.sponsoredCardHeight,
            sponsored: true,
          ),
        );
    }
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({
    required this.height,
    this.sponsored = false,
  });

  final double height;
  final bool sponsored;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: PeeplHomeTokens.skeletonSurface,
        borderRadius: BorderRadius.circular(PeeplHomeTokens.cardRadius),
        border: sponsored
            ? Border.all(
                color: PeeplHomeTokens.sponsoredBorder,
                width: PeeplHomeTokens.sponsoredBorderWidth,
              )
            : null,
        boxShadow: sponsored ? null : const [
          PeeplHomeTokens.organicShadow,
          PeeplHomeTokens.organicWhiteShadowRight,
          PeeplHomeTokens.organicWhiteShadowBottom,
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: height * 0.34,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _SkeletonBlock(width: 34, height: 12),
                SizedBox(height: 4),
                _SkeletonBlock(width: 28, height: 6),
                SizedBox(height: 5),
                _SkeletonBlock(width: 40, height: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (sponsored) const _SkeletonBlock(width: 52, height: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBlock(width: double.infinity, height: 8),
                    SizedBox(height: 5),
                    _SkeletonBlock(width: 72, height: 6),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: PeeplHomeTokens.skeletonHighlight,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}
