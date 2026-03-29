import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class InviteScreen extends StatelessWidget {
  const InviteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Invite',
      description: 'RN: invite friends / share referral.',
    );
  }
}
