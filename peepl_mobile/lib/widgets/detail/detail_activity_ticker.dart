import 'package:flutter/material.dart';

import 'peepl_detail_tokens.dart';

class DetailActivityTicker extends StatelessWidget {
  const DetailActivityTicker({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: PeeplDetailTokens.cardDecoration(
        color: PeeplDetailTokens.cardElevated,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF66E38D),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Color(0xFF66E38D),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PeeplDetailTokens.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
