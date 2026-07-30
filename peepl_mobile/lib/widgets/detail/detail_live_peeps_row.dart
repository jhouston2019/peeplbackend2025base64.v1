import 'package:flutter/material.dart';

import 'detail_section_card.dart';
import 'peepl_detail_tokens.dart';

class DetailLivePeepsRow extends StatelessWidget {
  const DetailLivePeepsRow({
    super.key,
    required this.usernames,
    required this.totalCount,
  });

  final List<String> usernames;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    if (usernames.isEmpty) return const SizedBox.shrink();

    final displayNames = usernames.take(5).toList();
    final overflow = totalCount - displayNames.length;

    return DetailSectionCard(
      title: 'Live Peeps',
      child: Row(
        children: [
          SizedBox(
            height: 40,
            width: displayNames.length * 28.0 + (overflow > 0 ? 28 : 0),
            child: Stack(
              children: [
                for (var i = 0; i < displayNames.length; i++)
                  Positioned(
                    left: i * 28.0,
                    child: _Avatar(name: displayNames[i]),
                  ),
                if (overflow > 0)
                  Positioned(
                    left: displayNames.length * 28.0,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: PeeplDetailTokens.cardElevated,
                        shape: BoxShape.circle,
                        border: Border.all(color: PeeplDetailTokens.border, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+$overflow',
                        style: const TextStyle(
                          color: PeeplDetailTokens.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$totalCount peep${totalCount == 1 ? '' : 's'} at this spot',
              style: const TextStyle(
                color: PeeplDetailTokens.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PeeplDetailTokens.accentBlue,
        border: Border.all(color: PeeplDetailTokens.background, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: PeeplDetailTokens.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}
