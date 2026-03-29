import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class AccountInfoScreen extends StatelessWidget {
  const AccountInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Account Info',
      description: 'RN: profile fields, image picker, save via REST + Firebase Auth.',
    );
  }
}
