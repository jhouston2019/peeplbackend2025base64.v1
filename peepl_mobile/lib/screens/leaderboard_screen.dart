import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Leaderboard',
      description: 'RN: points / pioneers ranking.',
    );
  }
}
