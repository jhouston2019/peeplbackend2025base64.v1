import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ── data models ──────────────────────────────────────────────────────────────

class _Stats {
  final String username;
  final int peeps;
  final int pioneers;
  final int points;
  final int? rank;
  final int likesGiven;
  final int likesReceived;

  const _Stats({
    required this.username,
    required this.peeps,
    required this.pioneers,
    required this.points,
    this.rank,
    required this.likesGiven,
    required this.likesReceived,
  });
}

class _LeaderEntry {
  final String userId;
  final String username;
  final int points;
  final bool isMe;

  const _LeaderEntry({
    required this.userId,
    required this.username,
    required this.points,
    required this.isMe,
  });
}

class _BoardData {
  final _Stats stats;
  final List<_LeaderEntry> leaderboard;

  const _BoardData({required this.stats, required this.leaderboard});
}

// ── screen ───────────────────────────────────────────────────────────────────

class ScoreboardScreen extends StatefulWidget {
  const ScoreboardScreen({super.key});

  @override
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  final _db = FirebaseFirestore.instance;
  late Future<_BoardData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // ── data loading ─────────────────────────────────────────────────────────

  Future<_BoardData?> _load() async {
    try {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return null;
    final uid = me.uid;

    // Parallel: user doc, peep count, pioneer count, following list
    final raw = await Future.wait<dynamic>([
      _db.collection('users').doc(uid).get(),
      _db
          .collection('location_posts')
          .where('userId', isEqualTo: uid)
          .count()
          .get(),
      _db
          .collection('pioneers')
          .where('userId', isEqualTo: uid)
          .count()
          .get(),
      _db
          .collection('users')
          .doc(uid)
          .collection('following')
          .limit(50)
          .get(),
    ]);

    final userDoc = raw[0] as DocumentSnapshot;
    final peepsCount = (raw[1] as AggregateQuerySnapshot).count ?? 0;
    final pioneersCount = (raw[2] as AggregateQuerySnapshot).count ?? 0;
    final followingSnap = raw[3] as QuerySnapshot;

    final userData =
        userDoc.data() as Map<String, dynamic>? ?? {};

    final stats = _Stats(
      username: (userData['username'] as String?) ??
          (userData['displayName'] as String?) ??
          me.displayName ??
          me.email?.split('@').first ??
          'You',
      peeps: peepsCount,
      pioneers: pioneersCount,
      points: (userData['points'] as num?)?.toInt() ?? 0,
      rank: (userData['rank'] as num?)?.toInt(),
      likesGiven: (userData['likesGiven'] as num?)?.toInt() ?? 0,
      likesReceived: (userData['likesCount'] as num?)?.toInt() ??
          (userData['likesReceived'] as num?)?.toInt() ??
          0,
    );

    // Build friends leaderboard
    final friendIds =
        followingSnap.docs.map((d) => d.id).toList();
    final allIds = {...friendIds, uid}.toList(); // deduplicate

    final friendDocs = await Future.wait(
      allIds.map((id) => _db.collection('users').doc(id).get()),
    );

    final entries = friendDocs
        .map((doc) {
          if (!doc.exists) return null;
          final d = doc.data() as Map<String, dynamic>;
          return _LeaderEntry(
            userId: doc.id,
            username: (d['username'] as String?) ??
                (d['displayName'] as String?) ??
                'Unknown',
            points: (d['points'] as num?)?.toInt() ?? 0,
            isMe: doc.id == uid,
          );
        })
        .whereType<_LeaderEntry>()
        .toList()
      ..sort((a, b) => b.points.compareTo(a.points));

    return _BoardData(stats: stats, leaderboard: entries);
    } catch (e) {
      debugPrint('ScoreboardScreen._load error: $e');
      return null;
    }
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

  static Color _avatarColor(String name) {
    const palette = [
      Color(0xFF1565C0),
      Color(0xFF388E3C),
      Color(0xFFBF360C),
      Color(0xFF6A1B9A),
      Color(0xFF00695C),
      Color(0xFF558B2F),
    ];
    if (name.isEmpty) return palette[0];
    return palette[name.codeUnitAt(0) % palette.length];
  }

  static Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFB0BEC5);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Colors.grey.shade600;
  }

  static String _rankEmoji(int rank) {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '#$rank';
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    final name = me?.displayName ??
        me?.email?.split('@').first ??
        'User';
    final g = _gradient(name);

    return Scaffold(
      backgroundColor: g[0],
      body: SafeArea(
        child: Column(
          children: [
            _buildBanner(context, name, g),
            _buildSectionHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: FutureBuilder<_BoardData?>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Something went wrong'),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _future = _load()),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }
                    if (snap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    if (snap.data == null) {
                      return const Center(
                          child: Text('Not signed in'));
                    }
                    return _buildBody(context, snap.data!);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BANNER ───────────────────────────────────────────────────────────────

  Widget _buildBanner(
      BuildContext ctx, String name, List<Color> g) {
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
          const Expanded(
            child: Text(
              'Scoreboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF00BCD4).withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: const Text(
        'Your Stats & Friends Leaderboard',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ── BODY ─────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, _BoardData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildYourStatsCard(data.stats),
          const SizedBox(height: 20),
          _buildLeaderboardSection(context, data.leaderboard),
        ],
      ),
    );
  }

  // ── YOUR STATS ───────────────────────────────────────────────────────────

  Widget _buildYourStatsCard(_Stats s) {
    final rankLabel = s.rank != null ? '#${s.rank}' : '—';

    final items = [
      ('Peeps', '${s.peeps}', Icons.location_on_outlined),
      ('Pioneers', '${s.pioneers}', Icons.flag_outlined),
      ('Points', '${s.points}', Icons.star_outline),
      ('Rank', rankLabel, Icons.leaderboard_outlined),
      ('Likes Given', '${s.likesGiven}', Icons.favorite_border),
      ('Likes Received', '${s.likesReceived}', Icons.favorite),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                'YOUR STATS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 8,
            childAspectRatio: 1.3,
            children: items.map((item) {
              final (label, value, icon) = item;
              return _StatCell(
                label: label,
                value: value,
                icon: icon,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── FRIENDS LEADERBOARD ──────────────────────────────────────────────────

  Widget _buildLeaderboardSection(
      BuildContext context, List<_LeaderEntry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Friends Leaderboard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/leaderboard'),
              child: const Text(
                'View Full →',
                style: TextStyle(
                  color: Color(0xFF1565C0),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Follow friends to see them here!',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (_, i) =>
                _LeaderRow(rank: i + 1, entry: entries[i]),
          ),
      ],
    );
  }
}

// ── stat cell ────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── leader row ───────────────────────────────────────────────────────────────

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.rank, required this.entry});

  final int rank;
  final _LeaderEntry entry;

  static Color _avatarColor(String name) {
    const palette = [
      Color(0xFF1565C0),
      Color(0xFF388E3C),
      Color(0xFFBF360C),
      Color(0xFF6A1B9A),
      Color(0xFF00695C),
      Color(0xFF558B2F),
    ];
    if (name.isEmpty) return palette[0];
    return palette[name.codeUnitAt(0) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final rankLabel = rank <= 3
        ? ['🥇', '🥈', '🥉'][rank - 1]
        : '#$rank';
    final rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFB0BEC5)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : Colors.grey.shade600;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: entry.isMe
          ? const Color(0xFFE3F2FD)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          // Rank badge
          SizedBox(
            width: 40,
            child: Center(
              child: rank <= 3
                  ? Text(rankLabel,
                      style: const TextStyle(fontSize: 20))
                  : Text(
                      rankLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: rankColor,
                      ),
                    ),
            ),
          ),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor:
                entry.isMe ? const Color(0xFF1565C0) : _avatarColor(entry.username),
            child: Text(
              entry.username.isNotEmpty
                  ? entry.username[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Username
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    entry.username,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: entry.isMe
                          ? const Color(0xFF1565C0)
                          : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (entry.isMe) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Points
          Text(
            '${entry.points} pts',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: entry.isMe
                  ? const Color(0xFF1565C0)
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
