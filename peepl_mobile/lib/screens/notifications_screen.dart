import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Notifications',
      description: 'RN: notification list, mark read.',
    );
  }
}
