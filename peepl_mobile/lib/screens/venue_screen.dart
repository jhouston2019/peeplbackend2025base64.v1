import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class VenueScreen extends StatelessWidget {
  const VenueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Venue',
      description: 'RN: single venue detail, crowd, peeps.',
    );
  }
}
