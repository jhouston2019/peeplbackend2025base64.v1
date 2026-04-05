import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Native ad card that matches post-card dimensions so the feed feels seamless.
///
/// Impression fires once on first frame via [WidgetsBinding.addPostFrameCallback].
/// For production, swap that for a VisibilityDetector to count only when ≥50%
/// of the card is actually on screen.
///
/// The [ad] map mirrors the Firestore `native_ads` document shape:
///   headline  String   — primary copy
///   subline   String   — secondary copy
///   bgColor   dynamic  — Color, int (ARGB), or "0xFFrrggbb" hex string
class AdCard extends StatefulWidget {
  final Map<String, dynamic> ad;
  final VoidCallback? onImpression;
  final VoidCallback? onTap;

  const AdCard({
    super.key,
    required this.ad,
    this.onImpression,
    this.onTap,
  });

  @override
  State<AdCard> createState() => _AdCardState();
}

class _AdCardState extends State<AdCard> {
  bool _impressionFired = false;

  // Unique key scoped to this widget instance so VisibilityDetector can
  // deregister itself correctly when the card leaves the tree.
  late final String _visibilityKey =
      'ad_${widget.ad['id'] ?? Object.hash(widget.ad, identityHashCode(this))}';

  static Color _parseColor(dynamic value) {
    if (value is Color) return value;
    if (value is int) return Color(value);
    if (value is String) {
      final normalized = value.startsWith('0x') || value.startsWith('0X')
          ? value
          : '0x$value';
      final parsed = int.tryParse(normalized);
      if (parsed != null) return Color(parsed);
    }
    return const Color(0xFF1a1a1a);
  }

  @override
  Widget build(BuildContext context) {
    final headline = widget.ad['headline'] as String? ?? '';
    final subline = widget.ad['subline'] as String? ?? '';
    final bgColor = _parseColor(widget.ad['bgColor']);

    return VisibilityDetector(
      key: Key(_visibilityKey),
      onVisibilityChanged: (info) {
        // Fire once when ≥50 % of the card is visible on screen.
        if (!_impressionFired && info.visibleFraction >= 0.5 && mounted) {
          _impressionFired = true;
          widget.onImpression?.call();
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
        height: 74,
        margin: const EdgeInsets.only(bottom: 3),
        decoration: BoxDecoration(color: bgColor),
        child: Stack(
          children: [
            // Left-to-right gradient overlay mirrors post-card aesthetic
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.black.withValues(alpha: 0.15),
                    ],
                  ),
                ),
              ),
            ),

            // SPONSORED badge — top left
            Positioned(
              top: 6,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Text(
                  'SPONSORED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // Headline + subline
            Positioned(
              top: 22,
              left: 8,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subline,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 10,
                      shadows: const [
                        Shadow(blurRadius: 3, color: Colors.black),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),   // GestureDetector
    );   // VisibilityDetector
  }
}
