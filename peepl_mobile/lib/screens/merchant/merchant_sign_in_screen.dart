import 'package:flutter/material.dart';
import '../../widgets/peepl_ported_screen_shell.dart';

class MerchantSignInScreen extends StatelessWidget {
  const MerchantSignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Merchant sign in',
      description: 'RN: merchant auth entry.',
    );
  }
}
