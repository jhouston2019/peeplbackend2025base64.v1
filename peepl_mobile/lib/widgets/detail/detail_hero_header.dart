import 'package:flutter/material.dart';

import 'detail_glass_icon_button.dart';
import 'peepl_detail_tokens.dart';

class DetailHeroHeader extends StatelessWidget {
  const DetailHeroHeader({
    super.key,
    required this.imageUrl,
    required this.locationName,
    required this.username,
    required this.timeLabel,
    required this.peepCountLabel,
    required this.address,
    required this.onBack,
    required this.onShare,
    required this.onMenu,
  });

  final String? imageUrl;
  final String locationName;
  final String username;
  final String timeLabel;
  final String? peepCountLabel;
  final String? address;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(PeeplDetailTokens.heroRadius),
            bottomRight: Radius.circular(PeeplDetailTokens.heroRadius),
          ),
          child: SizedBox(
            height: 320,
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
                        PeeplDetailTokens.background.withValues(alpha: 0.55),
                        PeeplDetailTokens.background.withValues(alpha: 0.15),
                        PeeplDetailTokens.background.withValues(alpha: 0.92),
                      ],
                      stops: const [0.0, 0.35, 1.0],
                    ),
                  ),
                ),
              ],
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
              const Expanded(
                child: Center(
                  child: Text(
                    'peepl',
                    style: TextStyle(
                      color: PeeplDetailTokens.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              DetailGlassIconButton(
                icon: Icons.ios_share_rounded,
                onTap: onShare,
                tooltip: 'Share',
              ),
              const SizedBox(width: 8),
              DetailGlassIconButton(
                icon: Icons.more_horiz_rounded,
                onTap: onMenu,
                tooltip: 'Menu',
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
              if (peepCountLabel != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: PeeplDetailTokens.glassDecoration(radius: 20),
                    child: Text(
                      peepCountLabel!,
                      style: const TextStyle(
                        color: PeeplDetailTokens.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                locationName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PeeplDetailTokens.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              if (address != null && address!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  address!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PeeplDetailTokens.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Posted by $username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PeeplDetailTokens.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (timeLabel.isNotEmpty) ...[
                    const Text(
                      ' · ',
                      style: TextStyle(color: PeeplDetailTokens.textSecondary),
                    ),
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        color: PeeplDetailTokens.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
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
      color: PeeplDetailTokens.cardElevated,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 72, color: PeeplDetailTokens.textSecondary),
      ),
    );
  }
}
