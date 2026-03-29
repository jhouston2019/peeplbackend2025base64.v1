import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Report',
      description: 'RN: report content / user flow.',
    );
  }
}
