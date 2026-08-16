import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/peepl_app_tokens.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  /// Unread count from the latest 50 inbox items (for bottom-nav badge).
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
              .where((doc) => !_NotificationsScreenState.isNotificationRead(
                    doc.data(),
                  ))
              .length,
        );
  }

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _kUnreadBg = Color(0xFFE3F2FD);
  static const _kSectionOrder = [
    'post_liked',
    'crowdsource_request',
    'new_post_nearby',
  ];

  /// Mirrors [NotificationService._canonicalNotificationType] — kept inline to
  /// avoid a shared-file scope expansion.
  static String _canonicalNotificationType(dynamic rawType) {
    final t = (rawType ?? '').toString().trim().toLowerCase();
    switch (t) {
      case 'like':
      case 'post_like':
      case 'post_liked':
        return 'post_liked';
      default:
        return t;
    }
  }

  /// Resolves a post id from inbox or FCM payload field name variants.
  /// [_persistNotification] stores the FCM postId in [relatedId].
  static String _resolvedPostId(Map<String, dynamic> data) {
    final id =
        data['postId'] ?? data['post_id'] ?? data['id'] ?? data['relatedId'];
    return id?.toString().trim() ?? '';
  }

  static bool isNotificationRead(Map<String, dynamic> data) {
    if (data.containsKey('read')) {
      final value = data['read'];
      if (value is bool) return value;
      return true;
    }
    if (data.containsKey('isRead')) {
      final value = data['isRead'];
      if (value is bool) return value;
      return true;
    }
    return false;
  }

  static String _relativeTime(dynamic ts) {
    if (ts == null) return '';
    final DateTime dt = ts is Timestamp
        ? ts.toDate()
        : ts is DateTime
            ? ts
            : DateTime.fromMillisecondsSinceEpoch(0);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';

    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';

    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  static String _sectionTitle(String type) {
    switch (type) {
      case 'post_liked':
        return 'Likes';
      case 'crowdsource_request':
        return 'Crowd requests';
      case 'new_post_nearby':
        return 'Nearby posts';
      default:
        return 'Other';
    }
  }

  static String _messageForType(String type, Map<String, dynamic> data) {
    final persistedBody = data['body']?.toString().trim() ?? '';
    final locationName = data['locationName'] as String? ?? 'a location';
    switch (type) {
      case 'post_liked':
        if (persistedBody.isNotEmpty) return persistedBody;
        final username = data['username'] as String? ?? 'Someone';
        return '$username liked your post at $locationName';
      case 'crowdsource_request':
        if (persistedBody.isNotEmpty) return persistedBody;
        return 'Someone wants to know about $locationName — can you help?';
      case 'new_post_nearby':
        if (persistedBody.isNotEmpty) return persistedBody;
        return 'New post near you at $locationName';
      default:
        final title = data['title'] as String? ?? '';
        return persistedBody.isNotEmpty ? persistedBody : title;
    }
  }

  static Widget _iconForType(String type) {
    switch (type) {
      case 'post_liked':
        return const Icon(Icons.favorite, color: Colors.red, size: 22);
      case 'crowdsource_request':
        return const Icon(Icons.help_outline, color: Colors.blue, size: 22);
      case 'new_post_nearby':
        return const Icon(Icons.location_on, color: Colors.green, size: 22);
      default:
        return Icon(Icons.notifications, color: PeeplAppTokens.textSecondary, size: 22);
    }
  }

  static Color _iconBgForType(String type) {
    switch (type) {
      case 'post_liked':
        return const Color(0xFFFFEBEE);
      case 'crowdsource_request':
        return const Color(0xFFE3F2FD);
      case 'new_post_nearby':
        return const Color(0xFFE8F5E9);
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  Future<void> _markOneRead(String uid, String docId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .doc(docId)
        .update({'read': true, 'isRead': true});
  }

  Future<void> _markAllRead(String uid) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final unread = query.docs
          .where((doc) => !isNotificationRead(doc.data()))
          .toList();
      if (unread.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unread) {
        batch.update(doc.reference, {'read': true, 'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('NotificationsScreen._markAllRead error: $e');
    }
  }

  Future<void> _navigateToPost(BuildContext context, String postId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('location_posts')
          .doc(postId)
          .get();
      if (!context.mounted) return;
      if (!snap.exists) {
        Navigator.pushNamed(context, '/feed');
        return;
      }
      final postData = <String, dynamic>{'id': snap.id, ...?snap.data()};
      Navigator.pushNamed(context, '/peep_detail', arguments: postData);
    } catch (e) {
      debugPrint('NotificationsScreen._navigateToPost error: $e');
      if (context.mounted) Navigator.pushNamed(context, '/feed');
    }
  }

  Future<void> _onTap(
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

    if (!context.mounted) return;

    final type = _canonicalNotificationType(data['type']);
    switch (type) {
      case 'post_liked':
      case 'new_post_nearby':
        final postId = _resolvedPostId(data);
        if (postId.isNotEmpty) {
          await _navigateToPost(context, postId);
        } else {
          Navigator.pushNamed(context, '/feed');
        }
        break;
      case 'crowdsource_request':
        final lat = double.tryParse(data['latitude']?.toString() ?? '');
        final lng = double.tryParse(data['longitude']?.toString() ?? '');
        Navigator.pushNamed(
          context,
          '/post',
          arguments: <String, dynamic>{
            'locationName': data['locationName'] as String? ?? '',
            if (lat != null) 'latitude': lat,
            if (lng != null) 'longitude': lng,
          },
        );
        break;
      case 'crowdsource_response':
        final responsePostId = _resolvedPostId(data);
        if (responsePostId.isNotEmpty) {
          await _navigateToPost(context, responsePostId);
        } else {
          Navigator.pushNamed(context, '/feed');
        }
        break;
      case 'walk_in_prompt':
        final walkLat = double.tryParse(data['latitude']?.toString() ?? '');
        final walkLng = double.tryParse(data['longitude']?.toString() ?? '');
        Navigator.pushNamed(
          context,
          '/post',
          arguments: <String, dynamic>{
            'locationName': data['locationName'] as String? ??
                data['venueName'] as String? ??
                '',
            if (walkLat != null) 'latitude': walkLat,
            if (walkLng != null) 'longitude': walkLng,
          },
        );
        break;
      case 'crowd_change_alert':
        final alertPostId = _resolvedPostId(data);
        if (alertPostId.isNotEmpty) {
          await _navigateToPost(context, alertPostId);
        } else {
          Navigator.pushNamed(context, '/feed');
        }
        break;
      default:
        break;
    }
  }

  Map<String, List<QueryDocumentSnapshot>> _groupByType(
    List<QueryDocumentSnapshot> docs,
  ) {
    final grouped = <String, List<QueryDocumentSnapshot>>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final type = _canonicalNotificationType(data['type']);
      final key = type.isEmpty ? 'other' : type;
      grouped.putIfAbsent(key, () => []).add(doc);
    }
    return grouped;
  }

  List<String> _orderedSectionKeys(Map<String, List<QueryDocumentSnapshot>> grouped) {
    final keys = <String>[];
    for (final type in _kSectionOrder) {
      if (grouped.containsKey(type)) keys.add(type);
    }
    for (final type in grouped.keys) {
      if (!_kSectionOrder.contains(type)) keys.add(type);
    }
    return keys;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(
          child: Text('Please log in to see notifications.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: PeeplAppTokens.background,
      appBar: AppBar(
        backgroundColor: PeeplAppTokens.background,
        foregroundColor: PeeplAppTokens.textPrimary,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(uid),
            child: const Text(
              'Mark all as read',
              style: TextStyle(
                color: PeeplAppTokens.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _buildList(context, uid),
    );
  }

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

        final grouped = _groupByType(docs);
        final sectionKeys = _orderedSectionKeys(grouped);

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: sectionKeys.length,
          itemBuilder: (context, sectionIndex) {
            final type = sectionKeys[sectionIndex];
            final sectionDocs = grouped[type]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    _sectionTitle(type),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: PeeplAppTokens.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                ...sectionDocs.map(
                  (doc) {
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    return _buildRow(context, uid, doc.id, data);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRow(
    BuildContext context,
    String uid,
    String docId,
    Map<String, dynamic> data,
  ) {
    final isRead = isNotificationRead(data);
    final type = _canonicalNotificationType(data['type']);
    final displayType = type.isEmpty ? 'other' : type;
    final message = _messageForType(displayType, data);
    final timestamp = data['timestamp'];

    return Material(
      color: isRead ? Colors.white : _kUnreadBg,
      child: InkWell(
        onTap: () => _onTap(context, uid, docId, data),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _iconBgForType(displayType),
                  shape: BoxShape.circle,
                ),
                child: Center(child: _iconForType(displayType)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                    color: const Color(0xFF1A1A1A),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _relativeTime(timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: PeeplAppTokens.card0,
                    ),
                  ),
                  if (!isRead) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: PeeplAppTokens.background,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 56,
              color: PeeplAppTokens.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "We'll notify you when something happens near your favourite spots.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: PeeplAppTokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
