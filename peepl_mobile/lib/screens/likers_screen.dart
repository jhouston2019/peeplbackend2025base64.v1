import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class LikersScreen extends StatelessWidget {
  const LikersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Likers',
      description: 'RN: list of users who liked a peep.',
    );
  }
}
