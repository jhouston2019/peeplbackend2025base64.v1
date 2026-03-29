import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class FollowListScreen extends StatelessWidget {
  const FollowListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Follow list',
      description: 'RN: followers or following list for a user.',
    );
  }
}
