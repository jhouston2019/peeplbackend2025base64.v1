import 'package:flutter/material.dart';

import 'peepl_detail_tokens.dart';

class DetailSectionCard extends StatelessWidget {
  const DetailSectionCard({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  final Widget child;
  final String? title;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding,
      decoration: PeeplDetailTokens.cardDecoration(color: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                color: PeeplDetailTokens.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}
