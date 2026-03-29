import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Permissions',
      description: 'RN: location and notification permission UX.',
    );
  }
}
