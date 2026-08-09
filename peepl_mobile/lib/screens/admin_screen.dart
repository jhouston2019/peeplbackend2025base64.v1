import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/peepl_app_tokens.dart';

const Color _kPeeplBlue = PeeplAppTokens.shellNavy;

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
    const String adminUid = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }
    if (user.uid != adminUid) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _allowed = true;
      _gateResolved = true;
    });
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
                decoration: PeeplAppTokens.shellBodyDecoration(),
                child: Column(
                  children: [
                    Material(
                      color: PeeplAppTokens.textPrimary,
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
            child: const Icon(Icons.arrow_back, color: PeeplAppTokens.textPrimary, size: 28),
          ),
          const SizedBox(width: 16),
          const Text(
            'Admin',
            style: TextStyle(
              color: PeeplAppTokens.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, '/admin/seed_locations'),
            child: const Text(
              'Seed Locations',
              style: TextStyle(color: PeeplAppTokens.textPrimary),
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
            style: TextStyle(fontSize: 12, color: PeeplAppTokens.textSecondary),
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
  const _NativeAdsTab();

  static String _advertiserLabel(Map<String, dynamic> data) {
    final advertiser = data['advertiser'] as String?;
    if (advertiser != null && advertiser.trim().isNotEmpty) {
      return advertiser.trim();
    }
    return (data['advertiserName'] as String?) ??
        (data['headline'] as String?) ??
        (data['title'] as String?) ??
        'Untitled ad';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplAppTokens.background,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
            return const Center(
              child: Text('No native ads. Tap + to create one.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();
              final name = _advertiserLabel(d);
              final active = d['isActive'] == true;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('ID: ${doc.id}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: active,
                        activeThumbColor: _kPeeplBlue,
                        onChanged: (v) => _setAdActive(context, doc.id, v),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: _kPeeplBlue),
                        tooltip: 'Edit',
                        onPressed: () => _showAdForm(
                          context,
                          adId: doc.id,
                          initialData: d,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red),
                        tooltip: 'Delete',
                        onPressed: () =>
                            _confirmDeleteAd(context, doc.id, name),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _kPeeplBlue,
        onPressed: () => _showAdForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  static Future<void> _showAdForm(
    BuildContext context, {
    String? adId,
    Map<String, dynamic>? initialData,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AdFormSheet(
        adId: adId,
        initialData: initialData,
      ),
    );
  }

  static Future<void> _setAdActive(
    BuildContext context,
    String adId,
    bool isActive,
  ) async {
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

  static Future<void> _confirmDeleteAd(
    BuildContext context,
    String adId,
    String advertiserName,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete ad'),
        content: Text('Permanently delete "$advertiserName"?'),
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
          .collection('native_ads')
          .doc(adId)
          .delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad deleted.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete ad: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _AdFormSheet extends StatefulWidget {
  const _AdFormSheet({this.adId, this.initialData});

  final String? adId;
  final Map<String, dynamic>? initialData;

  bool get isEditing => adId != null && adId!.isNotEmpty;

  @override
  State<_AdFormSheet> createState() => _AdFormSheetState();
}

class _AdFormSheetState extends State<_AdFormSheet> {
  final _advertiserCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _ctaCtrl = TextEditingController(text: 'Learn More');
  final _discountCtrl = TextEditingController();
  final _targetLocationCtrl = TextEditingController();

  late DateTime _startDate;
  late DateTime _endDate;
  bool _isActive = true;
  double _priority = 5;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate.add(const Duration(days: 30));

    if (data != null) {
      _advertiserCtrl.text = (data['advertiser'] as String?) ??
          (data['advertiserName'] as String?) ??
          (data['headline'] as String?) ??
          '';
      _taglineCtrl.text = (data['tagline'] as String?) ??
          (data['subline'] as String?) ??
          (data['bodyText'] as String?) ??
          '';
      _ctaCtrl.text = (data['cta'] as String?) ??
          (data['ctaText'] as String?) ??
          'Learn More';
      _discountCtrl.text = (data['discount'] as String?) ?? '';

      final targets = data['targetLocations'];
      if (targets is List && targets.isNotEmpty) {
        _targetLocationCtrl.text = targets.first.toString();
      } else if (targets is String) {
        _targetLocationCtrl.text = targets;
      }

      final start = data['startDate'];
      if (start is Timestamp) {
        final d = start.toDate();
        _startDate = DateTime(d.year, d.month, d.day);
      }
      final end = data['endDate'];
      if (end is Timestamp) {
        final d = end.toDate();
        _endDate = DateTime(d.year, d.month, d.day);
      }

      _isActive = (data['isActive'] as bool?) ?? true;
      _priority = ((data['priority'] as num?)?.toDouble() ?? 5).clamp(1, 10);
    }
  }

  @override
  void dispose() {
    _advertiserCtrl.dispose();
    _taglineCtrl.dispose();
    _ctaCtrl.dispose();
    _discountCtrl.dispose();
    _targetLocationCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        if (!_endDate.isAfter(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
      } else {
        _endDate = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  Future<void> _save() async {
    final advertiser = _advertiserCtrl.text.trim();
    final tagline = _taglineCtrl.text.trim();
    final cta = _ctaCtrl.text.trim().isEmpty ? 'Learn More' : _ctaCtrl.text.trim();
    final discount = _discountCtrl.text.trim();
    final targetLocation = _targetLocationCtrl.text.trim();

    if (advertiser.isEmpty || tagline.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Advertiser name and tagline are required.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_endDate.isAfter(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date must be after start date.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final payload = <String, dynamic>{
      'advertiser': advertiser,
      'tagline': tagline,
      'cta': cta,
      'discount': discount,
      'startDate': Timestamp.fromDate(_startDate),
      'endDate': Timestamp.fromDate(_endDate),
      'isActive': _isActive,
      'priority': _priority.round(),
    };

    if (targetLocation.isNotEmpty) {
      payload['targetLocations'] = [targetLocation];
    } else if (widget.isEditing) {
      payload['targetLocations'] = FieldValue.delete();
    }

    try {
      final collection =
          FirebaseFirestore.instance.collection('native_ads');
      if (widget.isEditing) {
        await collection.doc(widget.adId).update(payload);
      } else {
        await collection.add({
          ...payload,
          'impressions': 0,
          'clicks': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing ? 'Ad updated.' : 'Ad created.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save ad: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  widget.isEditing ? 'Edit Ad' : 'New Ad',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kPeeplBlue,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _advertiserCtrl,
              decoration: const InputDecoration(
                labelText: 'Advertiser name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taglineCtrl,
              decoration: const InputDecoration(
                labelText: 'Tagline *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctaCtrl,
              decoration: const InputDecoration(
                labelText: 'CTA button text',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _discountCtrl,
              decoration: const InputDecoration(
                labelText: 'Discount / offer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetLocationCtrl,
              decoration: const InputDecoration(
                labelText: 'Target location',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start date'),
              subtitle: Text(_formatDate(_startDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _saving ? null : () => _pickDate(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End date *'),
              subtitle: Text(_formatDate(_endDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _saving ? null : () => _pickDate(isStart: false),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Is Active'),
              value: _isActive,
              activeThumbColor: _kPeeplBlue,
              onChanged: _saving ? null : (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Priority'),
                Text('${_priority.round()}'),
              ],
            ),
            Slider(
              value: _priority,
              min: 1,
              max: 10,
              divisions: 9,
              label: '${_priority.round()}',
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _priority = v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: _kPeeplBlue),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PeeplAppTokens.textPrimary,
                        ),
                      )
                    : Text(widget.isEditing ? 'Save Changes' : 'Create Ad'),
              ),
            ),
          ],
        ),
      ),
    );
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
    {'label': 'Splash', 'route': '/splash'},
    {'label': 'No Connection', 'route': '/no_connection'},
    {'label': 'Peep Submitted', 'route': '/peep_submitted'},
    {'label': 'Location detail (demo)', 'route': '/location_detail_demo'},
    {'label': 'Location detail', 'route': '/location_detail'},
  ];

  static final List<Map<String, String>> _onboardingRoutes = [
    {'label': 'Onboarding', 'route': '/onboarding'},
    {'label': 'Onboarding Step 1', 'route': '/onboarding/1'},
    {'label': 'Onboarding Step 2', 'route': '/onboarding/2'},
    {'label': 'Onboarding Step 3', 'route': '/onboarding/3'},
    {'label': 'Permissions (combined)', 'route': '/permissions'},
    {'label': 'Location Permission', 'route': '/permissions/location'},
    {'label': 'Push Permission', 'route': '/permissions/push'},
    {'label': 'Sign Up Confirmed', 'route': '/sign_up_confirmed'},
  ];

  static final List<Map<String, String>> _userRoutes = [
    {'label': 'Account Info', 'route': '/account_info'},
    {'label': 'Create Peep', 'route': '/create_peep'},
    {'label': 'Deal Claimed', 'route': '/deal_claimed'},
    {'label': 'Deals', 'route': '/deals'},
    {'label': 'Favorites', 'route': '/favorites'},
    {'label': 'Follow List', 'route': '/follow_list'},
    {'label': 'Gallery', 'route': '/gallery'},
    {'label': 'Get Peeps', 'route': '/get_peeps'},
    {'label': 'Groups', 'route': '/groups'},
    {'label': 'Heat Map', 'route': '/heat_map'},
    {'label': 'Invite', 'route': '/invite'},
    {'label': 'Leaderboard', 'route': '/leaderboard'},
    {'label': 'Likers', 'route': '/likers'},
    {'label': 'Map', 'route': '/map'},
    {'label': 'Menu', 'route': '/menu'},
    {'label': 'My Peeps', 'route': '/my_peeps'},
    {'label': 'Notifications', 'route': '/notifications'},
    {'label': 'Peep Detail', 'route': '/peep_detail'},
    {'label': 'Pioneer Congrat', 'route': '/pioneer_congrat'},
    {'label': 'Pioneers', 'route': '/pioneers'},
    {'label': 'Report', 'route': '/report'},
    {'label': 'Scoreboard', 'route': '/scoreboard'},
    {'label': 'Search', 'route': '/search'},
    {'label': 'Search Results', 'route': '/search_results'},
    {'label': 'Share', 'route': '/share'},
    {'label': 'Trending', 'route': '/trending'},
    {'label': 'User Profile', 'route': '/user_profile'},
    {'label': 'Venue List', 'route': '/venue_list'},
    {'label': 'Venue', 'route': '/venue'},
    {'label': 'VIP Peeps', 'route': '/vip_peeps'},
  ];

  static final List<Map<String, String>> _merchantRoutes = [
    {'label': 'Merchant Portal', 'route': '/merchant_portal'},
    {'label': 'Merchant Account Info', 'route': '/merchant_account_info'},
    {'label': 'Merchant Account Number', 'route': '/merchant_account_number'},
    {'label': 'Merchant Activity', 'route': '/merchant_activity'},
    {'label': 'Merchant Portal', 'route': '/merchant_portal'},
    {'label': 'Merchant Setup Step 1', 'route': '/merchant_setup_step1'},
    {'label': 'Merchant Setup Step 2', 'route': '/merchant_setup_step2'},
    {'label': 'Create Campaign', 'route': '/merchant_setup_step2'},
    {'label': 'Merchant Sign In', 'route': '/merchant_sign_in'},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        _buildSection(context, 'Main', _mainRoutes),
        _buildSection(context, 'Onboarding & Permissions', _onboardingRoutes),
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
                style: TextStyle(fontSize: 12, color: PeeplAppTokens.textSecondary),
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
