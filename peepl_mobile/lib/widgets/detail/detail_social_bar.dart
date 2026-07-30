import 'package:flutter/material.dart';

import 'peepl_detail_tokens.dart';

class DetailSocialBar extends StatelessWidget {
  const DetailSocialBar({
    super.key,
    required this.isLiked,
    required this.likesCount,
    required this.commentsCount,
    required this.onLikeTap,
    required this.onLikesCountTap,
    required this.onShareTap,
    required this.onReportTap,
  });

  final bool isLiked;
  final int likesCount;
  final int commentsCount;
  final VoidCallback onLikeTap;
  final VoidCallback onLikesCountTap;
  final VoidCallback onShareTap;
  final VoidCallback onReportTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: PeeplDetailTokens.cardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ActionButton(
            icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            label: '$likesCount',
            color: isLiked ? const Color(0xFFFF4D6D) : PeeplDetailTokens.textSecondary,
            onTap: onLikeTap,
            onLabelTap: onLikesCountTap,
          ),
          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: '$commentsCount',
            color: PeeplDetailTokens.textSecondary,
            onTap: () {},
          ),
          _ActionButton(
            icon: Icons.ios_share_rounded,
            label: 'Share',
            color: PeeplDetailTokens.textSecondary,
            onTap: onShareTap,
          ),
          _ActionButton(
            icon: Icons.flag_outlined,
            label: 'Report',
            color: PeeplDetailTokens.textSecondary,
            onTap: onReportTap,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.onLabelTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLabelTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onLabelTap ?? onTap,
                child: Text(
                  label,
                  style: TextStyle(
                    color: PeeplDetailTokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: onLabelTap != null ? TextDecoration.underline : null,
                    decorationColor: PeeplDetailTokens.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
