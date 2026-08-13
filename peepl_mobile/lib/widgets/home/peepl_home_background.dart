import 'dart:ui';

import 'package:flutter/material.dart';

import 'peepl_home_tokens.dart';

/// Soft daylight environmental backdrop for the Peepl home feed shell.
///
/// There is no photo asset — the atmosphere is built from a gradient plus
/// colored bokeh shapes, blurred in one pass via [ImageFiltered], then a very
/// light sage tint. [BackdropFilter] is intentionally avoided; on smooth
/// synthetic layers it reads as a flat off-white sheet rather than blur.
class PeeplHomeBackground extends StatelessWidget {
  const PeeplHomeBackground({super.key, required this.child});

  static const _backgroundBlurSigma = 20.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: _backgroundBlurSigma,
              sigmaY: _backgroundBlurSigma,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: PeeplHomeTokens.feedBackdropGradient,
                      stops: [0.0, 0.38, 0.72, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  top: -40,
                  left: -30,
                  child: _BokehOrb(
                    diameter: 180,
                    color: PeeplHomeTokens.feedBokehMint.withValues(alpha: 0.50),
                  ),
                ),
                Positioned(
                  top: 120,
                  right: -50,
                  child: _BokehOrb(
                    diameter: 220,
                    color: PeeplHomeTokens.feedBokehSky.withValues(alpha: 0.54),
                  ),
                ),
                Positioned(
                  bottom: 140,
                  left: 40,
                  child: _BokehOrb(
                    diameter: 160,
                    color: PeeplHomeTokens.feedBokehWarm.withValues(alpha: 0.36),
                  ),
                ),
                Positioned(
                  bottom: -20,
                  right: 20,
                  child: _BokehOrb(
                    diameter: 200,
                    color: PeeplHomeTokens.feedBokehSky.withValues(alpha: 0.32),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Positioned.fill(
          child: ColoredBox(color: PeeplHomeTokens.feedFrostOverlay),
        ),
        child,
      ],
    );
  }
}

class _BokehOrb extends StatelessWidget {
  const _BokehOrb({
    required this.diameter,
    required this.color,
  });

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.35, 1.0],
        ),
      ),
    );
  }
}
