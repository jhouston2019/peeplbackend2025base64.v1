import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _db = FirebaseFirestore.instance;

  // user doc
  Map<String, dynamic>? _userData;

  // follow state
  bool _isFollowing = false;
  bool _loadingFollow = false;
  bool _isCurrentUser = false;

  // stats
  int _peepsCount = 0;
  int _pioneersCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;

  List<QueryDocumentSnapshot> _recentPeeps = [];
  bool _dataLoaded = false;
  bool _error = false;

  // ── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (mounted) setState(() { _error = false; _dataLoaded = false; });
    await Future.wait([_loadUserAndFollow(), _loadStats(), _loadRecentPeeps()]);
    if (mounted) setState(() => _dataLoaded = true);
  }

  Future<void> _loadUserAndFollow() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      _isCurrentUser = currentUser?.uid == widget.userId;

      final doc = await _db.collection('users').doc(widget.userId).get();
      if (!mounted) return;
      setState(() => _userData = doc.data() ?? {});

      if (currentUser != null && !_isCurrentUser) {
        final followDoc = await _db
            .collection('users')
            .doc(currentUser.uid)
            .collection('following')
            .doc(widget.userId)
            .get();
        if (mounted) setState(() => _isFollowing = followDoc.exists);
      }
    } catch (e) {
      debugPrint('UserProfile._loadUserAndFollow: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _loadStats() async {
    try {
      final uid = widget.userId;
      final results = await Future.wait([
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
            .collection('followers')
            .count()
            .get(),
        _db
            .collection('users')
            .doc(uid)
            .collection('following')
            .count()
            .get(),
      ]);
      if (!mounted) return;
      setState(() {
        _peepsCount = results[0].count ?? 0;
        _pioneersCount = results[1].count ?? 0;
        _followersCount = results[2].count ?? 0;
        _followingCount = results[3].count ?? 0;
      });
    } catch (e) {
      debugPrint('UserProfile._loadStats: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _loadRecentPeeps() async {
    try {
      final snap = await _db
          .collection('location_posts')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .limit(3)
          .get();
      if (!mounted) return;
      setState(() => _recentPeeps = snap.docs);
    } catch (e) {
      debugPrint('UserProfile._loadRecentPeeps: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  // ── follow / unfollow ────────────────────────────────────────────────────

  Future<void> _toggleFollow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    setState(() => _loadingFollow = true);
    try {
      final myRef = _db.collection('users').doc(currentUser.uid);
      final theirRef = _db.collection('users').doc(widget.userId);
      final now = FieldValue.serverTimestamp();

      if (_isFollowing) {
        await Future.wait([
          myRef.collection('following').doc(widget.userId).delete(),
          theirRef.collection('followers').doc(currentUser.uid).delete(),
        ]);
        setState(() {
          _isFollowing = false;
          _followersCount = (_followersCount - 1).clamp(0, 999999);
        });
      } else {
        await Future.wait([
          myRef
              .collection('following')
              .doc(widget.userId)
              .set({'followedAt': now}),
          theirRef
              .collection('followers')
              .doc(currentUser.uid)
              .set({'followedAt': now}),
        ]);
        setState(() {
          _isFollowing = true;
          _followersCount++;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingFollow = false);
    }
  }

  // ── colour helpers ───────────────────────────────────────────────────────

  static const List<List<Color>> _gradients = [
    [Color(0xFF1565C0), Color(0xFF0D47A1)],
    [Color(0xFF2E7D32), Color(0xFF1B5E20)],
    [Color(0xFF4527A0), Color(0xFF311B92)],
    [Color(0xFF00695C), Color(0xFF004D40)],
    [Color(0xFFBF360C), Color(0xFF7F0000)],
    [Color(0xFF37474F), Color(0xFF263238)],
  ];

  List<Color> _userGradient(String name) =>
      _gradients[name.isNotEmpty ? name.codeUnitAt(0) % _gradients.length : 0];

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final username = (_userData?['username'] as String?) ??
        (_userData?['displayName'] as String?) ??
        'User';
    final likesCount = (_userData?['likesCount'] as num?)?.toInt() ?? 0;
    final gradient = _userGradient(username);

    return Scaffold(
      backgroundColor: gradient[0],
      body: SafeArea(
        child: Column(
          children: [
            _buildBanner(context, username, gradient),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: _error
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Something went wrong',
                              style: TextStyle(fontSize: 15, color: Colors.black54),
                            ),
                            TextButton(
                              onPressed: _loadAll,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : !_dataLoaded
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatsRow(context, likesCount),
                            const Divider(height: 32),
                            _buildRecentPeepsSection(context),
                          ],
                        ),
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
      BuildContext context, String username, List<Color> gradient) {
    return Container(
      height: 72,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white.withValues(alpha: 0.28),
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!_isCurrentUser) _buildFollowButton(gradient),
        ],
      ),
    );
  }

  Widget _buildFollowButton(List<Color> gradient) {
    if (_loadingFollow) {
      return const SizedBox(
        width: 20,
        height: 20,
        child:
            CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }
    return GestureDetector(
      onTap: _toggleFollow,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: _isFollowing
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          _isFollowing ? 'Following' : '+ Follow',
          style: TextStyle(
            color: _isFollowing ? Colors.white : gradient[0],
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ── STATS ────────────────────────────────────────────────────────────────

  Widget _buildStatsRow(BuildContext context, int likesCount) {
    final stats = <(String, int, String?)>[
      ('Peeps', _peepsCount, null),
      ('Pioneers', _pioneersCount, null),
      ('Likes', likesCount, null),
      ('Followers', _followersCount, 'followers'),
      ('Following', _followingCount, 'following'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: stats.map((s) {
        final (label, count, mode) = s;
        final tappable = mode != null;
        return GestureDetector(
          onTap: tappable
              ? () => Navigator.pushNamed(
                    context,
                    '/follow_list',
                    arguments: {
                      'userId': widget.userId,
                      'mode': mode,
                    },
                  )
              : null,
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: tappable
                      ? const Color(0xFF1565C0)
                      : Colors.black87,
                  decoration:
                      tappable ? TextDecoration.underline : null,
                  decorationColor: const Color(0xFF1565C0),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── RECENT PEEPS ─────────────────────────────────────────────────────────

  Widget _buildRecentPeepsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Peeps',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(
                context,
                '/my_peeps',
                arguments: widget.userId,
              ),
              child: const Text(
                'See all →',
                style: TextStyle(color: Color(0xFF1565C0)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_recentPeeps.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No Peeps yet.',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentPeeps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final data =
                  _recentPeeps[i].data() as Map<String, dynamic>;
              return _MiniPeepCard(
                data: data,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/peep_detail',
                  arguments: Map<String, dynamic>.from(data)
                    ..['id'] = _recentPeeps[i].id,
                ),
              );
            },
          ),
      ],
    );
  }
}

// ── mini peep card ───────────────────────────────────────────────────────────

class _MiniPeepCard extends StatelessWidget {
  const _MiniPeepCard({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  static Color _levelColor(int l) {
    if (l <= 4) return const Color(0xFF4CAF50);
    if (l <= 6) return const Color(0xFFFFA726);
    return const Color(0xFFFF5722);
  }

  @override
  Widget build(BuildContext context) {
    final locationName =
        data['locationName'] as String? ?? 'Unknown location';
    final level = (data['crowdingLevel'] as num?)?.toInt() ?? 0;
    final description = data['description'] as String? ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF1565C0).withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _levelColor(level),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    locationName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}
