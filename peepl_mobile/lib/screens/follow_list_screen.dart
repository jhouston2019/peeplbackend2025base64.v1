import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _kUsersCollection = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

class FollowListScreen extends StatefulWidget {
  const FollowListScreen({
    super.key,
    this.userId,
    this.initialTab = 0,
    this.mode,
  });

  final String? userId;
  final int initialTab;

  /// Legacy route arg: 'followers' or 'following'.
  final String? mode;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _searchCtrl = TextEditingController();

  String _profileUserId = '';
  bool _didInit = false;
  String _searchQuery = '';

  int _followersCount = 0;
  int _followingCount = 0;

  TabController? _tabController;

  final Map<String, _FollowUser> _userCache = {};
  final Map<String, bool> _iFollowCache = {};

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _isOwnProfile =>
      _profileUserId.isNotEmpty && _profileUserId == _currentUid;

  @override
  void dispose() {
    _tabController?.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    _profileUserId = widget.userId ?? '';
    var initialTab = widget.initialTab;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      if (_profileUserId.isEmpty) {
        _profileUserId = args['userId'] as String? ?? '';
      }
      if (args['initialTab'] is int) {
        initialTab = args['initialTab'] as int;
      } else {
        final mode = args['mode'] as String? ?? widget.mode;
        if (mode == 'following') initialTab = 1;
        if (mode == 'followers') initialTab = 0;
      }
    } else if (widget.mode == 'following') {
      initialTab = 1;
    } else if (widget.mode == 'followers') {
      initialTab = 0;
    }

    if (_profileUserId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialTab.clamp(0, 1),
    );
  }

  Future<_FollowUser> _loadUser(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid]!;

    try {
      final results = await Future.wait([
        _db.collection(_kUsersCollection).doc(uid).get(),
        _db
            .collection('location_posts')
            .where('userId', isEqualTo: uid)
            .count()
            .get(),
      ]);

      final userDoc = results[0] as DocumentSnapshot;
      final countSnap = results[1] as AggregateQuerySnapshot;
      final data = userDoc.data() as Map<String, dynamic>? ?? {};

      final user = _FollowUser(
        uid: uid,
        displayName: (data['displayName'] as String?) ??
            (data['name'] as String?) ??
            'User',
        username: (data['username'] as String?) ?? '',
        photoUrl: data['photoUrl'] as String?,
        postCount: countSnap.count ?? 0,
      );
      _userCache[uid] = user;
      return user;
    } catch (e) {
      debugPrint('FollowListScreen._loadUser: $e');
      final fallback = _FollowUser(
        uid: uid,
        displayName: 'User',
        username: '',
        photoUrl: null,
        postCount: 0,
      );
      _userCache[uid] = fallback;
      return fallback;
    }
  }

  Future<bool> _doIFollow(String uid) async {
    if (_currentUid.isEmpty || uid == _currentUid) return false;
    if (_iFollowCache.containsKey(uid)) return _iFollowCache[uid]!;

    try {
      final doc = await _db
          .collection('follows')
          .doc(_currentUid)
          .collection('following')
          .doc(uid)
          .get();
      final follows = doc.exists;
      _iFollowCache[uid] = follows;
      return follows;
    } catch (_) {
      return false;
    }
  }

  Future<void> _followUser(String targetUid) async {
    if (_currentUid.isEmpty || targetUid == _currentUid) return;
    try {
      final now = FieldValue.serverTimestamp();
      await Future.wait([
        _db
            .collection('follows')
            .doc(_currentUid)
            .collection('following')
            .doc(targetUid)
            .set({'followedAt': now}),
        _db
            .collection('follows')
            .doc(targetUid)
            .collection('followers')
            .doc(_currentUid)
            .set({'followedAt': now}),
      ]);
      _iFollowCache[targetUid] = true;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to follow: $e')),
        );
      }
    }
  }

  Future<void> _unfollowUser(String targetUid) async {
    if (_currentUid.isEmpty) return;
    try {
      await Future.wait([
        _db
            .collection('follows')
            .doc(_currentUid)
            .collection('following')
            .doc(targetUid)
            .delete(),
        _db
            .collection('follows')
            .doc(targetUid)
            .collection('followers')
            .doc(_currentUid)
            .delete(),
      ]);
      _iFollowCache[targetUid] = false;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unfollow: $e')),
        );
      }
    }
  }

  Future<void> _removeFollower(String followerUid) async {
    if (!_isOwnProfile) return;
    try {
      await Future.wait([
        _db
            .collection('follows')
            .doc(_profileUserId)
            .collection('followers')
            .doc(followerUid)
            .delete(),
        _db
            .collection('follows')
            .doc(followerUid)
            .collection('following')
            .doc(_profileUserId)
            .delete(),
      ]);
      if (mounted) {
        setState(() => _followersCount = (_followersCount - 1).clamp(0, 999999));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove follower: $e')),
        );
      }
    }
  }

  bool _matchesSearch(_FollowUser user) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    return user.username.toLowerCase().contains(q) ||
        user.displayName.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    if (_profileUserId.isEmpty || _tabController == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
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
            'Connections',
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (value) => setState(() => _searchQuery = value.trim()),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: 'Search by username...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.white.withValues(alpha: 0.8),
            size: 18,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 18,
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(21),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(21),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(21),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
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
        tabs: [
          Tab(text: 'Followers ($_followersCount)'),
          Tab(text: 'Following ($_followingCount)'),
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
          _buildFollowList(
            collection: 'followers',
            emptyMessage: 'No followers yet',
            isFollowersTab: true,
            onCountChanged: (total) {
              if (_followersCount != total) {
                setState(() => _followersCount = total);
              }
            },
          ),
          _buildFollowList(
            collection: 'following',
            emptyMessage: 'Not following anyone yet',
            isFollowersTab: false,
            onCountChanged: (total) {
              if (_followingCount != total) {
                setState(() => _followingCount = total);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFollowList({
    required String collection,
    required String emptyMessage,
    required bool isFollowersTab,
    required void Function(int total) onCountChanged,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('follows')
          .doc(_profileUserId)
          .collection(collection)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() {}),
              child: const Text('Failed to load — tap to retry'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) onCountChanged(docs.length);
        });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  emptyMessage,
                  style: TextStyle(color: Colors.grey[500], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: docs.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, color: Colors.grey.shade100),
          itemBuilder: (context, index) {
            final uid = docs[index].id;
            if (uid == _currentUid) return const SizedBox.shrink();

            return _FollowUserRow(
              key: ValueKey('$collection-$uid'),
              uid: uid,
              searchQuery: _searchQuery,
              loadUser: _loadUser,
              doIFollow: _doIFollow,
              matchesSearch: _matchesSearch,
              isFollowersTab: isFollowersTab,
              isOwnProfile: _isOwnProfile,
              currentUid: _currentUid,
              onFollow: _followUser,
              onUnfollow: _unfollowUser,
              onRemove: _removeFollower,
            );
          },
        );
      },
    );
  }
}

class _FollowUserRow extends StatefulWidget {
  const _FollowUserRow({
    super.key,
    required this.uid,
    required this.searchQuery,
    required this.loadUser,
    required this.doIFollow,
    required this.matchesSearch,
    required this.isFollowersTab,
    required this.isOwnProfile,
    required this.currentUid,
    required this.onFollow,
    required this.onUnfollow,
    required this.onRemove,
  });

  final String uid;
  final String searchQuery;
  final Future<_FollowUser> Function(String uid) loadUser;
  final Future<bool> Function(String uid) doIFollow;
  final bool Function(_FollowUser user) matchesSearch;
  final bool isFollowersTab;
  final bool isOwnProfile;
  final String currentUid;
  final Future<void> Function(String uid) onFollow;
  final Future<void> Function(String uid) onUnfollow;
  final Future<void> Function(String uid) onRemove;

  @override
  State<_FollowUserRow> createState() => _FollowUserRowState();
}

class _FollowUserRowState extends State<_FollowUserRow> {
  bool _actionLoading = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        widget.loadUser(widget.uid),
        widget.doIFollow(widget.uid),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                CircleAvatar(radius: 22, backgroundColor: Colors.grey),
                SizedBox(width: 12),
                Expanded(
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ],
            ),
          );
        }

        final user = snap.data![0] as _FollowUser;
        final iFollow = snap.data![1] as bool;

        if (!widget.matchesSearch(user)) return const SizedBox.shrink();

        return InkWell(
          onTap: () => Navigator.pushNamed(
            context,
            '/user_profile',
            arguments: widget.uid,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      const Color(0xFF1565C0).withValues(alpha: 0.15),
                  backgroundImage: user.photoUrl != null &&
                          user.photoUrl!.isNotEmpty
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null || user.photoUrl!.isEmpty
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Color(0xFF1565C0),
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
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user.username.isNotEmpty)
                        Text(
                          '@${user.username}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      Text(
                        '${user.postCount} ${user.postCount == 1 ? 'post' : 'posts'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActionButton(iFollow),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(bool iFollow) {
    if (widget.currentUid.isEmpty) return const SizedBox.shrink();

    if (widget.isFollowersTab) {
      if (widget.isOwnProfile) {
        return _actionButton(
          label: 'Remove',
          filled: false,
          destructive: true,
          onTap: () async {
            setState(() => _actionLoading = true);
            await widget.onRemove(widget.uid);
            if (mounted) setState(() => _actionLoading = false);
          },
        );
      }
      if (!iFollow) {
        return _actionButton(
          label: 'Follow back',
          filled: true,
          onTap: () async {
            setState(() => _actionLoading = true);
            await widget.onFollow(widget.uid);
            if (mounted) setState(() => _actionLoading = false);
          },
        );
      }
      return _actionButton(label: 'Following', filled: false, onTap: null);
    }

    if (widget.isOwnProfile) {
      return _actionButton(
        label: 'Unfollow',
        filled: false,
        onTap: () async {
          setState(() => _actionLoading = true);
          await widget.onUnfollow(widget.uid);
          if (mounted) setState(() => _actionLoading = false);
        },
      );
    }

    if (!iFollow) {
      return _actionButton(
        label: 'Follow',
        filled: true,
        onTap: () async {
          setState(() => _actionLoading = true);
          await widget.onFollow(widget.uid);
          if (mounted) setState(() => _actionLoading = false);
        },
      );
    }

    return _actionButton(label: 'Following', filled: false, onTap: null);
  }

  Widget _actionButton({
    required String label,
    required bool filled,
    bool destructive = false,
    VoidCallback? onTap,
  }) {
    if (_actionLoading) {
      return const SizedBox(
        width: 72,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (onTap == null) {
      return Text(
        label,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      );
    }

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor:
            filled ? const Color(0xFF1565C0) : Colors.transparent,
        foregroundColor: destructive
            ? Colors.red
            : filled
                ? Colors.white
                : const Color(0xFF1565C0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: filled
              ? BorderSide.none
              : BorderSide(
                  color: destructive ? Colors.red : const Color(0xFF1565C0),
                ),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FollowUser {
  final String uid;
  final String displayName;
  final String username;
  final String? photoUrl;
  final int postCount;

  const _FollowUser({
    required this.uid,
    required this.displayName,
    required this.username,
    required this.photoUrl,
    required this.postCount,
  });
}
