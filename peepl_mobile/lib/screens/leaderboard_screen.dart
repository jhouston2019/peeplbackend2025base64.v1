import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _kUsersCollection = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

enum _Period { week, month, allTime }

class _LeaderEntry {
  final String userId;
  final int postCount;
  final int totalLikes;
  final int uniqueLocations;
  String displayName;
  String username;
  String? photoUrl;
  bool isVIP;

  _LeaderEntry({
    required this.userId,
    required this.postCount,
    required this.totalLikes,
    required this.uniqueLocations,
    this.displayName = 'User',
    this.username = '',
    this.photoUrl,
    this.isVIP = false,
  });

  int get score => totalLikes;
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  late TabController _tabController;
  String _currentUid = '';

  final Map<_Period, List<_LeaderEntry>> _cache = {};
  final Map<_Period, bool> _loading = {};
  final Map<_Period, String?> _errors = {};

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadPeriod(_Period.week);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _loadPeriod(_periodForIndex(_tabController.index));
  }

  _Period _periodForIndex(int index) {
    switch (index) {
      case 1:
        return _Period.month;
      case 2:
        return _Period.allTime;
      default:
        return _Period.week;
    }
  }

  DateTime? _cutoffFor(_Period period) {
    final now = DateTime.now();
    switch (period) {
      case _Period.week:
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
      case _Period.month:
        return DateTime(now.year, now.month, 1);
      case _Period.allTime:
        return null;
    }
  }

  Future<void> _loadPeriod(_Period period) async {
    if (_loading[period] == true) return;
    setState(() {
      _loading[period] = true;
      _errors[period] = null;
    });

    try {
      final cutoff = _cutoffFor(period);
      Query<Map<String, dynamic>> query =
          _db.collection('location_posts');

      if (cutoff != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff),
        );
      }

      final snap = await query.limit(3000).get();
      final aggregated = _aggregatePosts(snap.docs);
      aggregated.sort((a, b) {
        final likes = b.totalLikes.compareTo(a.totalLikes);
        if (likes != 0) return likes;
        final posts = b.postCount.compareTo(a.postCount);
        if (posts != 0) return posts;
        return b.uniqueLocations.compareTo(a.uniqueLocations);
      });

      final topIds = aggregated.take(20).map((e) => e.userId).toSet();
      if (_currentUid.isNotEmpty) topIds.add(_currentUid);

      await _hydrateUsers(aggregated.where((e) => topIds.contains(e.userId)).toList());

      if (mounted) {
        setState(() {
          _cache[period] = aggregated;
          _loading[period] = false;
        });
      }
    } catch (e) {
      debugPrint('LeaderboardScreen._loadPeriod: $e');
      if (mounted) {
        setState(() {
          _errors[period] = e.toString();
          _loading[period] = false;
        });
      }
    }
  }

  List<_LeaderEntry> _aggregatePosts(List<QueryDocumentSnapshot> docs) {
    final byUser = <String, _LeaderEntry>{};
    final locationsByUser = <String, Set<String>>{};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final uid = data['userId'] as String? ?? '';
      if (uid.isEmpty) continue;

      locationsByUser.putIfAbsent(uid, () => {});
      final location = data['locationName'] as String? ?? '';
      if (location.isNotEmpty) locationsByUser[uid]!.add(location);

      final likes = (data['likesCount'] as num?)?.toInt() ?? 0;
      final existing = byUser[uid];
      if (existing == null) {
        byUser[uid] = _LeaderEntry(
          userId: uid,
          postCount: 1,
          totalLikes: likes,
          uniqueLocations: 0,
        );
      } else {
        byUser[uid] = _LeaderEntry(
          userId: uid,
          postCount: existing.postCount + 1,
          totalLikes: existing.totalLikes + likes,
          uniqueLocations: existing.uniqueLocations,
          displayName: existing.displayName,
          username: existing.username,
          photoUrl: existing.photoUrl,
          isVIP: existing.isVIP,
        );
      }
    }

    for (final uid in byUser.keys) {
      final entry = byUser[uid]!;
      byUser[uid] = _LeaderEntry(
        userId: entry.userId,
        postCount: entry.postCount,
        totalLikes: entry.totalLikes,
        uniqueLocations: locationsByUser[uid]?.length ?? 0,
        displayName: entry.displayName,
        username: entry.username,
        photoUrl: entry.photoUrl,
        isVIP: entry.isVIP,
      );
    }

    return byUser.values.toList();
  }

  Future<void> _hydrateUsers(List<_LeaderEntry> entries) async {
    await Future.wait(entries.map((entry) async {
      try {
        final doc =
            await _db.collection(_kUsersCollection).doc(entry.userId).get();
        final data = doc.data() ?? {};
        entry.displayName = (data['displayName'] as String?) ??
            (data['name'] as String?) ??
            entry.displayName;
        entry.username = (data['username'] as String?) ?? entry.username;
        entry.photoUrl = data['photoUrl'] as String?;
        entry.isVIP = data['isVIPeep'] as bool? ?? false;
      } catch (_) {}
    }));
  }

  int? _rankOf(List<_LeaderEntry> all, String uid) {
    final index = all.indexWhere((e) => e.userId == uid);
    return index >= 0 ? index + 1 : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(child: _buildTabViews()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Text(
            'Leaderboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Scoreboard',
            onPressed: () => Navigator.pushNamed(context, '/scoreboard'),
            icon: const Icon(Icons.scoreboard_outlined, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Material(
      color: const Color(0xFF1565C0),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'This Week'),
          Tab(text: 'This Month'),
          Tab(text: 'All Time'),
        ],
      ),
    );
  }

  Widget _buildTabViews() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildPeriodBody(_Period.week),
          _buildPeriodBody(_Period.month),
          _buildPeriodBody(_Period.allTime),
        ],
      ),
    );
  }

  Widget _buildPeriodBody(_Period period) {
    final loading = _loading[period] == true;
    final error = _errors[period];
    final all = _cache[period] ?? [];

    if (loading && all.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && all.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load leaderboard', style: TextStyle(color: Colors.grey[600])),
            TextButton(
              onPressed: () => _loadPeriod(period),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'No activity yet for this period',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    final top20 = all.take(20).toList();
    final top3 = top20.length >= 3 ? top20.take(3).toList() : <_LeaderEntry>[];
    final rest = top20.length >= 3 ? top20.skip(3).toList() : top20;

    final myRank = _currentUid.isNotEmpty ? _rankOf(all, _currentUid) : null;
    _LeaderEntry? myEntry;
    if (_currentUid.isNotEmpty) {
      for (final e in all) {
        if (e.userId == _currentUid) {
          myEntry = e;
          break;
        }
      }
    }
    final showMyFooter =
        myEntry != null && myRank != null && myRank > 20;
    final footerEntry = myEntry;
    final footerRank = myRank;

    return RefreshIndicator(
      onRefresh: () => _loadPeriod(period),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (top3.length >= 3)
            SliverToBoxAdapter(
              child: _Podium(
                top3: top3,
                currentUid: _currentUid,
                onTap: _openProfile,
              ),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final rank = (top3.length >= 3 ? 3 : 0) + index + 1;
                final entry = rest[index];
                return _RankRow(
                  rank: rank,
                  entry: entry,
                  isMe: entry.userId == _currentUid,
                  onTap: () => _openProfile(entry.userId),
                );
              },
              childCount: rest.length,
            ),
          ),
          if (showMyFooter)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(height: 1, color: Colors.grey.shade300),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Your rank',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  _RankRow(
                    rank: footerRank!,
                    entry: footerEntry!,
                    isMe: true,
                    onTap: () => _openProfile(footerEntry.userId),
                  ),
                ],
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  void _openProfile(String userId) {
    Navigator.pushNamed(context, '/user_profile', arguments: userId);
  }
}

class _Podium extends StatelessWidget {
  const _Podium({
    required this.top3,
    required this.currentUid,
    required this.onTap,
  });

  final List<_LeaderEntry> top3;
  final String currentUid;
  final void Function(String userId) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FF),
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _PodiumPlace(
            rank: 2,
            entry: top3[1],
            stepHeight: 60,
            avatarRadius: 28,
            isMe: top3[1].userId == currentUid,
            onTap: () => onTap(top3[1].userId),
          ),
          _PodiumPlace(
            rank: 1,
            entry: top3[0],
            stepHeight: 90,
            avatarRadius: 36,
            goldBorder: true,
            isMe: top3[0].userId == currentUid,
            onTap: () => onTap(top3[0].userId),
          ),
          _PodiumPlace(
            rank: 3,
            entry: top3[2],
            stepHeight: 42,
            avatarRadius: 24,
            isMe: top3[2].userId == currentUid,
            onTap: () => onTap(top3[2].userId),
          ),
        ],
      ),
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({
    required this.rank,
    required this.entry,
    required this.stepHeight,
    required this.avatarRadius,
    required this.isMe,
    required this.onTap,
    this.goldBorder = false,
  });

  final int rank;
  final _LeaderEntry entry;
  final double stepHeight;
  final double avatarRadius;
  final bool isMe;
  final VoidCallback onTap;
  final bool goldBorder;

  static Color _stepColor(int r) {
    if (r == 1) return const Color(0xFFFFD700);
    if (r == 2) return const Color(0xFFB0BEC5);
    return const Color(0xFFCD7F32);
  }

  static Color _rankColor(int r) {
    if (r == 1) return const Color(0xFFFFD700);
    if (r == 2) return const Color(0xFF9E9E9E);
    return const Color(0xFFCD7F32);
  }

  @override
  Widget build(BuildContext context) {
    final name = entry.displayName.isNotEmpty
        ? entry.displayName
        : entry.username.isNotEmpty
            ? entry.username
            : 'User';
    final width = rank == 1 ? 100.0 : 82.0;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$rank',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: rank == 1 ? 16 : 14,
              color: _rankColor(rank),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: goldBorder
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFD700), width: 3),
                  )
                : null,
            child: _LeaderAvatar(
              entry: entry,
              radius: avatarRadius,
              isMe: isMe,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: width,
            child: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: rank == 1 ? 13 : 11,
                color: isMe ? const Color(0xFF1565C0) : Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (entry.isVIP)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text('⭐ VIP', style: TextStyle(fontSize: 9)),
            ),
          const SizedBox(height: 4),
          _StatChips(
            entry: entry,
            compact: true,
          ),
          const SizedBox(height: 6),
          Container(
            width: rank == 1 ? 88 : 72,
            height: stepHeight,
            decoration: BoxDecoration(
              color: _stepColor(rank),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.entry,
    required this.isMe,
    required this.onTap,
  });

  final int rank;
  final _LeaderEntry entry;
  final bool isMe;
  final VoidCallback onTap;

  static Color _rankTextColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFF9E9E9E);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final name = entry.displayName.isNotEmpty
        ? entry.displayName
        : entry.username.isNotEmpty
            ? entry.username
            : 'User';

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: isMe
            ? const BoxDecoration(
                color: Color(0xFFE3F2FD),
                border: Border(
                  left: BorderSide(color: Color(0xFF1565C0), width: 3),
                ),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: rank <= 3 ? _rankTextColor(rank) : Colors.grey[600],
                ),
              ),
            ),
            _LeaderAvatar(entry: entry, radius: 22, isMe: isMe),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isMe
                                ? const Color(0xFF1565C0)
                                : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.isVIP) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD4AC0D), Color(0xFFFFD700)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'VIP',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (entry.username.isNotEmpty)
                    Text(
                      '@${entry.username}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  const SizedBox(height: 6),
                  _StatChips(entry: entry),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderAvatar extends StatelessWidget {
  const _LeaderAvatar({
    required this.entry,
    required this.radius,
    required this.isMe,
  });

  final _LeaderEntry entry;
  final double radius;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final name = entry.displayName.isNotEmpty
        ? entry.displayName
        : entry.username.isNotEmpty
            ? entry.username
            : 'U';

    return CircleAvatar(
      radius: radius,
      backgroundColor: isMe
          ? const Color(0xFF1565C0)
          : const Color(0xFF1565C0).withValues(alpha: 0.15),
      backgroundImage: entry.photoUrl != null && entry.photoUrl!.isNotEmpty
          ? NetworkImage(entry.photoUrl!)
          : null,
      child: entry.photoUrl == null || entry.photoUrl!.isEmpty
          ? Text(
              name[0].toUpperCase(),
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF1565C0),
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.55,
              ),
            )
          : null,
    );
  }
}

class _StatChips extends StatelessWidget {
  const _StatChips({required this.entry, this.compact = false});

  final _LeaderEntry entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 8.0 : 10.0;
    final hPad = compact ? 5.0 : 7.0;
    final vPad = compact ? 2.0 : 3.0;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _chip('${entry.postCount} posts', fontSize, hPad, vPad),
        _chip('${entry.totalLikes} likes', fontSize, hPad, vPad),
        _chip('${entry.uniqueLocations} locs', fontSize, hPad, vPad),
      ],
    );
  }

  Widget _chip(String label, double fontSize, double hPad, double vPad) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF1565C0).withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1565C0),
        ),
      ),
    );
  }
}
