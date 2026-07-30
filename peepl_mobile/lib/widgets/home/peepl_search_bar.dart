import 'package:flutter/material.dart';

import 'peepl_home_tokens.dart';

class PeeplSearchBar extends StatelessWidget {
  const PeeplSearchBar({
    super.key,
    required this.onTap,
    required this.onFilterTap,
  });

  final VoidCallback onTap;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: PeeplHomeTokens.searchField,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: PeeplHomeTokens.chipBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: PeeplHomeTokens.white.withValues(alpha: 0.55),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search places, events, people...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PeeplHomeTokens.white.withValues(alpha: 0.45),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onFilterTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.tune,
                    color: PeeplHomeTokens.white.withValues(alpha: 0.55),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
