import 'package:flutter/material.dart';

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
                  ? const Color(0xFF1565C0)
                  : Colors.grey[300],
            ),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                  color: isActive || isComplete
                      ? Colors.white
                      : Colors.grey[600],
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
              color: isComplete ? const Color(0xFF1565C0) : Colors.grey[300],
            ),
        ],
      );
    }),
  );
}
