import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignUpConfirmedScreen extends StatefulWidget {
  const SignUpConfirmedScreen({super.key});

  @override
  State<SignUpConfirmedScreen> createState() => _SignUpConfirmedScreenState();
}

class _SignUpConfirmedScreenState extends State<SignUpConfirmedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  String _username = 'there';
  bool _didInitUsername = false;

  static const _summaryPoints = [
    '📍 See how crowded any place is in real time',
    '📸 Post Peeps and become a Pioneer at new spots',
    '🎁 Discover deals and invite friends to join',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitUsername) return;
    _didInitUsername = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['username'] != null) {
      _username = args['username'] as String;
    } else {
      final user = FirebaseAuth.instance.currentUser;
      _username = user?.displayName ??
          user?.email?.split('@').first ??
          'there';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF1565C0),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/icon/icon.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Welcome to Peepl, $_username! 👋',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 28),
                ..._summaryPoints.map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            point,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      '/onboarding',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Let's Go!",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
