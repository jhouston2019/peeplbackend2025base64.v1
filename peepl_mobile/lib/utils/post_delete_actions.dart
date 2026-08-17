import 'package:flutter/material.dart';

import '../services/feed_service.dart';

Future<bool> confirmAndDeletePost(
  BuildContext context,
  FeedService feedService, {
  required String postId,
  String? locationName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete post?'),
      content: Text(
        locationName != null && locationName.isNotEmpty
            ? 'Remove your crowd report at $locationName? This cannot be undone.'
            : 'Remove this crowd report? This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return false;

  try {
    await feedService.deleteLocationPost(postId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted')),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return false;
  }
}

Future<void> showPostActionMenu(
  BuildContext context, {
  required bool isOwner,
  required VoidCallback onReport,
  required Future<void> Function() onDelete,
}) async {
  if (!isOwner) {
    onReport();
    return;
  }

  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              'Delete post',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Report'),
            onTap: () => Navigator.pop(ctx, 'report'),
          ),
        ],
      ),
    ),
  );

  if (!context.mounted || action == null) return;
  if (action == 'delete') {
    await onDelete();
  } else if (action == 'report') {
    onReport();
  }
}
