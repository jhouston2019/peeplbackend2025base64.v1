import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class MyPeepsScreen extends StatelessWidget {
  const MyPeepsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'My peeps',
      description: 'RN: current user peeps feed.',
    );
  }
}
