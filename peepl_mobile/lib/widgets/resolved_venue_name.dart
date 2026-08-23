import 'package:flutter/material.dart';

import '../services/venue_name_service.dart';

class ResolvedVenueName extends StatelessWidget {
  const ResolvedVenueName({
    super.key,
    required this.post,
    this.style,
    this.maxLines = 1,
    this.fallback = 'Unknown Venue',
    this.textAlign,
  });

  final Map<String, dynamic> post;
  final TextStyle? style;
  final int? maxLines;
  final String fallback;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final name = VenueNameService.labelForPost(post);
    return Text(
      name.isEmpty ? fallback : name,
      style: style,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
    );
  }
}
