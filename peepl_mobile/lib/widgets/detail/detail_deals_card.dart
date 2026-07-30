import 'package:flutter/material.dart';

import 'peepl_detail_tokens.dart';

class DetailDealsCard extends StatelessWidget {
  const DetailDealsCard({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PeeplDetailTokens.cardRadius),
          child: Ink(
            decoration: PeeplDetailTokens.cardDecoration(
              color: const Color(0xFF0F2E1F),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF66E38D).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_offer_outlined,
                      color: Color(0xFF66E38D),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deals Available',
                          style: TextStyle(
                            color: PeeplDetailTokens.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tap to view nearby offers',
                          style: TextStyle(
                            color: PeeplDetailTokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: PeeplDetailTokens.textSecondary.withValues(alpha: 0.8),
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
