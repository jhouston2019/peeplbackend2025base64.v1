import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PioneerCongratScreen extends StatefulWidget {
  /// Optionally supplied when pushed directly. If null the screen reads the
  /// location name from named-route arguments (a plain String).
  final String? locationName;

  const PioneerCongratScreen({super.key, this.locationName});

  @override
  State<PioneerCongratScreen> createState() => _PioneerCongratScreenState();
}

class _PioneerCongratScreenState extends State<PioneerCongratScreen> {
  late final ConfettiController _confettiController;
  bool _claiming = false;
  String _resolvedName = '';
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _resolvedName = widget.locationName ??
          (ModalRoute.of(context)?.settings.arguments as String?) ??
          '';
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _claimBadge() async {
    if (_claiming) return;
    setState(() => _claiming = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      batch.set(db.collection('pioneers').doc(), {
        'userId': user.uid,
        'locationName': _resolvedName,
        'timestamp': FieldValue.serverTimestamp(),
        'pointsAwarded': 500,
      });

      batch.update(db.collection('users').doc(user.uid), {
        'points': FieldValue.increment(500),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('Pioneer claim error: $e');
    }

    _confettiController.play();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Dark navy gradient background
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D1B2A),
                    Color(0xFF1B2A4A),
                    Color(0xFF0A1628),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),

            // Floating emoji particles
            _ParticleBg(screenSize: size),

            // Main content
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 88)),
                      const SizedBox(height: 24),
                      const Text(
                        "You're a Pioneer!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _resolvedName.isNotEmpty
                            ? 'You were the first to Peep $_resolvedName. '
                                "You've earned Pioneer status and 500 points!"
                            : "You've earned Pioneer status and 500 points!",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.65,
                        ),
                      ),
                      const SizedBox(height: 44),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _claiming ? null : _claimBadge,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700),
                            foregroundColor: const Color(0xFF1A1A1A),
                            disabledBackgroundColor:
                                const Color(0xFFFFD700).withValues(alpha: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 6,
                            shadowColor:
                                const Color(0xFFFFD700).withValues(alpha: 0.5),
                          ),
                          child: _claiming
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF1A1A1A),
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Claim Your Badge 🏅',
                                  style: TextStyle(
                                    fontSize: 17,
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

            // Confetti emitter — centred at top of screen
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Color(0xFFFFD700),
                  Color(0xFFFFA500),
                  Colors.white,
                  Color(0xFF2244EE),
                  Color(0xFF00BFFF),
                  Color(0xFFFF69B4),
                ],
                numberOfParticles: 40,
                maxBlastForce: 28,
                minBlastForce: 8,
                gravity: 0.25,
                emissionFrequency: 0.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Floating emoji particle background ──────────────────────────────────────

class _ParticleBg extends StatefulWidget {
  final Size screenSize;

  const _ParticleBg({required this.screenSize});

  @override
  State<_ParticleBg> createState() => _ParticleBgState();
}

class _ParticleBgState extends State<_ParticleBg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const _emojis = ['🌟', '✨', '⭐', '🎉'];

  // [fractional-left, fractional-top] — hand-placed to avoid the centre focal area
  static const List<(double, double)> _positions = [
    (0.06, 0.09),
    (0.82, 0.07),
    (0.13, 0.38),
    (0.77, 0.28),
    (0.48, 0.72),
    (0.20, 0.80),
    (0.90, 0.58),
    (0.38, 0.11),
    (0.63, 0.86),
    (0.03, 0.61),
    (0.56, 0.47),
    (0.29, 0.53),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.screenSize.width;
    final h = widget.screenSize.height;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Stack(
        children: [
          for (var i = 0; i < _positions.length; i++)
            Positioned(
              left: _positions[i].$1 * w,
              top: _positions[i].$2 * h,
              child: Opacity(
                // Each particle has a different phase so they pulse out of sync
                opacity: 0.15 +
                    0.55 *
                        (1 -
                            math.cos(
                              (_ctrl.value + i / _positions.length) *
                                  2 *
                                  math.pi,
                            )) /
                        2,
                child: Text(
                  _emojis[i % _emojis.length],
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
