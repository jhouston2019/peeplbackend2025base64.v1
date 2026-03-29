import 'package:flutter/material.dart';
import '../../widgets/peepl_ported_screen_shell.dart';

class MerchantPortalScreen extends StatelessWidget {
  const MerchantPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Merchant portal',
      description: 'RN: create ad slots, rates, schedule, submit to API.',
    );
  }
}
