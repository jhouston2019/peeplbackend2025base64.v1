import 'package:flutter/material.dart';

import 'peepl_detail_tokens.dart';

class DetailCommentTile extends StatelessWidget {
  const DetailCommentTile({
    super.key,
    required this.username,
    required this.text,
    required this.timeLabel,
  });

  final String username;
  final String text;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: PeeplDetailTokens.cardDecoration(
          color: PeeplDetailTokens.cardElevated.withValues(alpha: 0.65),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: PeeplDetailTokens.accentBlue,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: PeeplDetailTokens.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          username,
                          style: const TextStyle(
                            color: PeeplDetailTokens.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (timeLabel.isNotEmpty)
                        Text(
                          timeLabel,
                          style: const TextStyle(
                            color: PeeplDetailTokens.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 14,
                      color: PeeplDetailTokens.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
