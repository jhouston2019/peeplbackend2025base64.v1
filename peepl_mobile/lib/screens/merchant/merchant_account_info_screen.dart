import 'package:flutter/material.dart';
import '../../widgets/peepl_ported_screen_shell.dart';

class MerchantAccountInfoScreen extends StatelessWidget {
  const MerchantAccountInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Merchant account info',
      description: 'RN: business profile fields for merchant.',
    );
  }
}
