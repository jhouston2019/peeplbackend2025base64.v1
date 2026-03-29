import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class ShareScreen extends StatelessWidget {
  const ShareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Share',
      description: 'RN: share sheet / deep link for peep or venue.',
    );
  }
}
