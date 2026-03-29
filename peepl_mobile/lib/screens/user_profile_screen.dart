import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'User profile',
      description: 'RN: another user profile, follow, peeps.',
    );
  }
}
