import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Onboarding',
      description: 'RN: first-run slides and permissions prompts.',
    );
  }
}
