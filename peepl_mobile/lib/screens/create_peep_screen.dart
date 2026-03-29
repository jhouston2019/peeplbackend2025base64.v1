import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class CreatePeepScreen extends StatelessWidget {
  const CreatePeepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Create peep',
      description: 'RN: compose peep, media, post to backend/Firestore.',
    );
  }
}
