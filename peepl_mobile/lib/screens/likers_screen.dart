import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LikersScreen extends StatefulWidget {
  /// Optional: supply [postId] directly; otherwise resolved from route args.
  final String? postId;

  const LikersScreen({super.key, this.postId});

  @override
  State<LikersScreen> createState() => _LikersScreenState();
}

class _LikersScreenState extends State<LikersScreen> {
  String _postId = '';
  bool _didInit = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────────
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _postId = widget.postId ??
          (ModalRoute.of(context)?.settings.arguments as String?) ??
          '';
      setState(() {}); // trigger rebuild with resolved postId
    }
  }

  // ── Avatar helpers ────────────────────────────────────────────────────────────
  static Color _avatarColor(String username) {
    const colors = [
      Color(0xFF1565C0),
      Color(0xFF388E3C),
      Color(0xFFBF360C),
      Color(0xFF6A1B9A),
      Color(0xFF00695C),
      Color(0xFF558B2F),
      Color(0xFF283593),
      Color(0xFF4E342E),
    ];
    if (username.isEmpty) return colors[0];
    return colors[username.codeUnitAt(0) % colors.length];
  }

  static String _initial(String username) =>
      username.isNotEmpty ? username[0].toUpperCase() : '?';

  static String _relativeTime(dynamic ts) {
    if (ts == null) return '';
    final DateTime dt = ts is Timestamp ? ts.toDate() : DateTime.now();
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Column(
        children: [
          _buildHeader(topPad),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(double topPad) {
    return Container(
      color: const Color(0xFF2244EE),
      padding: EdgeInsets.fromLTRB(0, topPad + 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Liked by',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_postId.isEmpty) {
      return const Center(child: Text('No post ID provided.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('location_posts')
          .doc(_postId)
          .collection('likes')
          .orderBy('likedAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmptyState();

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            indent: 68,
            endIndent: 16,
          ),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final userId = doc.id;
            final likeData = doc.data() as Map<String, dynamic>;
            return _LikerRow(
              userId: userId,
              likeTimestamp: likeData['likedAt'],
              onTap: () => Navigator.pushNamed(
                context,
                '/user_profile',
                arguments: {'userId': userId},
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('❤️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 14),
            const Text(
              'No likes yet',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 6),
            Text(
              'Be the first to like this Peep!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Single liker row ─────────────────────────────────────────────────────────
// Fetches the username from users/{userId} and renders the row.

class _LikerRow extends StatefulWidget {
  final String userId;
  final dynamic likeTimestamp;
  final VoidCallback onTap;

  const _LikerRow({
    required this.userId,
    required this.likeTimestamp,
    required this.onTap,
  });

  @override
  State<_LikerRow> createState() => _LikerRowState();
}

class _LikerRowState extends State<_LikerRow> {
  String _username = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _fetchUsername();
  }

  Future<void> _fetchUsername() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final name = (doc.data()?['username'] as String?) ??
          (doc.data()?['displayName'] as String?) ??
          'Unknown';
      if (mounted) setState(() {
        _username = name;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() {
        _username = 'Unknown';
        _loaded = true;
      });
    }
  }

  static Color _avatarColor(String u) {
    const colors = [
      Color(0xFF1565C0),
      Color(0xFF388E3C),
      Color(0xFFBF360C),
      Color(0xFF6A1B9A),
      Color(0xFF00695C),
      Color(0xFF558B2F),
      Color(0xFF283593),
      Color(0xFF4E342E),
    ];
    if (u.isEmpty) return colors[0];
    return colors[u.codeUnitAt(0) % colors.length];
  }

  static String _relativeTime(dynamic ts) {
    if (ts == null) return '';
    final DateTime dt = ts is Timestamp ? ts.toDate() : DateTime.now();
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircleAvatar(backgroundColor: Color(0xFFE0E0E0)),
            ),
            SizedBox(width: 12),
            SizedBox(
              width: 120,
              height: 12,
              child: ColoredBox(color: Color(0xFFE0E0E0)),
            ),
          ],
        ),
      );
    }

    final initial =
        _username.isNotEmpty ? _username[0].toUpperCase() : '?';
    final bgColor = _avatarColor(_username);
    final timeLabel = _relativeTime(widget.likeTimestamp);

    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar circle
            CircleAvatar(
              radius: 20,
              backgroundColor: bgColor,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Username
            Expanded(
              child: Text(
                _username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            // Timestamp
            if (timeLabel.isNotEmpty)
              Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios,
                size: 12, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
