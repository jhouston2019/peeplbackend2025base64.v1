import 'package:flutter/material.dart';

import '../home/peepl_home_tokens.dart';
import 'peepl_detail_tokens.dart';

/// Compact solid-blue Explore Live CTA for the LIVE NOW module.
class DetailExploreLiveButton extends StatelessWidget {
  const DetailExploreLiveButton({
    super.key,
    required this.isLoading,
    required this.onTap,
  });

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PeeplHomeTokens.brandBlue,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else ...[
                const Icon(
                  Icons.cell_tower_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Explore Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
