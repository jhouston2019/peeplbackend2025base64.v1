import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/crowd_meter.dart';
import 'location_detail_screen.dart';

const _kUsersCollection = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _targetUserId = '';
  Map<String, dynamic>? _userData;
  bool _isFollowing = false;
  bool _loadingFollow = false;
  bool _isCurrentUser = false;
  bool _didInit = false;

  int _postsCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;

  bool _loading = true;
  bool _error = false;

  TabController? _tabController;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    _targetUserId = widget.userId ?? '';
    if (_targetUserId.isEmpty) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _targetUserId = args;
      } else if (args is Map) {
        _targetUserId = args['userId'] as String? ?? '';
      }
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _isCurrentUser =
        _targetUserId.isNotEmpty && _targetUserId == currentUid;

    _tabController = TabController(
      length: _isCurrentUser ? 2 : 1,
      vsync: this,
    );

    if (_targetUserId.isNotEmpty) _loadAll();
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }

    await Future.wait([
      _loadUserAndFollow(),
      _loadStats(),
    ]);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadUserAndFollow() async {
    try {
      final doc =
          await _db.collection(_kUsersCollection).doc(_targetUserId).get();
      if (!mounted) return;
      setState(() => _userData = doc.data() ?? {});

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null && !_isCurrentUser) {
        final followDoc = await _db
            .collection('follows')
            .doc(currentUid)
            .collection('following')
            .doc(_targetUserId)
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
      final results = await Future.wait([
        _db
            .collection('location_posts')
            .where('userId', isEqualTo: _targetUserId)
            .count()
            .get(),
        _db
            .collection('follows')
            .doc(_targetUserId)
            .collection('followers')
            .count()
            .get(),
        _db
            .collection('follows')
            .doc(_targetUserId)
            .collection('following')
            .count()
            .get(),
      ]);

      if (!mounted) return;
      setState(() {
        _postsCount = results[0].count ?? 0;
        _followersCount = results[1].count ?? 0;
        _followingCount = results[2].count ?? 0;
      });
    } catch (e) {
      debugPrint('UserProfile._loadStats: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _toggleFollow() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    setState(() => _loadingFollow = true);
    try {
      final myFollowingRef = _db
          .collection('follows')
          .doc(currentUid)
          .collection('following')
          .doc(_targetUserId);
      final theirFollowersRef = _db
          .collection('follows')
          .doc(_targetUserId)
          .collection('followers')
          .doc(currentUid);
      final now = FieldValue.serverTimestamp();

      if (_isFollowing) {
        await Future.wait([
          myFollowingRef.delete(),
          theirFollowersRef.delete(),
        ]);
        if (mounted) {
          setState(() {
            _isFollowing = false;
            _followersCount = (_followersCount - 1).clamp(0, 999999);
          });
        }
      } else {
        await Future.wait([
          myFollowingRef.set({'followedAt': now}),
          theirFollowersRef.set({'followedAt': now}),
        ]);
        if (mounted) {
          setState(() {
            _isFollowing = true;
            _followersCount++;
          });
        }
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

  Future<void> _blockUser() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block user?'),
        content: const Text(
          'They will not be able to interact with you. You can unblock later in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _db
          .collection('blocks')
          .doc(currentUid)
          .collection('blocked')
          .doc(_targetUserId)
          .set({'blockedAt': FieldValue.serverTimestamp()});

      if (_isFollowing) await _toggleFollow();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not block user: $e')),
        );
      }
    }
  }

  Future<void> _reportUser() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    const reasons = [
      'Spam or fake account',
      'Harassment',
      'Inappropriate content',
      'Impersonation',
      'Other',
    ];

    String? selected;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report user'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: reasons
                  .map(
                    (reason) => ListTile(
                      title: Text(reason, style: const TextStyle(fontSize: 14)),
                      leading: Icon(
                        selected == reason
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: const Color(0xFF1565C0),
                      ),
                      onTap: () => setDialogState(() => selected = reason),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || selected == null || !mounted) return;

    try {
      await _db.collection('reports').add({
        'reportedUserId': _targetUserId,
        'reporterId': currentUid,
        'reason': selected,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thank you.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e')),
        );
      }
    }
  }

  void _showMenu() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.red),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(ctx);
                _reportUser();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Block'),
              onTap: () {
                Navigator.pop(ctx);
                _blockUser();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatJoinDate(dynamic value) {
    DateTime? date;
    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }
    if (date == null) return 'Joined —';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Joined ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_targetUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('User not found')),
      );
    }

    final displayName = (_userData?['displayName'] as String?) ??
        (_userData?['name'] as String?) ??
        'User';
    final username = (_userData?['username'] as String?) ?? '';
    final bio = (_userData?['bio'] as String?) ?? '';
    final photoUrl = _userData?['photoUrl'] as String?;
    final isVIP = _userData?['isVIPeep'] as bool? ?? false;
    final joinDate = _formatJoinDate(
      _userData?['joinDate'] ??
          _userData?['createdAt'] ??
          _userData?['joinedAt'],
    );

    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error && _userData == null
                        ? _buildErrorState()
                        : Column(
                            children: [
                              Expanded(
                                child: NestedScrollView(
                                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                                    return [
                                      SliverToBoxAdapter(
                                        child: _buildProfileHeader(
                                          displayName: displayName,
                                          username: username,
                                          bio: bio,
                                          photoUrl: photoUrl,
                                          isVIP: isVIP,
                                          joinDate: joinDate,
                                        ),
                                      ),
                                      if (_tabController != null)
                                        SliverPersistentHeader(
                                          pinned: true,
                                          delegate: _TabBarDelegate(
                                            TabBar(
                                              controller: _tabController,
                                              labelColor: const Color(0xFF1565C0),
                                              unselectedLabelColor: Colors.grey,
                                              indicatorColor: const Color(0xFF1565C0),
                                              tabs: [
                                                const Tab(text: 'Posts'),
                                                if (_isCurrentUser)
                                                  const Tab(text: 'Favorites'),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ];
                                  },
                                  body: _tabController == null
                                      ? const SizedBox.shrink()
                                      : TabBarView(
                                          controller: _tabController,
                                          children: [
                                            _buildPostsTab(),
                                            if (_isCurrentUser)
                                              _buildFavoritesTab(),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              'Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!_isCurrentUser)
            IconButton(
              onPressed: _showMenu,
              icon: const Icon(Icons.more_vert, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Something went wrong',
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
          TextButton(onPressed: _loadAll, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildProfileHeader({
    required String displayName,
    required String username,
    required String bio,
    required String? photoUrl,
    required bool isVIP,
    required String joinDate,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.15),
            backgroundImage:
                photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? Text(
                    displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          if (username.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '@$username',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
          if (isVIP) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AC0D), Color(0xFFFFD700)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('⭐', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Text(
                    'VIPeep',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              bio,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            joinDate,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          _buildStatsRow(),
          const SizedBox(height: 16),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('Posts', _postsCount, null),
        _buildStatItem('Followers', _followersCount, 0),
        _buildStatItem('Following', _followingCount, 1),
      ],
    );
  }

  Widget _buildStatItem(String label, int count, int? initialTab) {
    final tappable = initialTab != null;
    return GestureDetector(
      onTap: tappable
          ? () => Navigator.pushNamed(
                context,
                '/follow_list',
                arguments: {
                  'userId': _targetUserId,
                  'initialTab': initialTab,
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
              color: tappable ? const Color(0xFF1565C0) : Colors.black87,
              decoration: tappable ? TextDecoration.underline : null,
              decorationColor: const Color(0xFF1565C0),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (_isCurrentUser) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/account_info'),
          icon: const Icon(Icons.edit_outlined),
          label: const Text(
            'Edit Profile',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1565C0),
            side: const BorderSide(color: Color(0xFF1565C0)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (_loadingFollow) {
      return const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _toggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _isFollowing ? Colors.grey.shade200 : const Color(0xFF1565C0),
          foregroundColor:
              _isFollowing ? Colors.black87 : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: _isFollowing ? 0 : 2,
        ),
        child: Text(
          _isFollowing ? 'Following' : 'Follow',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildPostsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('location_posts')
          .where('userId', isEqualTo: _targetUserId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Could not load posts: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No posts yet',
              style: TextStyle(color: Colors.grey[500]),
            ),
          );
        }

        return GridView.builder(
          primary: false,
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final post = {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            };
            return _PostGridTile(
              post: post,
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => LocationDetailScreen(postData: post),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFavoritesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection(_kUsersCollection)
          .doc(_targetUserId)
          .collection('favorites')
          .orderBy('savedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load favorites'));
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('♥', style: TextStyle(fontSize: 40, color: Colors.red)),
                const SizedBox(height: 10),
                Text(
                  'No favorite venues yet',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          primary: false,
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final locationName =
                data['locationName'] as String? ?? docs[index].id;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: Color(0xFF1565C0),
                  size: 20,
                ),
              ),
              title: Text(
                locationName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () => Navigator.pushNamed(
                context,
                '/venue',
                arguments: {'locationName': locationName},
              ),
            );
          },
        );
      },
    );
  }
}

class _PostGridTile extends StatelessWidget {
  const _PostGridTile({required this.post, required this.onTap});

  final Map<String, dynamic> post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = post['imageUrl'] as String? ?? '';
    final crowdLevel = (post['crowdingLevel'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    ColoredBox(color: Colors.grey.shade300),
              )
            else
              ColoredBox(color: Colors.grey.shade300),
            Positioned(
              top: 4,
              right: 4,
              child: CrowdMeter(level: crowdLevel, size: 32),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar;
  }
}
