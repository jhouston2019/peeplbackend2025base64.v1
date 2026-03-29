import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Search',
      description: 'RN: search users, venues, peeps.',
    );
  }
}
