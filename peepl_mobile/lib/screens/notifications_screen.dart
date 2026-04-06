import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {

  // ── Icon config ───────────────────────────────────────────────────────────────
  static String _emoji(String? type) {
    switch (type) {
      case 'crowd_alert':
        return '🔴';
      case 'pioneer':
        return '🏅';
      case 'follow':
        return '👤';
      case 'like':
        return '💬';
      case 'deal':
        return '🎟️';
      default:
        return '🔔';
    }
  }

  static Color _iconBg(String? type) {
    switch (type) {
      case 'crowd_alert':
        return const Color(0xFFFFEBEE);
      case 'pioneer':
        return const Color(0xFFFFF8E1);
      case 'follow':
        return const Color(0xFFE3F2FD);
      case 'like':
        return const Color(0xFFF3E5F5);
      case 'deal':
        return const Color(0xFFE8F5E9);
      default:
        return const Color(0xFFFFF3E0);
    }
  }

  // ── Timestamp ─────────────────────────────────────────────────────────────────
  static String _relativeTime(dynamic ts) {
    if (ts == null) return '';
    final DateTime dt =
        ts is Timestamp ? ts.toDate() : DateTime.now();
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  }

  // ── Actions ───────────────────────────────────────────────────────────────────
  static Future<void> _markOneRead(String uid, String docId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .doc(docId)
        .update({'isRead': true});
  }

  static Future<void> _markAllRead(String uid) async {
    final query = await FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .where('isRead', isEqualTo: false)
        .limit(50)
        .get();
    if (query.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  static Future<void> _onTap(
    BuildContext context,
    String uid,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _markOneRead(uid, docId);
    } catch (e) {
      debugPrint('NotificationsScreen._markOneRead error: $e');
    }

    final type = data['type'] as String? ?? '';
    final relatedId = data['relatedId'] as String? ?? '';

    switch (type) {
      case 'crowd_alert':
        Navigator.pushNamed(
          context,
          '/venue',
          arguments: <String, dynamic>{'locationName': relatedId},
        );
      case 'pioneer':
        Navigator.pushNamed(context, '/pioneers');
      case 'follow':
        Navigator.pushNamed(
          context,
          '/user_profile',
          arguments: relatedId,
        );
      case 'like':
        Navigator.pushNamed(context, '/feed');
      case 'deal':
        Navigator.pushNamed(context, '/deals');
      default:
        break; // 'push' — just mark read, stay on screen
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return _buildUnauthenticated(context);
    }

    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Column(
        children: [
          _buildHeader(context, topPad, uid),
          Expanded(child: _buildList(context, uid)),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, double topPad, String uid) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF2244EE),
          padding: EdgeInsets.fromLTRB(0, topPad + 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _markAllRead(uid),
                child: Text(
                  'Mark all read',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          color: const Color(0xFF1535C8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: const Text(
            'Your recent activity',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  // ── Stream list ───────────────────────────────────────────────────────────────
  Widget _buildList(BuildContext context, String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Failed to load notifications'),
                TextButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmptyState();

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildRow(context, uid, doc.id, data);
          },
        );
      },
    );
  }

  // ── Notification row ──────────────────────────────────────────────────────────
  Widget _buildRow(
    BuildContext context,
    String uid,
    String docId,
    Map<String, dynamic> data,
  ) {
    final isRead = data['isRead'] as bool? ?? true;
    final type = data['type'] as String? ?? 'push';
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final timestamp = data['timestamp'];

    return GestureDetector(
      onTap: () => _onTap(context, uid, docId, data),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: isRead ? Colors.white : const Color(0xFFF0F4FF),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            _buildIconCircle(type),
            const SizedBox(width: 12),

            // Title + body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Timestamp + unread dot
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _relativeTime(timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
                if (!isRead) ...[
                  const SizedBox(height: 5),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2244EE),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconCircle(String type) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: _iconBg(type),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _emoji(type),
          style: const TextStyle(fontSize: 17),
        ),
      ),
    );
  }

  // ── Empty / unauth states ─────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔔', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 14),
            const Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "We'll notify you when something happens at your favourite spots.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnauthenticated(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2244EE),
        title: const Text('Notifications',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(child: Text('Please log in to see notifications.')),
    );
  }
}
