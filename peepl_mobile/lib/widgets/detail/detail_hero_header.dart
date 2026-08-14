import 'package:flutter/material.dart';

import 'detail_glass_icon_button.dart';
import 'peepl_detail_tokens.dart';

class DetailHeroHeader extends StatelessWidget {
  const DetailHeroHeader({
    super.key,
    required this.imageUrl,
    required this.locationName,
    required this.venueType,
    required this.locationSubtitle,
    required this.onBack,
    required this.onShare,
    required this.onMenu,
    this.onFollow,
    this.isFollowing = false,
    this.isFollowLoading = false,
  });

  final String? imageUrl;
  final String locationName;
  final String? venueType;
  final String? locationSubtitle;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onMenu;
  final VoidCallback? onFollow;
  final bool isFollowing;
  final bool isFollowLoading;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final heroHeight = PeeplDetailTokens.heroHeightFor(context);

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildImage(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.12),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.72),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          Positioned(
            top: topPadding + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                DetailGlassIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBack,
                ),
                const Spacer(),
                DetailGlassIconButton(
                  icon: Icons.ios_share_rounded,
                  onTap: onShare,
                  tooltip: 'Share',
                ),
                if (onFollow != null) ...[
                  const SizedBox(width: 8),
                  DetailGlassIconButton(
                    icon: isFollowLoading
                        ? Icons.hourglass_empty_rounded
                        : (isFollowing
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded),
                    onTap: isFollowLoading ? () {} : onFollow!,
                    tooltip:
                        isFollowing ? 'Unfollow location' : 'Follow location',
                  ),
                ],
                const SizedBox(width: 8),
                DetailGlassIconButton(
                  icon: Icons.more_horiz_rounded,
                  onTap: onMenu,
                  tooltip: 'More',
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locationName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.5,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 6,
                        color: Colors.black45,
                      ),
                    ],
                  ),
                ),
                if (_identityLine != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _identityLine!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 4,
                          color: Colors.black38,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? get _identityLine {
    final type = venueType?.trim();
    final subtitle = locationSubtitle?.trim();
    if (type != null && type.isNotEmpty && subtitle != null && subtitle.isNotEmpty) {
      return '$type • $subtitle';
    }
    if (type != null && type.isNotEmpty) return type;
    if (subtitle != null && subtitle.isNotEmpty) return subtitle;
    return null;
  }

  Widget _buildImage() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: PeeplDetailTokens.textPrimary.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 72,
          color: PeeplDetailTokens.textSecondary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
