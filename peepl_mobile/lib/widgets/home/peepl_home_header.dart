import 'package:flutter/material.dart';

import 'peepl_home_tokens.dart';

class PeeplHomeHeader extends StatelessWidget {
  const PeeplHomeHeader({
    super.key,
    required this.areaLabel,
    required this.onLocationTap,
    required this.onProfileTap,
    required this.onMenuTap,
  });

  final String areaLabel;
  final VoidCallback onLocationTap;
  final VoidCallback onProfileTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    const wordmarkStyle = TextStyle(
      color: PeeplHomeTokens.white,
      fontSize: 24,
      fontWeight: FontWeight.w800,
      height: 1.0,
      letterSpacing: -0.5,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: SizedBox(
        height: 34,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: onLocationTap,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: PeeplHomeTokens.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              areaLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: PeeplHomeTokens.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: PeeplHomeTokens.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onProfileTap,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: PeeplHomeTokens.white.withValues(alpha: 0.6),
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: PeeplHomeTokens.white,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onMenuTap,
                      behavior: HitTestBehavior.opaque,
                      child: const Icon(
                        Icons.menu,
                        color: PeeplHomeTokens.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            IgnorePointer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('p', style: wordmarkStyle),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('e', style: wordmarkStyle),
                      Transform.scale(
                        scaleX: -1,
                        child: Text('e', style: wordmarkStyle),
                      ),
                    ],
                  ),
                  Text('pl', style: wordmarkStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
