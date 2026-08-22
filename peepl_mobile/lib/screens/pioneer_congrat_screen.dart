import 'dart:math' as math;
import '../theme/peepl_app_tokens.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/share_service.dart';
import '../utils/post_peep_share_prompt.dart';
import '../widgets/peepl_positive_message.dart';

class PioneerCongratScreen extends StatefulWidget {
  /// Optionally supplied when pushed directly. If null the screen reads
  /// [PostPeepShareArgs] from named-route arguments (a map).
  final String? locationName;

  const PioneerCongratScreen({super.key, this.locationName});

  @override
  State<PioneerCongratScreen> createState() => _PioneerCongratScreenState();
}

class _PioneerCongratScreenState extends State<PioneerCongratScreen> {
  late final ConfettiController _confettiController;
  String _resolvedName = '';
  PostPeepShareArgs? _shareArgs;
  bool _didInit = false;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _shareArgs = PostPeepShareArgs.fromRoute(
        ModalRoute.of(context)?.settings.arguments,
        widgetLocationName: widget.locationName,
      );
      _resolvedName =
          _shareArgs?.locationName ?? widget.locationName ?? '';
      _recordPioneerAndCelebrate();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _recordPioneerAndCelebrate() async {
    if (_recording) return;
    _recording = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _resolvedName.isNotEmpty) {
      try {
        final db = FirebaseFirestore.instance;
        final existing = await db
            .collection('pioneers')
            .where('locationName', isEqualTo: _resolvedName)
            .limit(1)
            .get();
        if (existing.docs.isEmpty) {
          final batch = db.batch();
          batch.set(db.collection('pioneers').doc(), {
            'userId': user.uid,
            'locationName': _resolvedName,
            'timestamp': FieldValue.serverTimestamp(),
            'pointsAwarded': 500,
          });
          batch.update(db.collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3').doc(user.uid), {
            'points': FieldValue.increment(500),
          });
          await batch.commit();
        }
      } catch (e) {
        debugPrint('Pioneer record error: $e');
      }
    }

    _confettiController.play();

    if (_shareArgs != null) {
      if (!context.mounted) return;
      await schedulePostPeepSharePrompt(
        context: context,
        args: _shareArgs!,
      );
    }
  }

  Future<void> _shareAchievement() async {
    if (_resolvedName.isEmpty) return;

    try {
      final postId = _shareArgs?.postId;
      final user = FirebaseAuth.instance.currentUser;
      if (postId == null || postId.isEmpty || user == null) {
        await Share.share(
          'I just became the Pioneer of $_resolvedName on Peepl! 🏆 '
          'Know before you go: https://peepl.app',
        );
        return;
      }

      final shareUrl = await ShareService.instance.generatePeepShareUrl(
        peepId: postId,
        sharingUserId: user.uid,
        shareContext: 'pioneer_achievement',
      );

      await Share.share(
        'I just became the Pioneer of $_resolvedName on Peepl! 🏆 '
        'Know before you go: $shareUrl',
      );
    } catch (e) {
      debugPrint('[PioneerCongratScreen] _shareAchievement error: $e');
    }
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
            _ParticleBg(screenSize: size),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    const Text('🏆', style: TextStyle(fontSize: 88)),
                    const SizedBox(height: 24),
                    const Text(
                      "You're a Pioneer! 🎉",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _resolvedName.isNotEmpty
                          ? "You're the first person to post about $_resolvedName!"
                          : "You're the first person to post about this location!",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: PeeplAppTokens.textPrimary,
                        fontSize: 16,
                        height: 1.65,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _PioneerBadge(),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _shareAchievement,
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share this achievement'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: const Color(0xFF1A1A1A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, '/pioneers'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PeeplAppTokens.textPrimary,
                          side: const BorderSide(color: Colors.white70, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'View all Pioneers',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, '/home'),
                        child: const Text(
                          'Back to Feed',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const PeeplPositiveMessage(
                      contextKey: 'pioneer_congrat',
                      onLightBackground: false,
                    ),
                  ],
                ),
              ),
            ),
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
                  PeeplAppTokens.background,
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

class _PioneerBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PeeplAppTokens.accentBlue,
        boxShadow: [
          BoxShadow(
            color: PeeplAppTokens.accentBlue.withValues(alpha: 0.45),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('⭐', style: TextStyle(fontSize: 36)),
          SizedBox(height: 4),
          Text(
            'Pioneer',
            style: TextStyle(
              color: PeeplAppTokens.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

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
      builder: (context, child) => Stack(
        children: [
          for (var i = 0; i < _positions.length; i++)
            Positioned(
              left: _positions[i].$1 * w,
              top: _positions[i].$2 * h,
              child: Opacity(
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
