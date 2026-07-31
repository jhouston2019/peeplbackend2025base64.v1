import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/peepl_app_tokens.dart';

import '../widgets/crowd_meter.dart';
import 'location_detail_screen.dart';

const _kCategories = <String>[
  'All',
  'Friends',
  'Neighborhood',
  'Venue',
  'Interest',
  'Other',
];

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  late final TabController _tabController;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Group'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Group name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PeeplAppTokens.shellNavy,
              foregroundColor: PeeplAppTokens.textPrimary,
            ),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    final name = nameCtrl.text.trim();
    nameCtrl.dispose();

    if (created == true && name.isNotEmpty) {
      await _createGroup(name);
    }
  }

  Future<void> _createGroup(String name) async {
    if (_uid.isEmpty) return;
    try {
      final ref = await _db.collection('groups').add({
        'name': name,
        'createdBy': _uid,
        'members': [_uid],
        'createdAt': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
        'isPrivate': false,
        'category': 'Other',
        'memberCount': 1,
      });
      await _db.collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3').doc(_uid).collection('groups').doc(ref.id).set({
        'name': name,
        'groupId': ref.id,
        'joinedAt': FieldValue.serverTimestamp(),
        'lastReadAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create group.')),
        );
      }
    }
  }

  void _openGroupFeed(String groupId, String groupName, List<String> members) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => _GroupFeedScreen(
          groupId: groupId,
          groupName: groupName,
          members: members,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplAppTokens.shellNavy,
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              backgroundColor: PeeplAppTokens.background,
              foregroundColor: PeeplAppTokens.accentBlue,
              onPressed: _showCreateDialog,
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            _buildTabBar(),
            Expanded(
              child: Container(
                decoration: PeeplAppTokens.shellBodyDecoration(),
                clipBehavior: Clip.antiAlias,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _MyGroupsTab(
                      uid: _uid,
                      onOpenFeed: _openGroupFeed,
                    ),
                    _DiscoverGroupsTab(uid: _uid),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: PeeplAppTokens.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            '👥  Groups',
            style: TextStyle(
              color: PeeplAppTokens.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      onTap: (_) => setState(() {}),
      indicatorColor: Colors.white,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      tabs: const [
        Tab(text: 'My Groups'),
        Tab(text: 'Discover Groups'),
      ],
    );
  }
}

// ── My Groups tab ─────────────────────────────────────────────────────────────

class _MyGroupsTab extends StatelessWidget {
  const _MyGroupsTab({
    required this.uid,
    required this.onOpenFeed,
  });

  final String uid;
  final void Function(String groupId, String groupName, List<String> members)
      onOpenFeed;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const Center(child: Text('Not signed in.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('👥', style: TextStyle(fontSize: 52)),
                  SizedBox(height: 14),
                  Text(
                    'No groups yet',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: PeeplAppTokens.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Create one with + or discover groups to join',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: PeeplAppTokens.textMuted),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] as String?) ?? 'Group';
            final members = (data['members'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            final memberCount = (data['memberCount'] as num?)?.toInt() ??
                members.length;
            return _GroupCard(
              groupId: doc.id,
              name: name,
              memberCount: memberCount,
              lastActivity: data['lastActivity'] ?? data['createdAt'],
              category: data['category'] as String?,
              uid: uid,
              showUnread: true,
              onTap: () => onOpenFeed(doc.id, name, members),
            );
          },
        );
      },
    );
  }
}

// ── Discover Groups tab ───────────────────────────────────────────────────────

class _DiscoverGroupsTab extends StatefulWidget {
  const _DiscoverGroupsTab({required this.uid});

  final String uid;

  @override
  State<_DiscoverGroupsTab> createState() => _DiscoverGroupsTabState();
}

class _DiscoverGroupsTabState extends State<_DiscoverGroupsTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _joinGroup(String groupId, List<dynamic> currentMembers) async {
    if (widget.uid.isEmpty) return;
    if (currentMembers.map((e) => e.toString()).contains(widget.uid)) return;

    try {
      final updated = [...currentMembers.map((e) => e.toString()), widget.uid];
      await FirebaseFirestore.instance.collection('groups').doc(groupId).update({
        'members': updated,
        'memberCount': updated.length,
      });
      final groupDoc =
          await FirebaseFirestore.instance.collection('groups').doc(groupId).get();
      final name = groupDoc.data()?['name'] as String? ?? 'Group';
      await FirebaseFirestore.instance
          .collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3')
          .doc(widget.uid)
          .collection('groups')
          .doc(groupId)
          .set({
        'name': name,
        'groupId': groupId,
        'joinedAt': FieldValue.serverTimestamp(),
        'lastReadAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not join group: $e')),
        );
      }
    }
  }

  bool _matchesCategory(String? category) {
    if (_selectedCategory == 'All') return true;
    final raw = (category ?? 'Other').toLowerCase();
    return raw == _selectedCategory.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search groups by name...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _kCategories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = _kCategories[i];
              final selected = _selectedCategory == cat;
              return FilterChip(
                label: Text(cat),
                selected: selected,
                onSelected: (_) => setState(() => _selectedCategory = cat),
                selectedColor: PeeplAppTokens.accentBlue.withValues(alpha: 0.2),
                checkmarkColor: PeeplAppTokens.accentBlue,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('groups').snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var docs = (snap.data?.docs ?? []).where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['isPrivate'] != true;
              }).toList();
              docs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] as String? ?? '').toLowerCase();
                if (_searchQuery.isNotEmpty && !name.contains(_searchQuery)) {
                  return false;
                }
                return _matchesCategory(data['category'] as String?);
              }).toList();

              docs.sort((a, b) {
                final ma = _memberCount(a.data() as Map<String, dynamic>);
                final mb = _memberCount(b.data() as Map<String, dynamic>);
                return mb.compareTo(ma);
              });

              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No public groups match your search',
                    style: TextStyle(color: PeeplAppTokens.textMuted),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] as String?) ?? 'Group';
                  final members = data['members'] as List<dynamic>? ?? [];
                  final isMember =
                      members.map((e) => e.toString()).contains(widget.uid);

                  return _GroupCard(
                    groupId: doc.id,
                    name: name,
                    memberCount: _memberCount(data),
                    lastActivity: data['lastActivity'] ?? data['createdAt'],
                    category: data['category'] as String?,
                    uid: widget.uid,
                    showUnread: false,
                    trailing: isMember
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: PeeplAppTokens.cardElevated,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Joined',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : TextButton(
                            onPressed: () => _joinGroup(doc.id, members),
                            style: TextButton.styleFrom(
                              backgroundColor: PeeplAppTokens.shellNavy,
                              foregroundColor: PeeplAppTokens.textPrimary,
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
                            child: const Text(
                              'Join',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  static int _memberCount(Map<String, dynamic> data) {
    final stored = (data['memberCount'] as num?)?.toInt();
    if (stored != null) return stored;
    return (data['members'] as List<dynamic>?)?.length ?? 0;
  }
}

// ── Group card ────────────────────────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.groupId,
    required this.name,
    required this.memberCount,
    required this.lastActivity,
    required this.uid,
    required this.showUnread,
    this.category,
    this.onTap,
    this.trailing,
  });

  final String groupId;
  final String name;
  final int memberCount;
  final dynamic lastActivity;
  final String? category;
  final String uid;
  final bool showUnread;
  final VoidCallback? onTap;
  final Widget? trailing;

  static List<Color> _paletteFor(String name) {
    const palettes = [
      [PeeplAppTokens.shellNavy, PeeplAppTokens.accentBlue],
      [Color(0xFF1B5E20), Color(0xFF388E3C)],
      [Color(0xFF4A148C), Color(0xFF7B1FA2)],
      [Color(0xFF004D40), Color(0xFF00796B)],
      [Color(0xFF7F0000), Color(0xFFC62828)],
    ];
    final idx = name.isNotEmpty ? name.codeUnitAt(0) % palettes.length : 0;
    return palettes[idx];
  }

  static String _formatActivity(dynamic ts) {
    if (ts is! Timestamp) return 'No activity yet';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return 'Active ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Active ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Active ${diff.inDays}d ago';
    return 'Active ${ts.toDate().month}/${ts.toDate().day}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = _paletteFor(name);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Material(
      color: PeeplAppTokens.textPrimary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PeeplAppTokens.cardElevated),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: PeeplAppTokens.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$memberCount ${memberCount == 1 ? 'member' : 'members'} · ${_formatActivity(lastActivity)}',
                      style: TextStyle(fontSize: 12, color: PeeplAppTokens.textSecondary),
                    ),
                    if (category != null && category!.isNotEmpty)
                      Text(
                        category!,
                        style: TextStyle(fontSize: 11, color: PeeplAppTokens.textMuted),
                      ),
                  ],
                ),
              ),
              if (showUnread && uid.isNotEmpty)
                _UnreadBadge(groupId: groupId, uid: uid),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (onTap != null)
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.groupId, required this.uid});

  final String groupId;
  final String uid;

  Future<int> _unreadCount() async {
    try {
      final db = FirebaseFirestore.instance;
      final groupDoc = await db.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return 0;

      final members = (groupDoc.data()?['members'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((id) => id.isNotEmpty)
              .toList() ??
          [];
      if (members.isEmpty) return 0;

      final readDoc = await db
          .collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3')
          .doc(uid)
          .collection('groups')
          .doc(groupId)
          .get();
      final lastRead = readDoc.data()?['lastReadAt'];

      var count = 0;
      for (var i = 0; i < members.length; i += 10) {
        final chunk = members.sublist(
          i,
          i + 10 > members.length ? members.length : i + 10,
        );
        Query<Map<String, dynamic>> q = db
            .collection('location_posts')
            .where('userId', whereIn: chunk);
        final snap = await q.limit(40).get();
        for (final doc in snap.docs) {
          final ts = doc.data()['timestamp'];
          if (lastRead is Timestamp) {
            if (ts is Timestamp && ts.compareTo(lastRead) <= 0) continue;
          }
          count++;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _unreadCount(),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        if (count <= 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(
              color: PeeplAppTokens.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

// ── Group feed ────────────────────────────────────────────────────────────────

class _GroupFeedScreen extends StatefulWidget {
  const _GroupFeedScreen({
    required this.groupId,
    required this.groupName,
    required this.members,
  });

  final String groupId;
  final String groupName;
  final List<String> members;

  @override
  State<_GroupFeedScreen> createState() => _GroupFeedScreenState();
}

class _GroupFeedScreenState extends State<_GroupFeedScreen> {
  final _db = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _markRead();
  }

  Future<void> _markRead() async {
    if (_uid.isEmpty) return;
    try {
      await _db.collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3').doc(_uid).collection('groups').doc(widget.groupId).set(
        {'lastReadAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final members = widget.members.where((m) => m.isNotEmpty).toList();
      final allPosts = <Map<String, dynamic>>[];

      for (var i = 0; i < members.length; i += 10) {
        final chunk = members.sublist(
          i,
          i + 10 > members.length ? members.length : i + 10,
        );
        final snap = await _db
            .collection('location_posts')
            .where('userId', whereIn: chunk)
            .limit(40)
            .get();
        for (final doc in snap.docs) {
          allPosts.add({...doc.data(), 'id': doc.id});
        }
      }

      allPosts.sort((a, b) {
        final ta = a['timestamp'];
        final tb = b['timestamp'];
        if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
        return 0;
      });

      if (mounted) {
        setState(() {
          _posts = allPosts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _formatTime(dynamic ts) {
    if (ts is! Timestamp) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${ts.toDate().month}/${ts.toDate().day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplAppTokens.shellNavy,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: PeeplAppTokens.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      widget.groupName,
                      style: const TextStyle(
                        color: PeeplAppTokens.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: PeeplAppTokens.shellBodyDecoration(),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _posts.isEmpty
                        ? const Center(
                            child: Text(
                              'No posts from group members yet',
                              style: TextStyle(color: PeeplAppTokens.textMuted),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadPosts,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _posts.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final post = _posts[i];
                                final locationName =
                                    post['locationName'] as String? ?? 'Unknown';
                                final username =
                                    post['username'] as String? ?? 'User';
                                final level =
                                    (post['crowdingLevel'] as num?)?.toInt() ?? 0;

                                return Material(
                                  color: PeeplAppTokens.textPrimary,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (context) =>
                                            LocationDetailScreen(postData: post),
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: PeeplAppTokens.cardElevated,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  locationName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: PeeplAppTokens.accentBlue,
                                                  ),
                                                ),
                                                Text(
                                                  'by $username · ${_formatTime(post['timestamp'])}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: PeeplAppTokens.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          CrowdMeter(level: level, size: 48),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
