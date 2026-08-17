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
    this.isOwner = false,
    this.onDeleteTap,
  });

  final bool isLiked;
  final int likesCount;
  final int commentsCount;
  final VoidCallback onLikeTap;
  final VoidCallback onLikesCountTap;
  final VoidCallback onShareTap;
  final VoidCallback onReportTap;
  final bool isOwner;
  final VoidCallback? onDeleteTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: PeeplDetailTokens.cardDecoration(),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _ActionCell(
                icon: isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: '$likesCount',
                color: isLiked
                    ? const Color(0xFFFF4D6D)
                    : PeeplDetailTokens.textSecondary,
                onTap: onLikeTap,
                onLabelTap: onLikesCountTap,
              ),
            ),
            _separator(),
            Expanded(
              child: _ActionCell(
                icon: Icons.chat_bubble_outline_rounded,
                label: '$commentsCount',
                color: PeeplDetailTokens.textSecondary,
                onTap: () {},
              ),
            ),
            _separator(),
            Expanded(
              child: _ActionCell(
                icon: Icons.ios_share_rounded,
                label: 'Share',
                color: PeeplDetailTokens.textSecondary,
                onTap: onShareTap,
              ),
            ),
            _separator(),
            Expanded(
              child: _ActionCell(
                icon: isOwner ? Icons.delete_outline : Icons.flag_outlined,
                label: isOwner ? 'Delete' : 'Report',
                color: isOwner
                    ? const Color(0xFFFF4D6D)
                    : PeeplDetailTokens.textSecondary,
                onTap: isOwner ? (onDeleteTap ?? () {}) : onReportTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _separator() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: PeeplDetailTokens.border,
    );
  }
}

class _ActionCell extends StatelessWidget {
  const _ActionCell({
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onLabelTap ?? onTap,
                child: Text(
                  label,
                  style: TextStyle(
                    color: PeeplDetailTokens.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration:
                        onLabelTap != null ? TextDecoration.underline : null,
                    decorationColor:
                        PeeplDetailTokens.textSecondary.withValues(alpha: 0.4),
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
