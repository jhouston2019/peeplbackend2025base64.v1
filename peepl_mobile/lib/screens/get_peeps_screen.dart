import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class GetPeepsScreen extends StatelessWidget {
  const GetPeepsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Get peeps',
      description: 'RN: discover users to follow.',
    );
  }
}
