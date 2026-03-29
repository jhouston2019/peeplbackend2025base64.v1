import 'package:flutter/material.dart';
import '../../widgets/peepl_ported_screen_shell.dart';

class MerchantSetupStep1Screen extends StatelessWidget {
  const MerchantSetupStep1Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Merchant setup (1)',
      description: 'RN: merchant registration step 1.',
    );
  }
}
