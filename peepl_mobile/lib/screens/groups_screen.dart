import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Groups',
      description: 'RN: user groups list and navigation.',
    );
  }
}
