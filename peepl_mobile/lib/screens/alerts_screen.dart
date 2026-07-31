import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/peepl_app_tokens.dart';

import 'location_detail_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  static Stream<int> unreadCountStream(String uid) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .where((doc) => doc.data()['read'] != true)
              .length,
        );
  }

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _relativeTime(dynamic ts) {
    if (ts == null) return '';
    final DateTime dt = ts is Timestamp
        ? ts.toDate()
        : ts is DateTime
            ? ts
            : DateTime.fromMillisecondsSinceEpoch(0);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _iconForType(String type) {
    switch (type) {
      case 'post_liked':
        return const Icon(Icons.favorite, color: Colors.red, size: 22);
      case 'arrival_fulfilled':
        return const Icon(Icons.location_on, color: PeeplAppTokens.accentBlue, size: 22);
      case 'crowdsource_request':
        return const Icon(Icons.people, color: Colors.orange, size: 22);
      default:
        return Icon(Icons.notifications, color: PeeplAppTokens.textSecondary, size: 22);
    }
  }

  Future<void> _markAllRead(String uid, List<QueryDocumentSnapshot> docs) async {
    final unread =
        docs.where((doc) => (doc.data() as Map)['read'] != true).toList();
    if (unread.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> _onNotificationTap(
    BuildContext context,
    String uid,
    QueryDocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>;
    final type = (data['type'] ?? '').toString();

    await doc.reference.update({'read': true});
    if (!context.mounted) return;

    final postId = (data['postId'] ?? data['relatedId'] ?? '').toString();

    if (type == 'post_liked' || type == 'crowdsource_request') {
      if (postId.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('location_posts')
            .doc(postId)
            .get();
        if (!context.mounted) return;
        if (snap.exists) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LocationDetailScreen(
                postData: {'id': snap.id, ...?snap.data()},
              ),
            ),
          );
        }
      }
      return;
    }

    if (type == 'arrival_fulfilled') {
      Navigator.pushNamed(context, '/map');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Alerts'),
          backgroundColor: PeeplAppTokens.shellNavy,
          foregroundColor: PeeplAppTokens.textPrimary,
        ),
        body: const Center(child: Text('Please log in to see notifications')),
      );
    }

    final uid = user.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        backgroundColor: PeeplAppTokens.shellNavy,
        foregroundColor: PeeplAppTokens.textPrimary,
        actions: [
          TextButton(
            onPressed: () async {
              final snap = await FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(uid)
                  .collection('items')
                  .orderBy('timestamp', descending: true)
                  .limit(50)
                  .get();
              if (!context.mounted) return;
              await _markAllRead(uid, snap.docs);
            },
            child: const Text(
              'Mark all read',
              style: TextStyle(color: PeeplAppTokens.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .doc(uid)
            .collection('items')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load notifications'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No notifications yet'),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final type = (data['type'] ?? '').toString();
              final isUnread = data['read'] != true;
              final title = (data['title'] ?? '').toString();
              final body = (data['body'] ?? '').toString();

              return ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                          color: PeeplAppTokens.accentBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    _iconForType(type),
                  ],
                ),
                title: Text(
                  title.isNotEmpty ? title : type,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (body.isNotEmpty)
                      Text(
                        body,
                        style: TextStyle(fontSize: 12, color: PeeplAppTokens.textSecondary),
                      ),
                    Text(
                      _relativeTime(data['timestamp']),
                      style: TextStyle(fontSize: 11, color: PeeplAppTokens.textMuted),
                    ),
                  ],
                ),
                onTap: () => _onNotificationTap(context, uid, doc),
              );
            },
          );
        },
      ),
    );
  }
}
