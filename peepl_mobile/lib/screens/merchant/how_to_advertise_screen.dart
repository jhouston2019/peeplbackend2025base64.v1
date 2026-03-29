import 'package:flutter/material.dart';
import '../../widgets/peepl_ported_screen_shell.dart';

class HowToAdvertiseScreen extends StatelessWidget {
  const HowToAdvertiseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'How to advertise',
      description: 'RN: merchant onboarding marketing copy.',
    );
  }
}
