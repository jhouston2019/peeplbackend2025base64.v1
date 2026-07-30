import 'package:flutter/material.dart';

import 'peepl_home_tokens.dart';

class FeedCardImage extends StatelessWidget {
  const FeedCardImage({
    super.key,
    required this.source,
    this.alignment = const Alignment(0, 0.35),
  });

  final String source;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (source.isEmpty) {
      return const ColoredBox(color: PeeplHomeTokens.cardFallback);
    }
    if (source.startsWith('assets/')) {
      return Image.asset(
        source,
        fit: BoxFit.cover,
        alignment: alignment,
        errorBuilder: (_, __, ___) =>
            const ColoredBox(color: PeeplHomeTokens.cardFallback),
      );
    }
    return Image.network(
      source,
      fit: BoxFit.cover,
      alignment: alignment,
      errorBuilder: (_, __, ___) =>
          const ColoredBox(color: PeeplHomeTokens.cardFallback),
    );
  }
}
