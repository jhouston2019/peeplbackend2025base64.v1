import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DealClaimedScreen extends StatefulWidget {
  const DealClaimedScreen({super.key, required this.adData});

  final Map<String, dynamic> adData;

  @override
  State<DealClaimedScreen> createState() => _DealClaimedScreenState();
}

class _DealClaimedScreenState extends State<DealClaimedScreen> {
  final _db = FirebaseFirestore.instance;

  late final String _code;
  late final DateTime _expiresAt;
  late final Timer _ticker;
  bool _claimWritten = false;

  /// Normalise the adData map so it always has 'headline', 'subline', 'id'
  /// regardless of whether it came from the native-ads shape or the map-pin shape.
  Map<String, dynamic> get _normalisedAd {
    final d = widget.adData;
    if (d.containsKey('headline')) return d;
    return {
      ...d,
      'headline': d['venueName'] as String? ?? '',
      'subline': d['offerText'] as String? ?? '',
      'id': d['dealId'] as String? ?? '',
    };
  }

  @override
  void initState() {
    super.initState();
    final ad = _normalisedAd;
    final venueName = (ad['headline'] as String?) ?? 'VEN';
    _code = _generateCode(venueName);
    _expiresAt = DateTime.now().add(const Duration(minutes: 45));

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _writeClaim();
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _generateCode(String venueName) {
    final letters =
        venueName.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    final prefix = letters.length >= 3
        ? letters.substring(0, 3)
        : letters.padRight(3, 'X');
    final digits = (1000 + math.Random().nextInt(9000)).toString();
    return '$prefix$digits';
  }

  String _expiryCountdown() {
    final diff = _expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    final m = diff.inMinutes;
    final s = diff.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ── Firestore ─────────────────────────────────────────────────────────────

  Future<void> _writeClaim() async {
    if (_claimWritten) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _claimWritten = true;
    final ad = _normalisedAd;
    final adId = (ad['id'] as String?) ?? '';

    try {
      await _db.collection('deal_claims').add({
        'userId': user.uid,
        'adId': adId,
        'claimedAt': FieldValue.serverTimestamp(),
        'redemptionCode': _code,
        'expiresAt': Timestamp.fromDate(_expiresAt),
      });
    } catch (e) {
      debugPrint('DealClaimedScreen._writeClaim error: $e');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ad = _normalisedAd;
    final venueName = (ad['headline'] as String?) ?? 'Venue';
    final offerText = (ad['subline'] as String?) ?? '';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF22CC44),
        body: SafeArea(
          child: Column(
            children: [
              // Top padding + subtle header row (no back button — intentional)
              const SizedBox(height: 40),

              // 🎟️ hero emoji
              const Text('🎟️', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 16),

              // Title
              const Text(
                'Deal Claimed!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 28),

              // White semi-transparent card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 22,
                  ),
                  child: Column(
                    children: [
                      // Venue name
                      Text(
                        venueName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      if (offerText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          offerText,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 14),

                      // Instruction
                      const Text(
                        'Show this screen to your server',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black38,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Redemption code
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFFFD700),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          _code,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFB8860B),
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Expiry countdown below the card
              Text(
                'Expires in ${_expiryCountdown()}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(),

              // Done button
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF22CC44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home',
                      (_) => false,
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
