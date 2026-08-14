import 'package:flutter/material.dart';

import 'detail_section_card.dart';
import 'peepl_detail_tokens.dart';

class DetailPeepCard extends StatelessWidget {
  const DetailPeepCard({
    super.key,
    required this.caption,
    required this.author,
    required this.timeLabel,
    required this.isLiked,
    required this.onLikeTap,
    this.photoUrl,
    this.onMenu,
  });

  final String caption;
  final String author;
  final String timeLabel;
  final bool isLiked;
  final VoidCallback onLikeTap;
  final String? photoUrl;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return DetailSectionCard(
      title: 'The Peep',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: PeeplDetailTokens.accentBlue,
                backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                    ? NetworkImage(photoUrl!)
                    : null,
                child: photoUrl == null || photoUrl!.isEmpty
                    ? Text(
                        author.isNotEmpty ? author[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      style: const TextStyle(
                        color: PeeplDetailTokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (timeLabel.isNotEmpty)
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          color: PeeplDetailTokens.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (onMenu != null)
                IconButton(
                  onPressed: onMenu,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: PeeplDetailTokens.textSecondary,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              caption,
              style: const TextStyle(
                color: PeeplDetailTokens.textPrimary,
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: onLikeTap,
                icon: Icon(
                  isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isLiked
                      ? const Color(0xFFFF4D6D)
                      : PeeplDetailTokens.textSecondary,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.reply_rounded,
                  color: PeeplDetailTokens.textSecondary,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
