import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Menu',
      description: 'RN: app side menu / more options.',
    );
  }
}
