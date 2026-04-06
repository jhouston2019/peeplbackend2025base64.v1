import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ── models ───────────────────────────────────────────────────────────────────

enum _Mode { friends, everyone }

class _Leader {
  final String userId;
  final String username;
  final int points;
  final bool isMe;

  const _Leader({
    required this.userId,
    required this.username,
    required this.points,
    required this.isMe,
  });
}

// ── screen ───────────────────────────────────────────────────────────────────

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _db = FirebaseFirestore.instance;
  final _scrollController = ScrollController();

  _Mode _mode = _Mode.everyone;

  // Current user info (loaded once)
  String _myUid = '';
  String _myUsername = '';
  int _myPoints = 0;
  int? _myRank;

  // Everyone (paginated)
  final List<_Leader> _everyone = [];
  bool _loadingEveryone = true;
  bool _everyoneLoaded = false;
  bool _everyoneHasMore = true;
  bool _loadingMoreEveryone = false;
  DocumentSnapshot? _everyoneLastDoc;

  // Friends
  List<_Leader> _friends = [];
  bool _loadingFriends = false;
  bool _friendsLoaded = false;

  // ── lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMyData();
    _loadEveryone();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_mode == _Mode.everyone &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300) {
      _loadMoreEveryone();
    }
  }

  // ── data: current user ─────────────────────────────────────────────────────

  Future<void> _loadMyData() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    _myUid = me.uid;
    try {
      final doc = await _db.collection('users').doc(me.uid).get();
      final data = doc.data() ?? {};
      if (!mounted) return;
      setState(() {
        _myUsername = (data['username'] as String?) ??
            (data['displayName'] as String?) ??
            me.displayName ??
            me.email?.split('@').first ??
            'Me';
        _myPoints = (data['points'] as num?)?.toInt() ?? 0;
        _myRank = (data['rank'] as num?)?.toInt();
      });
    } catch (_) {}
  }

  // ── data: everyone (paginated) ─────────────────────────────────────────────

  Future<void> _loadEveryone() async {
    if (_loadingEveryone && _everyoneLoaded) return;
    if (!_everyoneLoaded) setState(() => _loadingEveryone = true);
    try {
      final snap = await _db
          .collection('users')
          .orderBy('points', descending: true)
          .limit(20)
          .get();
      final leaders = _toLeaders(snap.docs);
      if (!mounted) return;
      setState(() {
        _everyone
          ..clear()
          ..addAll(leaders);
        _everyoneHasMore = snap.docs.length >= 20;
        _everyoneLastDoc =
            snap.docs.isNotEmpty ? snap.docs.last : null;
        _loadingEveryone = false;
        _everyoneLoaded = true;
        // Derive rank from position if not set on user doc
        if (_myRank == null) {
          final pos =
              _everyone.indexWhere((l) => l.isMe);
          if (pos >= 0) _myRank = pos + 1;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingEveryone = false);
    }
  }

  Future<void> _loadMoreEveryone() async {
    if (_loadingMoreEveryone ||
        !_everyoneHasMore ||
        _everyoneLastDoc == null) return;
    setState(() => _loadingMoreEveryone = true);
    try {
      final snap = await _db
          .collection('users')
          .orderBy('points', descending: true)
          .startAfterDocument(_everyoneLastDoc!)
          .limit(20)
          .get();
      if (!mounted) return;
      setState(() {
        _everyone.addAll(_toLeaders(snap.docs));
        _everyoneHasMore = snap.docs.length >= 20;
        _everyoneLastDoc =
            snap.docs.isNotEmpty ? snap.docs.last : null;
        _loadingMoreEveryone = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMoreEveryone = false);
    }
  }

  // ── data: friends ──────────────────────────────────────────────────────────

  Future<void> _loadFriends() async {
    if (_loadingFriends || _friendsLoaded) return;
    setState(() => _loadingFriends = true);
    try {
      final me = FirebaseAuth.instance.currentUser;
      if (me == null) {
        setState(() => _loadingFriends = false);
        return;
      }
      final followingSnap = await _db
          .collection('users')
          .doc(me.uid)
          .collection('following')
          .limit(50)
          .get();

      final ids =
          {...followingSnap.docs.map((d) => d.id), me.uid}.toList();

      final docs = await Future.wait(
          ids.map((id) => _db.collection('users').doc(id).get()));

      final leaders = docs
          .map((doc) {
            if (!doc.exists) return null;
            final d = doc.data() as Map<String, dynamic>;
            return _Leader(
              userId: doc.id,
              username: (d['username'] as String?) ??
                  (d['displayName'] as String?) ??
                  'Unknown',
              points: (d['points'] as num?)?.toInt() ?? 0,
              isMe: doc.id == me.uid,
            );
          })
          .whereType<_Leader>()
          .toList()
        ..sort((a, b) => b.points.compareTo(a.points));

      if (!mounted) return;
      setState(() {
        _friends = leaders;
        _loadingFriends = false;
        _friendsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  // ── refresh ────────────────────────────────────────────────────────────────

  Future<void> _refresh() async {
    if (_mode == _Mode.everyone) {
      setState(() {
        _everyoneLoaded = false;
        _everyoneLastDoc = null;
        _everyoneHasMore = true;
      });
      await _loadEveryone();
    } else {
      setState(() => _friendsLoaded = false);
      await _loadFriends();
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  List<_Leader> _toLeaders(List<QueryDocumentSnapshot> docs) =>
      docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return _Leader(
          userId: doc.id,
          username: (d['username'] as String?) ??
              (d['displayName'] as String?) ??
              'Unknown',
          points: (d['points'] as num?)?.toInt() ?? 0,
          isMe: doc.id == _myUid,
        );
      }).toList();

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

  List<_Leader> get _leaders =>
      _mode == _Mode.friends ? _friends : _everyone;
  bool get _isLoading =>
      _mode == _Mode.friends ? _loadingFriends : _loadingEveryone;

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rankLabel = _myRank != null ? '#$_myRank' : '—';
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, rankLabel),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TOP BAR ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, String rankLabel) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 20, 0),
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
            ],
          ),
        ),

        // "Your Score" row
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    rankLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    Colors.white.withValues(alpha: 0.25),
                child: Text(
                  _myUsername.isNotEmpty
                      ? _myUsername[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _myUsername,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$_myPoints pts',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),

        // Mode toggle pills
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Row(
            children: [
              _pill('Everyone', _Mode.everyone),
              const SizedBox(width: 8),
              _pill('Friends', _Mode.friends),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill(String label, _Mode mode) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _mode = mode);
        if (mode == _Mode.friends && !_friendsLoaded) {
          _loadFriends();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white
                .withValues(alpha: selected ? 0 : 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? const Color(0xFF1565C0)
                : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ── CONTENT ────────────────────────────────────────────────────────────────

  Widget _buildContent() {
    if (_isLoading && _leaders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_leaders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              _mode == _Mode.friends
                  ? 'No friends on Peepl yet!'
                  : 'Leaderboard is empty',
              style:
                  TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    final hasPodium = _leaders.length >= 3;
    final top3 = hasPodium ? _leaders.take(3).toList() : <_Leader>[];
    final rest =
        hasPodium ? _leaders.skip(3).toList() : _leaders;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount:
            1 + rest.length + (_loadingMoreEveryone ? 1 : 0),
        itemBuilder: (_, i) {
          // Podium slot
          if (i == 0) {
            return hasPodium
                ? _Podium(top3: top3, myUid: _myUid)
                : const SizedBox(height: 8);
          }
          // Loading-more footer
          if (_loadingMoreEveryone && i == rest.length + 1) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child:
                  Center(child: CircularProgressIndicator()),
            );
          }
          final idx = i - 1;
          final rank = (hasPodium ? 3 : 0) + idx + 1;
          return _RankRow(
            rank: rank,
            leader: rest[idx],
            avatarColor: _avatarColor(rest[idx].username),
          );
        },
      ),
    );
  }
}

// ── podium ───────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  const _Podium({required this.top3, required this.myUid});

  final List<_Leader> top3;
  final String myUid;

  static Color _avatarColor(String name) {
    const palette = [
      Color(0xFF1565C0),
      Color(0xFF388E3C),
      Color(0xFFBF360C),
      Color(0xFF6A1B9A),
      Color(0xFF00695C),
    ];
    if (name.isEmpty) return palette[0];
    return palette[name.codeUnitAt(0) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FF),
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // #2 — left, medium step
          _PodiumPlace(
            rank: 2,
            leader: top3[1],
            stepHeight: 60,
            avatarRadius: 26,
            avatarColor: _avatarColor(top3[1].username),
          ),
          // #1 — center, tallest step, gold border
          _PodiumPlace(
            rank: 1,
            leader: top3[0],
            stepHeight: 90,
            avatarRadius: 34,
            goldBorder: true,
            avatarColor: top3[0].isMe
                ? const Color(0xFF1565C0)
                : _avatarColor(top3[0].username),
          ),
          // #3 — right, shortest step
          _PodiumPlace(
            rank: 3,
            leader: top3[2],
            stepHeight: 42,
            avatarRadius: 22,
            avatarColor: _avatarColor(top3[2].username),
          ),
        ],
      ),
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({
    required this.rank,
    required this.leader,
    required this.stepHeight,
    required this.avatarRadius,
    required this.avatarColor,
    this.goldBorder = false,
  });

  final int rank;
  final _Leader leader;
  final double stepHeight;
  final double avatarRadius;
  final Color avatarColor;
  final bool goldBorder;

  static Color _stepColor(int r) {
    if (r == 1) return const Color(0xFFFFD700);
    if (r == 2) return const Color(0xFFB0BEC5);
    return const Color(0xFFCD7F32);
  }

  @override
  Widget build(BuildContext context) {
    final emoji = rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';
    final stepColor = _stepColor(rank);
    final nameWidth = rank == 1 ? 88.0 : 72.0;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/user_profile',
        arguments: leader.userId,
      ),
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji,
            style: TextStyle(fontSize: rank == 1 ? 22 : 17)),
        const SizedBox(height: 4),
        // Avatar (gold border for #1)
        Container(
          decoration: goldBorder
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFD700),
                    width: 3,
                  ),
                )
              : null,
          child: CircleAvatar(
            radius: avatarRadius,
            backgroundColor: avatarColor,
            child: Text(
              leader.username.isNotEmpty
                  ? leader.username[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: rank == 1 ? 24 : 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: nameWidth,
          child: Text(
            leader.username,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: rank == 1 ? 13 : 11,
              color: leader.isMe
                  ? const Color(0xFF1565C0)
                  : Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${leader.points} pts',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: rank == 1 ? 13 : 11,
            color: const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(height: 4),
        // Podium step
        Container(
          width: rank == 1 ? 82 : 66,
          height: stepHeight,
          decoration: BoxDecoration(
            color: stepColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(5),
              topRight: Radius.circular(5),
            ),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ],
    ),
    );
  }
}

// ── rank row ─────────────────────────────────────────────────────────────────

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.leader,
    required this.avatarColor,
  });

  final int rank;
  final _Leader leader;
  final Color avatarColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        '/user_profile',
        arguments: leader.userId,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: leader.isMe
            ? const BoxDecoration(
                color: Color(0xFFE3F2FD),
                border: Border(
                  left: BorderSide(
                    color: Color(0xFF1565C0),
                    width: 3,
                  ),
                ),
              )
            : null,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 19,
              backgroundColor:
                  leader.isMe ? const Color(0xFF1565C0) : avatarColor,
              child: Text(
                leader.username.isNotEmpty
                    ? leader.username[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      leader.username,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: leader.isMe
                            ? const Color(0xFF1565C0)
                            : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (leader.isMe) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
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
            ),
            Text(
              '${leader.points} pts',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: leader.isMe
                    ? const Color(0xFF1565C0)
                    : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
