import 'package:flutter/material.dart';

import '../services/peepl_positive_messages.dart';
import '../theme/peepl_app_tokens.dart';

/// Subtle positive sign-off for popups and modals.
///
/// Selects one message when the widget is first inserted and keeps it stable
/// for the lifetime of that popup instance.
class PeeplPositiveMessage extends StatefulWidget {
  const PeeplPositiveMessage({
    super.key,
    this.contextKey,
    this.onLightBackground = true,
  });

  /// Analytics / rotation context (e.g. `peep_submission_success`).
  final String? contextKey;

  /// Use muted grey on white sheets; token-based muted text on dark surfaces.
  final bool onLightBackground;

  @override
  State<PeeplPositiveMessage> createState() => _PeeplPositiveMessageState();
}

class _PeeplPositiveMessageState extends State<PeeplPositiveMessage> {
  PeeplPositiveMessageResult? _message;

  @override
  void initState() {
    super.initState();
    PeeplPositiveMessages.instance
        .next(surface: 'popup', context: widget.contextKey)
        .then((message) {
      if (mounted) setState(() => _message = message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    if (message == null) return const SizedBox.shrink();

    final textScaler = MediaQuery.textScalerOf(context);
    final baseSize = textScaler.scale(11.5);
    final color = widget.onLightBackground
        ? Colors.grey.shade600.withValues(alpha: 0.82)
        : PeeplAppTokens.textMuted;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        message.text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: baseSize,
          height: 1.35,
          fontWeight: FontWeight.w400,
          color: color,
        ),
      ),
    );
  }
}
