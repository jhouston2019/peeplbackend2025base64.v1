import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/crowd_dot_ring_meter.dart';

class ShareScreen extends StatelessWidget {
  const ShareScreen({super.key, required this.postData});

  final Map<String, dynamic> postData;

  // ── helpers ────────────────────────────────────────────────────────────────

  static String _timeAgo(dynamic ts) {
    if (ts == null) return 'just now';
    final dt = ts is Timestamp ? ts.toDate() : null;
    if (dt == null) return 'just now';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static LinearGradient _gradientForLevel(int level) {
    if (level >= 8) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE53935), Color(0xFFC62828)],
      );
    }
    if (level >= 5) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF57C00), Color(0xFFBF360C)],
      );
    }
    if (level >= 3) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF558B2F), Color(0xFF1B5E20)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
    );
  }

  static String _shareText(String locationName, int level) {
    final status = CrowdDotRingMeter.statusWord(level);
    final slug = Uri.encodeComponent(locationName);
    return 'peepl.app/venue/$slug — $locationName is $status right now! '
        'Crowd level $level/10. Check it out 👇';
  }

  static Future<void> _copyLink(BuildContext ctx, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Copied!'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF1565C0),
        ),
      );
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locationName =
        (postData['locationName'] as String?)?.trim().isNotEmpty == true
            ? (postData['locationName'] as String).trim()
            : 'this spot';
    final username = (postData['username'] as String?) ?? 'Someone';
    final level = (postData['crowdingLevel'] as num?)?.toInt() ?? 5;
    final timeAgo = _timeAgo(postData['timestamp']);
    final status = CrowdDotRingMeter.statusWord(level);
    final shareText = _shareText(locationName, level);
    final gradient = _gradientForLevel(level);

    const options = <(String, String)>[
      ('📱', 'Text'),
      ('✉️', 'Email'),
      ('📘', 'Facebook'),
      ('📸', 'Instagram'),
      ('👻', 'Snapchat'),
      ('🐦', 'Twitter'),
      ('🔗', 'Copy Link'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ─────────────────────────────────────────────────────
            Stack(
              children: [
                Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(gradient: gradient),
                  padding: const EdgeInsets.fromLTRB(56, 0, 16, 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$locationName is $status!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Peepled by $username · $timeAgo',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── SHARE SHEET ────────────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Share this Peep',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      locationName,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 28),
                    // Grid: 4 per row, 2 rows
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final tileW = constraints.maxWidth / 4;
                        return Wrap(
                          children: options.map((opt) {
                            final (emoji, label) = opt;
                            final isCopy = label == 'Copy Link';
                            return SizedBox(
                              width: tileW,
                              child: _OptionTile(
                                emoji: emoji,
                                label: label,
                                onTap: isCopy
                                    ? () => _copyLink(context, shareText)
                                    : () => Share.share(shareText),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── option tile ──────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.18),
                ),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
