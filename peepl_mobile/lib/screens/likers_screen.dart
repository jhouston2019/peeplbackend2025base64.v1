import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _kUsersCollection = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

class _LikerUser {
  final String userId;
  final String displayName;
  final String username;
  final String? photoUrl;

  const _LikerUser({
    required this.userId,
    required this.displayName,
    required this.username,
    this.photoUrl,
  });
}

class LikersScreen extends StatefulWidget {
  /// Optional: supply directly; otherwise resolved from route args.
  final String? postId;
  final String? locationName;

  const LikersScreen({super.key, this.postId, this.locationName});

  @override
  State<LikersScreen> createState() => _LikersScreenState();
}

class _LikersScreenState extends State<LikersScreen> {
  String _postId = '';
  String _locationName = '';
  bool _didInit = false;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _postId = widget.postId ?? '';
      _locationName = widget.locationName ?? '';

      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _postId = _postId.isNotEmpty
            ? _postId
            : (args['postId'] as String? ?? '');
        _locationName = _locationName.isNotEmpty
            ? _locationName
            : (args['locationName'] as String? ?? '');
      } else if (args is String && _postId.isEmpty) {
        _postId = args;
      }
    }
  }

  Future<Map<String, _LikerUser>> _loadUsers(List<String> userIds) async {
    if (userIds.isEmpty) return {};

    final results = await Future.wait(
      userIds.map(
        (id) => FirebaseFirestore.instance
            .collection(_kUsersCollection)
            .doc(id)
            .get(),
      ),
    );

    final users = <String, _LikerUser>{};
    for (final doc in results) {
      if (!doc.exists) continue;
      final data = doc.data() as Map<String, dynamic>;
      final username = (data['username'] as String?)?.trim() ?? '';
      final displayRaw = (data['displayName'] as String?)?.trim() ?? '';
      final displayName = displayRaw.isNotEmpty
          ? displayRaw
          : (username.isNotEmpty ? username : 'Unknown');
      users[doc.id] = _LikerUser(
        userId: doc.id,
        displayName: displayName,
        username: username.isNotEmpty ? username : displayName,
        photoUrl: data['photoUrl'] as String?,
      );
    }
    return users;
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

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
    return StreamBuilder<QuerySnapshot>(
      stream: _postId.isEmpty
          ? null
          : FirebaseFirestore.instance
              .collection('location_posts')
              .doc(_postId)
              .collection('likes')
              .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        final title = count == 1
            ? '1 person liked this'
            : '$count people liked this';

        return Container(
          color: const Color(0xFF2244EE),
          padding: EdgeInsets.fromLTRB(0, topPad + 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (_locationName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 56, top: 2),
                  child: Text(
                    'People who liked $_locationName',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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

        final userIds = docs.map((d) => d.id).toList();

        return FutureBuilder<Map<String, _LikerUser>>(
          future: _loadUsers(userIds),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final users = userSnap.data ?? {};

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                indent: 68,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final userId = doc.id;
                final user = users[userId] ??
                    _LikerUser(
                      userId: userId,
                      displayName: 'Unknown',
                      username: 'unknown',
                    );

                return _LikerRow(
                  user: user,
                  currentUid: _currentUid,
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/user_profile',
                    arguments: userId,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('❤️', style: TextStyle(fontSize: 48)),
            SizedBox(height: 14),
            Text(
              'No likes yet — be the first!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikerRow extends StatefulWidget {
  const _LikerRow({
    required this.user,
    required this.currentUid,
    required this.onTap,
  });

  final _LikerUser user;
  final String currentUid;
  final VoidCallback onTap;

  @override
  State<_LikerRow> createState() => _LikerRowState();
}

class _LikerRowState extends State<_LikerRow> {
  final _db = FirebaseFirestore.instance;
  bool _isFollowing = false;
  bool _followLoaded = false;
  bool _loadingFollow = false;

  bool get _isSelf =>
      widget.currentUid.isNotEmpty && widget.currentUid == widget.user.userId;

  @override
  void initState() {
    super.initState();
    _loadFollowState();
  }

  Future<void> _loadFollowState() async {
    if (_isSelf || widget.currentUid.isEmpty) {
      if (mounted) setState(() => _followLoaded = true);
      return;
    }

    try {
      final doc = await _db
          .collection('follows')
          .doc(widget.currentUid)
          .collection('following')
          .doc(widget.user.userId)
          .get();
      if (mounted) {
        setState(() {
          _isFollowing = doc.exists;
          _followLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _followLoaded = true);
    }
  }

  Future<void> _toggleFollow() async {
    if (_isSelf || widget.currentUid.isEmpty || _loadingFollow) return;

    setState(() => _loadingFollow = true);
    try {
      final myFollowingRef = _db
          .collection('follows')
          .doc(widget.currentUid)
          .collection('following')
          .doc(widget.user.userId);
      final theirFollowersRef = _db
          .collection('follows')
          .doc(widget.user.userId)
          .collection('followers')
          .doc(widget.currentUid);
      final now = FieldValue.serverTimestamp();

      if (_isFollowing) {
        await Future.wait([
          myFollowingRef.delete(),
          theirFollowersRef.delete(),
        ]);
        if (mounted) setState(() => _isFollowing = false);
      } else {
        await Future.wait([
          myFollowingRef.set({'followedAt': now}),
          theirFollowersRef.set({'followedAt': now}),
        ]);
        if (mounted) setState(() => _isFollowing = true);
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

  static Color _avatarColor(String name) {
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
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final initial = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : '?';

    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _avatarColor(user.displayName),
              backgroundImage: user.photoUrl != null &&
                      user.photoUrl!.isNotEmpty
                  ? NetworkImage(user.photoUrl!)
                  : null,
              child: user.photoUrl == null || user.photoUrl!.isEmpty
                  ? Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.username.isNotEmpty &&
                      user.username != user.displayName)
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (!_isSelf && _followLoaded) ...[
              const SizedBox(width: 8),
              _loadingFollow
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _toggleFollow,
                      style: TextButton.styleFrom(
                        backgroundColor: _isFollowing
                            ? Colors.grey.shade200
                            : const Color(0xFF1565C0),
                        foregroundColor: _isFollowing
                            ? Colors.black87
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _isFollowing ? 'Following' : 'Follow',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}
