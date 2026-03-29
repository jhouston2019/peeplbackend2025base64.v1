import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class VenueListScreen extends StatelessWidget {
  const VenueListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Venue list',
      description: 'RN: list of venues with filters.',
    );
  }
}
