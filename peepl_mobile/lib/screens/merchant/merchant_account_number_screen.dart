import 'package:flutter/material.dart';
import '../../widgets/peepl_ported_screen_shell.dart';

class MerchantAccountNumberScreen extends StatelessWidget {
  const MerchantAccountNumberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Merchant account number',
      description: 'RN: payout / account number capture.',
    );
  }
}
