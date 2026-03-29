import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class PioneersScreen extends StatelessWidget {
  const PioneersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Pioneers',
      description: 'RN: pioneers discovery / leaderboard entry.',
    );
  }
}
