import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class DealsScreen extends StatelessWidget {
  const DealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Deals',
      description: 'RN: merchant feed by location, filters, claim flow + countdown.',
    );
  }
}
