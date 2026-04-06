import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/crowd_dot_ring_meter.dart';

class MyPeepsScreen extends StatefulWidget {
  /// Pass a [userId] to view another user's peeps; null = currentUser.
  const MyPeepsScreen({super.key, this.userId});

  final String? userId;

  @override
  State<MyPeepsScreen> createState() => _MyPeepsScreenState();
}

class _MyPeepsScreenState extends State<MyPeepsScreen> {
  final _db = FirebaseFirestore.instance;
  String? _username;

  String get _uid =>
      widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _isOwn =>
      widget.userId == null ||
      widget.userId == FirebaseAuth.instance.currentUser?.uid;

  // ── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    if (_uid.isEmpty) return;
    try {
      final doc = await _db.collection('users').doc(_uid).get();
      final name = (doc.data()?['username'] as String?) ??
          (doc.data()?['displayName'] as String?) ??
          'User';
      if (mounted) setState(() => _username = name);
    } catch (_) {}
  }

  // ── colour helpers ───────────────────────────────────────────────────────

  static const List<List<Color>> _gs = [
    [Color(0xFF1565C0), Color(0xFF0D47A1)],
    [Color(0xFF2E7D32), Color(0xFF1B5E20)],
    [Color(0xFF4527A0), Color(0xFF311B92)],
    [Color(0xFF00695C), Color(0xFF004D40)],
    [Color(0xFFBF360C), Color(0xFF7F0000)],
  ];

  List<Color> _gradient(String name) =>
      _gs[name.isNotEmpty ? name.codeUnitAt(0) % _gs.length : 0];

  static const TextStyle _shadow = TextStyle(
    color: Colors.white,
    shadows: [
      Shadow(offset: Offset(0, 1), blurRadius: 6, color: Colors.black87),
    ],
  );

  // ── time helper ──────────────────────────────────────────────────────────

  static String _timeAgo(dynamic ts) {
    if (ts == null) return '';
    if (ts is! Timestamp) return '';
    final dt = ts.toDate();
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final name = _username ?? 'User';
    final g = _gradient(name);
    final title = _isOwn ? 'My Peeps' : "${name}'s Peeps";
    final sectionLabel =
        _isOwn ? 'My History — Peeps Place' : "${name}'s History";

    return Scaffold(
      backgroundColor: g[0],
      body: SafeArea(
        child: Column(
          children: [
            _buildBanner(context, name, g, title),
            _buildSectionHeader(sectionLabel),
            Expanded(
              child: _uid.isEmpty
                  ? const Center(
                      child: Text('Not signed in',
                          style: TextStyle(color: Colors.white)))
                  : _buildStream(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── BANNER ───────────────────────────────────────────────────────────────

  Widget _buildBanner(
      BuildContext ctx, String name, List<Color> g, String title) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: g,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF00BCD4).withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ── STREAM ───────────────────────────────────────────────────────────────

  Widget _buildStream(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('location_posts')
          .where('userId', isEqualTo: _uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👀', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 12),
                const Text(
                  'No Peeps yet — go explore!',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                if (_isOwn) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/post'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Peep Now →'),
                  ),
                ],
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0x33FFFFFF)),
            itemBuilder: (_, i) {
              final post = {
                ...docs[i].data() as Map<String, dynamic>,
                'id': docs[i].id,
              };
              return _buildCard(context, post);
            },
          ),
        );
      },
    );
  }

  // ── FEED CARD — identical style to FeedScreen._buildLocationCard ─────────

  Widget _buildCard(BuildContext ctx, Map<String, dynamic> post) {
    final level = (post['crowdingLevel'] as num?)?.toInt() ?? 0;
    final w = MediaQuery.sizeOf(ctx).width;
    final h = w * 0.19;

    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(ctx, '/peep_detail', arguments: post),
      child: SizedBox(
        width: double.infinity,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            post['imageUrl'] != null &&
                    (post['imageUrl'] as String).isNotEmpty
                ? Image.network(
                    post['imageUrl'] as String,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.grey[800]),
                  )
                : Container(color: Colors.grey[800]),

            // Gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0, 0.35, 1],
                ),
              ),
            ),

            // Text overlay
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['locationName']?.toString() ?? 'Unknown',
                          style: _shadow.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _timeAgo(post['timestamp']),
                          style: _shadow.copyWith(
                            fontSize: 9,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CrowdDotRingMeter(level: level, size: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
