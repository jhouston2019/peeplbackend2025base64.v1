import 'package:flutter/material.dart';

import 'detail_section_card.dart';
import 'peepl_detail_tokens.dart';

class DetailPeepCard extends StatelessWidget {
  const DetailPeepCard({
    super.key,
    required this.imageUrl,
    required this.caption,
    required this.author,
    required this.timeLabel,
    required this.isLiked,
    required this.onLikeTap,
  });

  final String? imageUrl;
  final String caption;
  final String author;
  final String timeLabel;
  final bool isLiked;
  final VoidCallback onLikeTap;

  @override
  Widget build(BuildContext context) {
    return DetailSectionCard(
      title: 'Latest Peep',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: PeeplDetailTokens.cardElevated,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_outlined,
                      color: PeeplDetailTokens.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          if (imageUrl != null && imageUrl!.isNotEmpty) const SizedBox(height: 12),
          if (caption.isNotEmpty)
            Text(
              caption,
              style: const TextStyle(
                color: PeeplDetailTokens.textPrimary,
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (caption.isNotEmpty) const SizedBox(height: 12),
          Row(
            children: [
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
              IconButton(
                onPressed: onLikeTap,
                icon: Icon(
                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isLiked ? const Color(0xFFFF4D6D) : PeeplDetailTokens.textSecondary,
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.reply_rounded,
                  color: PeeplDetailTokens.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
