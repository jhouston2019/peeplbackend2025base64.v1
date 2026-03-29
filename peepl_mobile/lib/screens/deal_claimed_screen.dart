import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class DealClaimedScreen extends StatelessWidget {
  const DealClaimedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Deal claimed',
      description: 'RN: confirmation after claiming a merchant deal.',
    );
  }
}
