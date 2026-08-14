import 'package:flutter/material.dart';

import '../home/peepl_home_tokens.dart';
import 'peepl_detail_tokens.dart';

class DetailCommentInput extends StatelessWidget {
  const DetailCommentInput({
    super.key,
    required this.controller,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PeeplDetailTokens.card.withValues(alpha: 0.95),
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: PeeplDetailTokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: TextStyle(
                      color: PeeplDetailTokens.textTertiary,
                    ),
                    filled: true,
                    fillColor: PeeplHomeTokens.searchField,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: PeeplDetailTokens.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: PeeplDetailTokens.accentBlue,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    if (!isSubmitting) onSubmit();
                  },
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isSubmitting ? null : onSubmit,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: PeeplHomeTokens.actionGreen,
                    shape: BoxShape.circle,
                  ),
                  child: isSubmitting
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            color: PeeplDetailTokens.textPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_forward_rounded,
                          color: PeeplDetailTokens.textPrimary,
                          size: 22,
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
