import 'package:flutter/material.dart';
import '../../widgets/peepl_ported_screen_shell.dart';

class MerchantActivityScreen extends StatelessWidget {
  const MerchantActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Merchant activity',
      description: 'RN: merchant ad activity / stats.',
    );
  }
}
