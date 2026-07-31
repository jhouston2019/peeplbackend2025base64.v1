import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/peepl_app_tokens.dart';

class PeepSubmittedScreen extends StatefulWidget {
  /// Optionally supplied when pushed directly. If null the screen reads from
  /// route arguments (Navigator.pushReplacementNamed with String argument).
  final String? locationName;

  const PeepSubmittedScreen({super.key, this.locationName});

  @override
  State<PeepSubmittedScreen> createState() => _PeepSubmittedScreenState();
}

class _PeepSubmittedScreenState extends State<PeepSubmittedScreen> {
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      final name = widget.locationName ??
          (ModalRoute.of(context)?.settings.arguments as String?) ??
          '';
      _checkPioneer(name);
    }
  }

  Future<void> _checkPioneer(String locationName) async {
    if (!mounted) return;

    if (locationName.isEmpty) {
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('location_posts')
          .where('locationName', isEqualTo: locationName)
          .where('userId', isNotEqualTo: user.uid)
          .limit(1)
          .get();

      final isPioneer = snap.docs.isEmpty;

      if (!mounted) return;

      if (isPioneer) {
        Navigator.pushReplacementNamed(
          context,
          '/pioneer_congrat',
          arguments: locationName,
        );
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (_) {
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: PeeplAppTokens.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('✅', style: TextStyle(fontSize: 72)),
                  const SizedBox(height: 24),
                  const Text(
                    'Peep Submitted!',
                    style: TextStyle(
                      color: PeeplAppTokens.background,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your crowd report is live. Checking if you\'re the first to Peep this spot...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: PeeplAppTokens.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const _LoadingDots(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Animated loading dots ────────────────────────────────────────────────────

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _a1;
  late final Animation<double> _a2;
  late final Animation<double> _a3;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Each dot brightens for 2 out of 6 equal weight slots, staggered by 2.
    _a1 = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.25), weight: 1),
      TweenSequenceItem(tween: ConstantTween(0.25), weight: 4),
    ]).animate(_ctrl);

    _a2 = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.25), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.25), weight: 1),
      TweenSequenceItem(tween: ConstantTween(0.25), weight: 2),
    ]).animate(_ctrl);

    _a3 = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.25), weight: 4),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.25), weight: 1),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(opacity: _a1.value),
          const SizedBox(width: 10),
          _Dot(opacity: _a2.value),
          const SizedBox(width: 10),
          _Dot(opacity: _a3.value),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double opacity;
  const _Dot({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: PeeplAppTokens.background,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
