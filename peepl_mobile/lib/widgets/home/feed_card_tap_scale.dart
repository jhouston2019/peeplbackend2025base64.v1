import 'package:flutter/material.dart';

/// Premium press feedback for feed cards — scale only, no layout shift.
class FeedCardTapScale extends StatefulWidget {
  const FeedCardTapScale({
    super.key,
    required this.onTap,
    required this.child,
    this.onLongPress,
  });

  final VoidCallback onTap;
  final Widget child;
  final VoidCallback? onLongPress;

  @override
  State<FeedCardTapScale> createState() => _FeedCardTapScaleState();
}

class _FeedCardTapScaleState extends State<FeedCardTapScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
