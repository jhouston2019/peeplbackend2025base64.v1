import 'package:flutter/material.dart';

import 'peepl_detail_tokens.dart';

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: PeeplDetailTokens.accentBlue,
        borderRadius: BorderRadius.circular(PeeplDetailTokens.cardRadius),
        elevation: 0,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(PeeplDetailTokens.cardRadius),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PeeplDetailTokens.cardRadius),
              gradient: const LinearGradient(
                colors: [Color(0xFF2E6CFF), Color(0xFF1B4FD8)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x402E6CFF),
                  offset: Offset(0, 6),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else ...[
                  const Icon(Icons.campaign_outlined, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Explore Live',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
