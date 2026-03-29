import 'package:flutter/material.dart';
import '../widgets/peepl_ported_screen_shell.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PeeplPortedScreenShell(
      title: 'Favorites',
      description: 'RN: saved venues / peeps list.',
    );
  }
}
