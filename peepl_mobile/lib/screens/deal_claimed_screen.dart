import 'dart:async';
import 'dart:math' as math;
import '../theme/peepl_app_tokens.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class DealClaimedScreen extends StatefulWidget {
  const DealClaimedScreen({super.key, required this.adData});

  final Map<String, dynamic> adData;

  @override
  State<DealClaimedScreen> createState() => _DealClaimedScreenState();
}

class _DealClaimedScreenState extends State<DealClaimedScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;

  late final AnimationController _checkCtrl;
  late final Animation<double> _checkScale;
  late final String _code;
  late final DateTime _expiresAt;
  late final Timer _ticker;
  bool _claimWritten = false;

  Map<String, dynamic> get _ad => widget.adData;

  String get _businessName {
    final name = (_ad['businessName'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    return (_ad['headline'] as String?) ??
        (_ad['venueName'] as String?) ??
        'Business';
  }

  String get _dealDescription {
    final desc = (_ad['dealDescription'] as String?)?.trim();
    if (desc != null && desc.isNotEmpty) return desc;
    return (_ad['subline'] as String?) ?? '';
  }

  String? get _merchantLogo {
    for (final key in ['merchantLogo', 'logoUrl', 'imageUrl']) {
      final v = _ad[key] as String?;
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  String get _dealId => (_ad['id'] as String?) ?? '';

  @override
  void initState() {
    super.initState();
    _code = _generateCode();
    _expiresAt = _resolveExpiry();

    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _checkScale = CurvedAnimation(
      parent: _checkCtrl,
      curve: Curves.elasticOut,
    );
    _checkCtrl.forward();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _writeClaim();
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    _ticker.cancel();
    super.dispose();
  }

  DateTime _resolveExpiry() {
    final expiry = _ad['dealExpiry'] ?? _ad['endDate'];
    if (expiry is Timestamp) return expiry.toDate();
    if (expiry is DateTime) return expiry;
    return DateTime.now().add(const Duration(hours: 24));
  }

  static String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = math.Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  String _expiryCountdown() {
    final diff = _expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    final s = diff.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m remaining';
    }
    return '${m}m ${s.toString().padLeft(2, '0')}s remaining';
  }

  Future<void> _writeClaim() async {
    if (_claimWritten) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _dealId.isEmpty) return;

    _claimWritten = true;

    try {
      await _db
          .collection('claimed_deals')
          .doc(user.uid)
          .collection('deals')
          .doc(_dealId)
          .set({
        'userId': user.uid,
        'dealId': _dealId,
        'businessName': _businessName,
        'dealDescription': _dealDescription,
        'redemptionCode': _code,
        'claimedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(_expiresAt),
        'adData': _ad,
      });
    } catch (e) {
      debugPrint('DealClaimedScreen._writeClaim error: $e');
    }
  }

  Future<void> _shareDeal() async {
    await Share.share(
      'I just got a deal at $_businessName on Peepl! 🎉',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF22CC44),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                ScaleTransition(
                  scale: _checkScale,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: PeeplAppTokens.textPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: PeeplAppTokens.textPrimary.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF22CC44),
                      size: 52,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Deal Claimed! 🎉',
                  style: TextStyle(
                    color: PeeplAppTokens.textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: PeeplAppTokens.textPrimary.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _MerchantLogo(logoUrl: _merchantLogo, name: _businessName),
                      const SizedBox(height: 12),
                      Text(
                        _businessName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: PeeplAppTokens.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_dealDescription.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _dealDescription,
                          style: const TextStyle(
                            fontSize: 14,
                            color: PeeplAppTokens.textMuted,
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          color: PeeplAppTokens.accentBlue,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2, color: Colors.white54, size: 56),
                            SizedBox(height: 10),
                            Text(
                              'Show this to staff',
                              style: TextStyle(
                                color: PeeplAppTokens.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Your deal code',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: PeeplAppTokens.accentBlue,
                          letterSpacing: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _expiryCountdown(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _shareDeal,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share Deal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PeeplAppTokens.background,
                      foregroundColor: const Color(0xFF22CC44),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pushNamedAndRemoveUntil(context, '/deals', (_) => false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PeeplAppTokens.textPrimary,
                      side: const BorderSide(color: PeeplAppTokens.textPrimary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Find More Deals',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MerchantLogo extends StatelessWidget {
  const _MerchantLogo({required this.logoUrl, required this.name});

  final String? logoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 64,
        height: 64,
        color: PeeplAppTokens.accentBlue.withValues(alpha: 0.1),
        child: logoUrl != null
            ? Image.network(
                logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: PeeplAppTokens.accentBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: PeeplAppTokens.accentBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
      ),
    );
  }
}
