import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class _PioneerEntry {
  final String locationName;
  final String userId;
  final String username;
  final String? photoUrl;
  final dynamic timestamp;
  final int postCount;

  const _PioneerEntry({
    required this.locationName,
    required this.userId,
    required this.username,
    this.photoUrl,
    required this.timestamp,
    this.postCount = 0,
  });
}

class PioneersScreen extends StatefulWidget {
  const PioneersScreen({super.key});

  @override
  State<PioneersScreen> createState() => _PioneersScreenState();
}

class _PioneersScreenState extends State<PioneersScreen> {
  final _db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  late Future<List<_PioneerEntry>> _future;
  String _searchQuery = '';
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _future = _load();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<_PioneerEntry>> _load() async {
    final snap = await _db
        .collection('location_posts')
        .orderBy('timestamp')
        .get();

    final Map<String, Map<String, dynamic>> firstPost = {};
    final Map<String, int> postCounts = {};

    for (final doc in snap.docs) {
      final data = doc.data();
      final venue = (data['locationName'] as String?)?.trim() ?? '';
      if (venue.isEmpty) continue;

      postCounts[venue] = (postCounts[venue] ?? 0) + 1;
      firstPost.putIfAbsent(venue, () => {...data, 'id': doc.id});
    }

    if (firstPost.isEmpty) return [];

    final uniqueUids = firstPost.values
        .map((d) => d['userId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final Map<String, String> usernameMap = {};
    final Map<String, String?> photoMap = {};
    if (uniqueUids.isNotEmpty) {
      final userDocs = await Future.wait(
        uniqueUids.map((id) => _db.collection('users').doc(id).get()),
      );
      for (final doc in userDocs) {
        if (!doc.exists) continue;
        final d = doc.data() as Map<String, dynamic>;
        usernameMap[doc.id] = (d['username'] as String?) ??
            (d['displayName'] as String?) ??
            'Unknown';
        photoMap[doc.id] = d['photoUrl'] as String?;
      }
    }

    final venues = firstPost.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return venues.map((venue) {
      final data = firstPost[venue]!;
      final uid = data['userId'] as String? ?? '';
      final postUsername = data['username'] as String?;
      return _PioneerEntry(
        locationName: venue,
        userId: uid,
        username: usernameMap[uid] ?? postUsername ?? 'Unknown',
        photoUrl: photoMap[uid],
        timestamp: data['timestamp'],
        postCount: postCounts[venue] ?? 0,
      );
    }).toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _openVenue(BuildContext context, String locationName) async {
    final snap = await _db
        .collection('location_posts')
        .where('locationName', isEqualTo: locationName)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (!context.mounted) return;

    final venueData = snap.docs.isNotEmpty
        ? {
            ...snap.docs.first.data(),
            'id': snap.docs.first.id,
          }
        : <String, dynamic>{'locationName': locationName};

    Navigator.pushNamed(context, '/venue', arguments: venueData);
  }

  void _openProfile(BuildContext context, String userId) {
    if (userId.isEmpty) return;
    Navigator.pushNamed(context, '/user_profile', arguments: userId);
  }

  static String _formatDate(dynamic ts) {
    if (ts == null) return '';
    final dt = ts is Timestamp ? ts.toDate() : null;
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  List<_PioneerEntry> _filterEntries(List<_PioneerEntry> entries) {
    if (_searchQuery.isEmpty) return entries;
    return entries
        .where((e) => e.locationName.toLowerCase().contains(_searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(),
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
                child: FutureBuilder<List<_PioneerEntry>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load: ${snap.error}',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      );
                    }
                    final entries = _filterEntries(snap.data ?? []);
                    if (entries.isEmpty) return _buildEmpty();
                    return _buildList(context, entries);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Text(
            '🏅 Pioneers',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
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
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search locations...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.8)),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF00BCD4).withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: const Text(
        'First to Peep each venue',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final message = _searchQuery.isNotEmpty
        ? 'No locations match "$_searchQuery"'
        : 'No Pioneers yet — be the first!';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏅', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<_PioneerEntry> entries) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: entries.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: Colors.grey.shade100),
        itemBuilder: (_, i) => _PioneerRow(
          entry: entries[i],
          dateLabel: _formatDate(entries[i].timestamp),
          isCurrentUser: _currentUserId != null &&
              entries[i].userId == _currentUserId,
          onLocationTap: () => _openVenue(context, entries[i].locationName),
          onProfileTap: () => _openProfile(context, entries[i].userId),
        ),
      ),
    );
  }
}

class _PioneerRow extends StatelessWidget {
  const _PioneerRow({
    required this.entry,
    required this.dateLabel,
    required this.isCurrentUser,
    required this.onLocationTap,
    required this.onProfileTap,
  });

  final _PioneerEntry entry;
  final String dateLabel;
  final bool isCurrentUser;
  final VoidCallback onLocationTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isCurrentUser
          ? BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.55),
                width: 1.5,
              ),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onProfileTap,
            child: _PioneerAvatar(
              username: entry.username,
              photoUrl: entry.photoUrl,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onLocationTap,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      entry.locationName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isCurrentUser
                            ? const Color(0xFFB8860B)
                            : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: onProfileTap,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      entry.username +
                          (dateLabel.isNotEmpty ? ' · $dateLabel' : ''),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.postCount}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isCurrentUser
                      ? const Color(0xFFB8860B)
                      : const Color(0xFF1565C0),
                ),
              ),
              Text(
                'post${entry.postCount == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onLocationTap,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _PioneerAvatar extends StatelessWidget {
  const _PioneerAvatar({
    required this.username,
    this.photoUrl,
  });

  final String username;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.15),
      backgroundImage:
          photoUrl != null && photoUrl!.isNotEmpty ? NetworkImage(photoUrl!) : null,
      child: photoUrl == null || photoUrl!.isEmpty
          ? Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF1565C0),
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}
