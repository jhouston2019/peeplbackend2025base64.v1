import 'package:flutter/material.dart';

import 'peepl_home_tokens.dart';

class HappeningNowTicker extends StatelessWidget {
  const HappeningNowTicker({
    super.key,
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: PeeplHomeTokens.tickerBackground,
          child: SizedBox(
            height: 30,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_offer_outlined,
                    color: PeeplHomeTokens.dealsGreen,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'CURRENT DEALS',
                    style: TextStyle(
                      color: PeeplHomeTokens.dealsGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PeeplHomeTokens.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: PeeplHomeTokens.white.withValues(alpha: 0.7),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
