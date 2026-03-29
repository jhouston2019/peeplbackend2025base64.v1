import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class PeepDetailScreen extends StatelessWidget {
  const PeepDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Peep detail',
      description: 'RN: single peep thread, likes, comments.',
    );
  }
}
