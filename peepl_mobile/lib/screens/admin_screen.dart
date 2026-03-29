import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color _kPeeplBlue = Color(0xFF1565C0);

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _gateResolved = false;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _checkAdminGate();
  }

  Future<void> _checkAdminGate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3')
          .doc(user.uid)
          .get();
      final ok = doc.data()?['isAdmin'] == true;
      if (!mounted) return;
      if (!ok) {
        Navigator.of(context).pushNamedAndRemoveUntil('/feed', (_) => false);
        return;
      }
      setState(() {
        _allowed = true;
        _gateResolved = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not verify admin access: $e'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/feed', (_) => false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_gateResolved) {
      return const Scaffold(
        backgroundColor: _kPeeplBlue,
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }
    if (!_allowed) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: _kPeeplBlue,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Material(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        labelColor: _kPeeplBlue,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: _kPeeplBlue,
                        isScrollable: true,
                        tabs: const [
                          Tab(text: 'Users'),
                          Tab(text: 'Posts'),
                          Tab(text: 'Stats'),
                          Tab(text: 'Ads'),
                          Tab(text: 'Screens'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _UsersTab(),
                          _PostsTab(),
                          _StatsTab(),
                          _NativeAdsTab(),
                          _ScreensTab(),
                        ],
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

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Text(
            'Admin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatJoinDate(dynamic raw) {
  if (raw is Timestamp) {
    final d = raw.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
  return '—';
}

class _UsersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorCenter('Failed to load users: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _kPeeplBlue),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No user documents yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final d = doc.data();
            final email = d['email'] as String? ?? '—';
            final username = d['username'] as String? ??
                d['displayName'] as String? ??
                (doc.id.length <= 8
                    ? doc.id
                    : doc.id.substring(0, 8));
            final joined = _formatJoinDate(
                d['joinDate'] ?? d['createdAt'] ?? d['joinedAt']);
            final banned = d['isBanned'] == true;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(email,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('Username: $username',
                        style: TextStyle(color: Colors.grey[700])),
                    Text('Join date: $joined',
                        style: TextStyle(color: Colors.grey[700])),
                    if (banned)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'BANNED',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: banned
                              ? null
                              : () => _confirmBan(context, doc.id),
                          icon: const Icon(Icons.block, size: 18),
                          label: const Text('Ban'),
                          style: TextButton.styleFrom(foregroundColor: Colors.orange[800]),
                        ),
                        TextButton.icon(
                          onPressed: () => _confirmDeleteUser(context, doc.id),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Delete'),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmBan(BuildContext context, String userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ban user'),
        content: const Text(
            'Mark this user as banned in Firestore (isBanned: true)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ban'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await FirebaseFirestore.instance.collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3').doc(userId).update({
        'isBanned': true,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User marked as banned.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ban user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteUser(BuildContext context, String userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete user document'),
        content: const Text(
            'Remove this user document? This does not delete the Auth account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await FirebaseFirestore.instance.collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3').doc(userId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User document deleted.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _PostsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('location_posts')
          .orderBy('timestamp', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorCenter('Failed to load posts: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _kPeeplBlue),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No posts.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final d = doc.data();
            final location = d['locationName'] as String? ?? '—';
            final username = d['username'] as String? ?? '—';
            final level = (d['crowdingLevel'] as num?)?.toInt() ?? 0;
            final ts = d['timestamp'];
            String timeStr = '—';
            if (ts is Timestamp) {
              final x = ts.toDate();
              timeStr =
                  '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')} '
                  '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(location,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '$username · crowding $level\n$timeStr',
                  style: TextStyle(color: Colors.grey[700], height: 1.35),
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDeletePost(context, doc.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeletePost(BuildContext context, String postId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post'),
        content: const Text('Permanently delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection('location_posts')
          .doc(postId)
          .delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _StatsTab extends StatefulWidget {
  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  bool _loading = true;
  String? _error;
  int _userCount = 0;
  int _postCount = 0;
  int _totalLikes = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final usersAgg = await FirebaseFirestore.instance
          .collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3')
          .count()
          .get();
      final postsAgg = await FirebaseFirestore.instance
          .collection('location_posts')
          .count()
          .get();

      int likes = 0;
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance
          .collection('location_posts')
          .limit(300);
      while (true) {
        final snap = await q.get();
        for (final doc in snap.docs) {
          final n = doc.data()['likesCount'];
          if (n is num) likes += n.toInt();
        }
        if (snap.docs.length < 300) break;
        q = FirebaseFirestore.instance
            .collection('location_posts')
            .startAfterDocument(snap.docs.last)
            .limit(300);
      }

      if (!mounted) return;
      setState(() {
        _userCount = usersAgg.count ?? 0;
        _postCount = postsAgg.count ?? 0;
        _totalLikes = likes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _kPeeplBlue),
      );
    }
    if (_error != null) {
      return _errorCenter(_error!);
    }
    return RefreshIndicator(
      color: _kPeeplBlue,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _statCard('Total users', _userCount.toString()),
          const SizedBox(height: 16),
          _statCard('Total posts', _postCount.toString()),
          const SizedBox(height: 16),
          _statCard('Total likes (sum of likesCount)', _totalLikes.toString()),
          const SizedBox(height: 24),
          Text(
            'Likes total sums each post likesCount field (paginated reads).',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPeeplBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _kPeeplBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _NativeAdsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('native_ads').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorCenter('Failed to load ads: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _kPeeplBlue),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No native ads.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final d = doc.data();
            final title = d['title'] as String? ??
                d['headline'] as String? ??
                doc.id;
            final active = d['isActive'] == true;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: SwitchListTile(
                title: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('ID: ${doc.id}'),
                value: active,
                activeThumbColor: _kPeeplBlue,
                onChanged: (v) => _setAdActive(context, doc.id, v),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _setAdActive(
      BuildContext context, String adId, bool isActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('native_ads')
          .doc(adId)
          .update({'isActive': isActive});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isActive ? 'Ad activated.' : 'Ad deactivated.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update ad: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _ScreensTab extends StatelessWidget {
  const _ScreensTab();

  static final List<Map<String, String>> _mainRoutes = [
    {'label': 'Home (main shell)', 'route': '/home'},
    {'label': 'Feed', 'route': '/feed'},
    {'label': 'Discover', 'route': '/discover'},
    {'label': 'Chat', 'route': '/chat'},
    {'label': 'Profile', 'route': '/profile'},
    {'label': 'Post', 'route': '/post'},
    {'label': 'Settings', 'route': '/settings'},
    {'label': 'Login', 'route': '/login'},
    {'label': 'Admin', 'route': '/admin'},
    {'label': 'Location detail (demo)', 'route': '/location_detail_demo'},
  ];

  static final List<Map<String, String>> _userRoutes = [
    {'label': 'Account Info', 'route': '/account_info'},
    {'label': 'Create Peep', 'route': '/create_peep'},
    {'label': 'Deal Claimed', 'route': '/deal_claimed'},
    {'label': 'Deals', 'route': '/deals'},
    {'label': 'Favorites', 'route': '/favorites'},
    {'label': 'Follow List', 'route': '/follow_list'},
    {'label': 'Get Peeps', 'route': '/get_peeps'},
    {'label': 'Groups', 'route': '/groups'},
    {'label': 'Invite', 'route': '/invite'},
    {'label': 'Leaderboard', 'route': '/leaderboard'},
    {'label': 'Likers', 'route': '/likers'},
    {'label': 'Map', 'route': '/map'},
    {'label': 'Menu', 'route': '/menu'},
    {'label': 'My Peeps', 'route': '/my_peeps'},
    {'label': 'Notifications', 'route': '/notifications'},
    {'label': 'Onboarding', 'route': '/onboarding'},
    {'label': 'Peep Detail', 'route': '/peep_detail'},
    {'label': 'Permissions', 'route': '/permissions'},
    {'label': 'Pioneer Congrat', 'route': '/pioneer_congrat'},
    {'label': 'Pioneers', 'route': '/pioneers'},
    {'label': 'Report', 'route': '/report'},
    {'label': 'Search', 'route': '/search'},
    {'label': 'Share', 'route': '/share'},
    {'label': 'Sign Up Confirmed', 'route': '/sign_up_confirmed'},
    {'label': 'User Profile', 'route': '/user_profile'},
    {'label': 'Venue List', 'route': '/venue_list'},
    {'label': 'Venue', 'route': '/venue'},
    {'label': 'VIP Peeps', 'route': '/vip_peeps'},
  ];

  static final List<Map<String, String>> _merchantRoutes = [
    {'label': 'How To Advertise', 'route': '/how_to_advertise'},
    {'label': 'Merchant Account Info', 'route': '/merchant_account_info'},
    {'label': 'Merchant Account Number', 'route': '/merchant_account_number'},
    {'label': 'Merchant Activity', 'route': '/merchant_activity'},
    {'label': 'Merchant Portal', 'route': '/merchant_portal'},
    {'label': 'Merchant Setup Step 1', 'route': '/merchant_setup_step1'},
    {'label': 'Merchant Setup Step 2', 'route': '/merchant_setup_step2'},
    {'label': 'Merchant Sign In', 'route': '/merchant_sign_in'},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        _buildSection(context, 'Main', _mainRoutes),
        _buildSection(context, 'User', _userRoutes),
        _buildSection(context, 'Merchant', _merchantRoutes),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Map<String, String>> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _kPeeplBlue,
              letterSpacing: 0.6,
            ),
          ),
        ),
        ...items.map(
          (e) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                e['label']!,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                e['route']!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              trailing: OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, e['route']!);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPeeplBlue,
                  side: const BorderSide(color: _kPeeplBlue),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _errorCenter(String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.red),
      ),
    ),
  );
}
