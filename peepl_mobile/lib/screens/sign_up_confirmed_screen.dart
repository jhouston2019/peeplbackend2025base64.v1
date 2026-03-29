import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class SignUpConfirmedScreen extends StatelessWidget {
  const SignUpConfirmedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Sign up confirmed',
      description: 'RN: post-registration confirmation.',
    );
  }
}
