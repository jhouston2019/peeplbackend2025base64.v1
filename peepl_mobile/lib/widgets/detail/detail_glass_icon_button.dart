import 'package:flutter/material.dart';

import 'peepl_detail_tokens.dart';

class DetailGlassIconButton extends StatelessWidget {
  const DetailGlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: PeeplDetailTokens.glassDecoration(radius: size / 2),
        child: Icon(icon, color: PeeplDetailTokens.textPrimary, size: size * 0.5),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }
}
