import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class VIPeepsScreen extends StatelessWidget {
  const VIPeepsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'VIP peeps',
      description: 'RN: VIP tier peeps listing.',
    );
  }
}
