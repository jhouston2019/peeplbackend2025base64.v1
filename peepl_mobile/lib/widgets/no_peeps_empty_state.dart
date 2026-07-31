import 'package:flutter/material.dart';
import '../theme/peepl_app_tokens.dart';

/// Shown when a venue has no crowd reports yet.
/// The "Peep Here →" button navigates to /post prefilling the location name.
class NoPeepsEmptyState extends StatelessWidget {
  final String locationName;

  const NoPeepsEmptyState({super.key, required this.locationName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👀', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            'No Peeps Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to Peep this spot and earn Pioneer status!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: PeeplAppTokens.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(
              context,
              '/post',
              arguments: {'locationName': locationName},
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: PeeplAppTokens.background,
              foregroundColor: PeeplAppTokens.textPrimary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Peep Here →',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
