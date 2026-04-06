import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VIPeepsScreen extends StatefulWidget {
  const VIPeepsScreen({super.key});

  @override
  State<VIPeepsScreen> createState() => _VIPeepsScreenState();
}

class _VIPeepsScreenState extends State<VIPeepsScreen> {
  bool _subscribing = false;

  static const _features = <(String, String, String)>[
    ('📊', 'Crowd History', '24-hr trend graphs per venue'),
    ('🔔', 'Priority Alerts', 'First to know when spots hit 8+'),
    ('📍', 'Unlimited Saves', 'Save unlimited favorite venues'),
    ('🎯', 'Deal Priority', 'Early access to merchant deals'),
    ('🏆', 'VIP Badge', 'Stand out on the leaderboard'),
  ];

  // ── subscribe / waitlist ──────────────────────────────────────────────────

  Future<void> _onSubscribeTap() async {
    final user = FirebaseAuth.instance.currentUser;
    setState(() => _subscribing = true);

    try {
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('vipeeps_waitlist')
            .doc(user.uid)
            .set({
          'userId': user.uid,
          'email': user.email,
          'joinedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // best-effort — show snackbar regardless
    } finally {
      if (mounted) {
        setState(() => _subscribing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Subscription coming soon — join the waitlist!'),
            backgroundColor: Color(0xFF1565C0),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0C0C28), Color(0xFF343470)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back button
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white70),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Hero icon
                const Center(
                  child: Text('⭐',
                      style: TextStyle(fontSize: 72)),
                ),
                const SizedBox(height: 16),

                // Title
                const Center(
                  child: Text(
                    'VIPeeps',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Sub-text
                Center(
                  child: Text(
                    'Upgrade for the full experience',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 15,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Feature cards
                ..._features.map(
                  (f) => _FeatureCard(
                    emoji: f.$1,
                    title: f.$2,
                    subtitle: f.$3,
                  ),
                ),

                const SizedBox(height: 32),

                // Subscribe button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24),
                  child: ElevatedButton(
                    onPressed:
                        _subscribing ? null : _onSubscribeTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor:
                          const Color(0xFFFFD700)
                              .withValues(alpha: 0.6),
                      padding:
                          const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 6,
                      shadowColor: const Color(0xFFFFD700)
                          .withValues(alpha: 0.4),
                    ),
                    child: _subscribing
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.black54,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Subscribe — \$4.99 / month',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // Fine print
                Center(
                  child: Text(
                    'Cancel anytime.',
                    style: TextStyle(
                      color:
                          Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
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

// ── feature card ──────────────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  final String emoji;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle,
              color: Color(0xFFFFD700), size: 18),
        ],
      ),
    );
  }
}
