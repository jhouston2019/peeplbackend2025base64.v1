import 'package:flutter/material.dart';

import 'peepl_home_tokens.dart';

class PeeplHomeHeader extends StatelessWidget {
  const PeeplHomeHeader({
    super.key,
    required this.areaLabel,
    required this.onLocationTap,
    required this.onProfileTap,
    required this.onMenuTap,
    required this.onPostTap,
    required this.onRequestPeepTap,
  });

  final String areaLabel;
  final VoidCallback onLocationTap;
  final VoidCallback onProfileTap;
  final VoidCallback onMenuTap;
  final VoidCallback onPostTap;
  final VoidCallback onRequestPeepTap;

  @override
  Widget build(BuildContext context) {
    const wordmarkStyle = TextStyle(
      color: PeeplHomeTokens.brandBlue,
      fontSize: 24,
      fontWeight: FontWeight.w800,
      height: 1.0,
      letterSpacing: -0.5,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
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
                                color: PeeplHomeTokens.headerForeground,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  areaLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: PeeplHomeTokens.headerForeground,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: PeeplHomeTokens.headerForeground,
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
                              color: PeeplHomeTokens.chipSurface,
                              border: Border.all(
                                color: PeeplHomeTokens.chipBorderLight,
                              ),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: PeeplHomeTokens.headerForeground,
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
                            color: PeeplHomeTokens.headerForeground,
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onPostTap,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: PeeplHomeTokens.actionGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          color: Color(0xFF111111),
                          size: 20,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'PEEP',
                          style: TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onRequestPeepTap,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: PeeplHomeTokens.chipSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PeeplHomeTokens.chipBorderLight),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cell_tower,
                            color: PeeplHomeTokens.headerForeground,
                            size: 20,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'REQUEST A PEEP',
                            style: TextStyle(
                              color: PeeplHomeTokens.headerForeground,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
