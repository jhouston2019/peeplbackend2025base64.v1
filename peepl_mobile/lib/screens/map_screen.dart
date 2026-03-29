import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Map',
      description: 'RN: MapView venues, crowd heat, merchant ads, filters.',
    );
  }
}
