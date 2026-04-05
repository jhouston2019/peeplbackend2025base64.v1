import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OnboardingData {
  final String icon;
  final String title;
  final String body;

  const _OnboardingData({
    required this.icon,
    required this.title,
    required this.body,
  });
}

class OnboardingScreen extends StatelessWidget {
  final int step;

  const OnboardingScreen({super.key, required this.step});

  static const List<_OnboardingData> _steps = [
    _OnboardingData(
      icon: '👥',
      title: 'Know Before You Go',
      body:
          'See real-time crowd levels from real people at bars, restaurants, parks, and events near you.',
    ),
    _OnboardingData(
      icon: '📍',
      title: 'Real People, Real Time',
      body:
          'Every Peep is posted by someone there right now. See crowd size, vibe, and wait times before you leave.',
    ),
    _OnboardingData(
      icon: '🏆',
      title: 'Become a Pioneer',
      body:
          'Be the first to Peep a new venue and earn Pioneer status. Climb the leaderboard and unlock VIPeeps.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final index = (step - 1).clamp(0, 2);
    final data = _steps[index];
    final isLast = step == 3;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Container(
                color: const Color(0xFF2244EE),
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      data.icon,
                      style: const TextStyle(fontSize: 72),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        data.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data.body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF444444),
                        height: 1.6,
                      ),
                    ),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (i) {
                            final active = i + 1 == step;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              width: active ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0xFF2244EE)
                                    : const Color(0xFFCCCCCC),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _onNext(context, isLast),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2244EE),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              isLast ? 'Get Started' : 'Next',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Future<void> _onNext(BuildContext context, bool isLast) async {
    if (isLast) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasCompletedOnboarding', true);
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/onboarding/${step + 1}');
    }
  }
}
