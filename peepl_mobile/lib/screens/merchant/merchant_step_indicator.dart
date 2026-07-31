import 'package:flutter/material.dart';

import '../../theme/peepl_app_tokens.dart';

Widget merchantStepIndicator(int currentStep) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(3, (index) {
      final step = index + 1;
      final isActive = step == currentStep;
      final isComplete = step < currentStep;
      return Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive || isComplete
                  ? PeeplAppTokens.accentBlue
                  : PeeplAppTokens.cardElevated,
            ),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                  color: isActive || isComplete
                      ? PeeplAppTokens.textPrimary
                      : PeeplAppTokens.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (index < 2)
            Container(
              width: 40,
              height: 2,
              color: isComplete
                  ? PeeplAppTokens.accentBlue
                  : PeeplAppTokens.cardElevated,
            ),
        ],
      );
    }),
  );
}
