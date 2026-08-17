import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/peepl_app_tokens.dart';

import '../services/feed_service.dart';
import '../utils/post_crowd_format.dart';
import '../utils/post_delete_actions.dart';
import '../widgets/crowd_meter.dart';
import '../widgets/resolved_venue_name.dart';
import 'location_detail_screen.dart';

enum _DateFilter { all, thisWeek, thisMonth }

class MyPeepsScreen extends StatefulWidget {
  /// Pass a [userId] to view another user's peeps; null = currentUser.
  const MyPeepsScreen({super.key, this.userId});

  final String? userId;

  @override
  State<MyPeepsScreen> createState() => _MyPeepsScreenState();
}

class _MyPeepsScreenState extends State<MyPeepsScreen> {
  final _db = FirebaseFirestore.instance;
  final _feedService = FeedService();
  String? _username;
  _DateFilter _dateFilter = _DateFilter.all;

  String get _uid =>
      widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _isOwn =>
      widget.userId == null ||
      widget.userId == FirebaseAuth.instance.currentUser?.uid;

  static const TextStyle _overlayShadow = TextStyle(
    color: PeeplAppTokens.textPrimary,
    shadows: [
      Shadow(offset: Offset(0, 1), blurRadius: 6, color: PeeplAppTokens.textPrimary),
    ],
  );

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    if (_uid.isEmpty) return;
    try {
      final doc = await _db.collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3').doc(_uid).get();
      final name = (doc.data()?['username'] as String?) ??
          (doc.data()?['displayName'] as String?) ??
          'User';
      if (mounted) setState(() => _username = name);
    } catch (_) {}
  }

  bool _matchesDateFilter(dynamic timestamp) {
    if (_dateFilter == _DateFilter.all) return true;
    if (timestamp is! Timestamp) return false;

    final postDate = timestamp.toDate();
    final now = DateTime.now();

    if (_dateFilter == _DateFilter.thisWeek) {
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      return !postDate.isBefore(weekStart);
    }

    final monthStart = DateTime(now.year, now.month, 1);
    return !postDate.isBefore(monthStart);
  }

  _PostStats _computeStats(List<QueryDocumentSnapshot> docs) {
    var totalLikes = 0;
    final locations = <String>{};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalLikes += (data['likesCount'] as num?)?.toInt() ?? 0;
      final name = data['locationName'] as String?;
      if (name != null && name.trim().isNotEmpty) {
        locations.add(name.trim());
      }
    }

    return _PostStats(
      totalPosts: docs.length,
      totalLikes: totalLikes,
      locationsVisited: locations.length,
    );
  }

  List<QueryDocumentSnapshot> _filteredDocs(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return _matchesDateFilter(data['timestamp']);
    }).toList();
  }

  Future<void> _confirmDelete(String docId, String locationName) async {
    await confirmAndDeletePost(
      context,
      _feedService,
      postId: docId,
      locationName: locationName,
    );
  }

  static String _timeAgo(dynamic ts) {
    if (ts == null) return '';
    if (ts is! Timestamp) return '';
    final dt = ts.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.month}/${d.day}/${d.year}';
    }
    if (ts is DateTime) {
      return '${ts.month}/${ts.day}/${ts.year}';
    }
    return '—';
  }

  String _overlayCrowdDetailLine(Map<String, dynamic> post) {
    final parts = <String>[];
    final mf = PostCrowdFormat.maleFemaleLine(post['maleFemaleRatio']);
    if (mf != null) parts.add(mf);
    final ak = PostCrowdFormat.adultKidLine(post['adultKidRatio']);
    if (ak != null) parts.add(ak);
    final age = post['ageRange']?.toString().trim();
    if (age != null && age.isNotEmpty) parts.add(age);
    return parts.join(' · ');
  }

  int _crowdLevel(Map<String, dynamic> post) {
    return (post['crowdingLevel'] as num?)?.toInt() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final name = _username ?? 'User';
    final title = _isOwn ? 'My Peeps' : "$name's Peeps";

    return Scaffold(
      backgroundColor: PeeplAppTokens.background,
      appBar: AppBar(
        backgroundColor: PeeplAppTokens.shellNavy,
        foregroundColor: PeeplAppTokens.textPrimary,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _uid.isEmpty
          ? const Center(child: Text('Please sign in to view posts.'))
          : _buildBody(context, name),
    );
  }

  Widget _buildBody(BuildContext context, String name) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('location_posts')
          .where('userId', isEqualTo: _uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Failed to load posts'),
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

        final allDocs = snap.data?.docs ?? [];
        final stats = _computeStats(allDocs);
        final filteredDocs = _filteredDocs(allDocs);

        if (allDocs.isEmpty) {
          return _buildEmptyState(context);
        }

        return Column(
          children: [
            _buildStatsBar(stats),
            _buildFilterChips(),
            Expanded(
              child: filteredDocs.isEmpty
                  ? _buildFilteredEmptyState()
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: filteredDocs.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final post = {
                          'id': doc.id,
                          ...doc.data() as Map<String, dynamic>,
                        };
                        return _buildLocationCard(context, post);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsBar(_PostStats stats) {
    return Container(
      width: double.infinity,
      color: PeeplAppTokens.textPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          _buildStatItem('Total Posts', stats.totalPosts),
          _buildStatDivider(),
          _buildStatItem('Total Likes', stats.totalLikes),
          _buildStatDivider(),
          _buildStatItem('Locations visited', stats.locationsVisited),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: PeeplAppTokens.accentBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: PeeplAppTokens.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildFilterChips() {
    return Container(
      width: double.infinity,
      color: PeeplAppTokens.textPrimary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        children: [
          _filterChip('All', _DateFilter.all),
          _filterChip('This Week', _DateFilter.thisWeek),
          _filterChip('This Month', _DateFilter.thisMonth),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _DateFilter filter) {
    final selected = _dateFilter == filter;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _dateFilter = filter),
      selectedColor: const Color(0xFFE3F2FD),
      checkmarkColor: PeeplAppTokens.accentBlue,
      labelStyle: TextStyle(
        color: selected ? PeeplAppTokens.accentBlue : Colors.grey.shade700,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected ? PeeplAppTokens.accentBlue : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context, Map<String, dynamic> post) {
    final crowdingLevel = _crowdLevel(post);
    final w = MediaQuery.sizeOf(context).width;
    final cardHeight = w * 0.19;
    final docId = post['id'] as String? ?? '';
    final locationName = post['locationName'] as String? ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => LocationDetailScreen(postData: post),
        ),
      ),
      onLongPress: _isOwn && docId.isNotEmpty
          ? () => _confirmDelete(docId, locationName)
          : null,
      child: SizedBox(
        width: double.infinity,
        height: cardHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              post['imageUrl']?.toString() ??
                  'https://via.placeholder.com/400x400',
              fit: BoxFit.cover,
              width: double.infinity,
              height: cardHeight,
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: PeeplAppTokens.textSecondary,
                child: const Icon(Icons.place, color: Colors.white54, size: 40),
              ),
            ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ResolvedVenueName(
                              post: post,
                              fallback: 'Unknown',
                              style: _overlayShadow.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              post['username']?.toString() ?? 'You',
                              style: _overlayShadow.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatDate(post['timestamp'])} · ${_timeAgo(post['timestamp'])}',
                              style: _overlayShadow.copyWith(
                                fontSize: 8,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                            if (_overlayCrowdDetailLine(post).isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                _overlayCrowdDetailLine(post),
                                style: _overlayShadow.copyWith(
                                  fontSize: 7,
                                  color: Colors.white.withValues(alpha: 0.92),
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      CrowdMeter(level: crowdingLevel, size: 60),
                      if (_isOwn && docId.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Material(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 18,
                            ),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            tooltip: 'Delete post',
                            onPressed: () =>
                                _confirmDelete(docId, locationName),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_location_alt_outlined,
                size: 56, color: PeeplAppTokens.textMuted),
            const SizedBox(height: 16),
            const Text(
              "You haven't posted yet! Tap POST to share your first crowd report.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/post'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PeeplAppTokens.shellNavy,
                foregroundColor: PeeplAppTokens.textPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'POST',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyState() {
    final label = switch (_dateFilter) {
      _DateFilter.thisWeek => 'this week',
      _DateFilter.thisMonth => 'this month',
      _DateFilter.all => '',
    };

    return Center(
      child: Text(
        'No posts $label',
        style: TextStyle(fontSize: 15, color: PeeplAppTokens.textSecondary),
      ),
    );
  }
}

class _PostStats {
  const _PostStats({
    required this.totalPosts,
    required this.totalLikes,
    required this.locationsVisited,
  });

  final int totalPosts;
  final int totalLikes;
  final int locationsVisited;
}
