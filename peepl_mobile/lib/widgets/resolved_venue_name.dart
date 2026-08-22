import 'package:flutter/material.dart';

import '../services/venue_name_service.dart';

class ResolvedVenueName extends StatelessWidget {
  const ResolvedVenueName({
    super.key,
    required this.post,
    this.style,
    this.maxLines = 1,
    this.loadingText = '…',
    this.fallback = 'Unknown Venue',
    this.textAlign,
  });

  final Map<String, dynamic> post;
  final TextStyle? style;
  final int? maxLines;
  final String loadingText;
  final String fallback;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: VenueNameService.displayNameForPost(post),
      builder: (context, snapshot) {
        final name = snapshot.data ??
            (snapshot.connectionState == ConnectionState.waiting
                ? loadingText
                : VenueNameService.storedVenueName(post) ??
                    VenueNameService.addressFallback(post) ??
                    fallback);
        return Text(
          name,
          style: style,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
        );
      },
    );
  }
}
