import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/peepl_app_tokens.dart';

import '../widgets/crowd_meter.dart';

const _kUsersCollection = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

enum _SortOption {
  recentlyAdded('Recently Added'),
  alphabetical('Alphabetical'),
  mostCrowded('Most Crowded'),
  leastCrowded('Least Crowded');

  const _SortOption(this.label);
  final String label;
}

class _FavoriteItem {
  final String docId;
  final String locationName;
  final dynamic savedAt;
  final int crowdingLevel;
  final dynamic lastUpdated;
  final Map<String, dynamic>? latestPost;

  const _FavoriteItem({
    required this.docId,
    required this.locationName,
    this.savedAt,
    this.crowdingLevel = 0,
    this.lastUpdated,
    this.latestPost,
  });
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _db = FirebaseFirestore.instance;

  List<_FavoriteItem> _items = [];
  bool _loading = true;
  String? _error;
  _SortOption _sort = _SortOption.recentlyAdded;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _displayName =>
      FirebaseAuth.instance.currentUser?.displayName ??
      FirebaseAuth.instance.currentUser?.email?.split('@').first ??
      'User';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    if (_uid.isEmpty) {
      setState(() {
        _loading = false;
        _items = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final favSnap = await _db
          .collection(_kUsersCollection)
          .doc(_uid)
          .collection('favorites')
          .get();

      final items = await Future.wait(
        favSnap.docs.map((doc) async {
          final data = doc.data();
          final locationName =
              (data['locationName'] as String?)?.trim() ??
                  doc.id.trim();

          final postSnap = await _db
              .collection('location_posts')
              .where('locationName', isEqualTo: locationName)
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          Map<String, dynamic>? latestPost;
          int crowdingLevel = 0;
          dynamic lastUpdated;

          if (postSnap.docs.isNotEmpty) {
            latestPost = {
              ...postSnap.docs.first.data(),
              'id': postSnap.docs.first.id,
            };
            crowdingLevel =
                (latestPost['crowdingLevel'] as num?)?.toInt() ?? 0;
            lastUpdated = latestPost['timestamp'];
          }

          return _FavoriteItem(
            docId: doc.id,
            locationName: locationName.isNotEmpty ? locationName : 'Unknown venue',
            savedAt: data['savedAt'] ?? data['lastVisited'],
            crowdingLevel: crowdingLevel,
            lastUpdated: lastUpdated,
            latestPost: latestPost,
          );
        }),
      );

      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load favorites. Pull to retry.';
        });
      }
    }
  }

  List<_FavoriteItem> get _sortedItems {
    final list = List<_FavoriteItem>.from(_items);
    switch (_sort) {
      case _SortOption.recentlyAdded:
        list.sort((a, b) => _timestampCompare(b.savedAt, a.savedAt));
      case _SortOption.alphabetical:
        list.sort(
          (a, b) => a.locationName.toLowerCase().compareTo(
                b.locationName.toLowerCase(),
              ),
        );
      case _SortOption.mostCrowded:
        list.sort((a, b) {
          final cmp = b.crowdingLevel.compareTo(a.crowdingLevel);
          return cmp != 0 ? cmp : a.locationName.compareTo(b.locationName);
        });
      case _SortOption.leastCrowded:
        list.sort((a, b) {
          final cmp = a.crowdingLevel.compareTo(b.crowdingLevel);
          return cmp != 0 ? cmp : a.locationName.compareTo(b.locationName);
        });
    }
    return list;
  }

  static int _timestampCompare(dynamic a, dynamic b) {
    final da = _toDate(a);
    final db = _toDate(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  static DateTime? _toDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return null;
  }

  static String _formatLastUpdated(dynamic ts) {
    final dt = _toDate(ts);
    if (dt == null) return 'No recent updates';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Updated ${diff.inDays}d ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Updated ${months[dt.month - 1]} ${dt.day}';
  }

  Future<void> _deleteFavorite(String docId) async {
    if (_uid.isEmpty) return;
    try {
      await _db
          .collection(_kUsersCollection)
          .doc(_uid)
          .collection('favorites')
          .doc(docId)
          .delete();
      if (mounted) {
        setState(() => _items.removeWhere((item) => item.docId == docId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove: $e')),
        );
      }
    }
  }

  void _openVenue(_FavoriteItem item) {
    final venueData = item.latestPost ??
        <String, dynamic>{'locationName': item.locationName};
    Navigator.pushNamed(context, '/venue', arguments: venueData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplAppTokens.shellNavy,
      body: SafeArea(
        child: Column(
          children: [
            _buildBanner(context),
            _buildSortBar(),
            _buildSectionHeader(),
            Expanded(
              child: Container(
                decoration: PeeplAppTokens.shellBodyDecoration(),
                child: _uid.isEmpty
                    ? const Center(child: Text('Not signed in'))
                    : _buildBody(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    final name = _displayName;
    return Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: PeeplAppTokens.textPrimary),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: PeeplAppTokens.background.withValues(alpha: 0.25),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: PeeplAppTokens.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Favorites',
              style: TextStyle(
                color: PeeplAppTokens.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              if (_items.length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Save at least 2 favorites to compare.'),
                  ),
                );
                return;
              }
              Navigator.pushNamed(
                context,
                '/where_should_we_go',
                arguments: {
                  'presetVenueNames':
                      _items.map((item) => item.locationName).toList(),
                },
              );
            },
            child: const Text(
              'Compare',
              style: TextStyle(
                color: PeeplAppTokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Icon(Icons.sort, color: Colors.white.withValues(alpha: 0.85), size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_SortOption>(
                value: _sort,
                isExpanded: true,
                dropdownColor: PeeplAppTokens.accentBlue,
                iconEnabledColor: Colors.white,
                style: const TextStyle(color: PeeplAppTokens.textPrimary, fontSize: 13),
                items: _SortOption.values
                    .map(
                      (opt) => DropdownMenuItem(
                        value: opt,
                        child: Text(opt.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _sort = value);
                },
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
        'Saved venues',
        style: TextStyle(
          color: PeeplAppTokens.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _loadFavorites,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      );
    }

    final items = _sortedItems;
    if (items.isEmpty) return _buildEmpty();

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _FavoriteCard(
          item: items[i],
          lastUpdatedLabel: _formatLastUpdated(items[i].lastUpdated),
          onTap: () => _openVenue(items[i]),
          onDelete: () => _deleteFavorite(items[i].docId),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.14),
          const Column(
            children: [
              Text('⭐', style: TextStyle(fontSize: 52)),
              SizedBox(height: 14),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'No favorites yet — tap the ⭐ on any venue to save it here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: PeeplAppTokens.textMuted,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.item,
    required this.lastUpdatedLabel,
    required this.onTap,
    required this.onDelete,
  });

  final _FavoriteItem item;
  final String lastUpdatedLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PeeplAppTokens.textPrimary,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PeeplAppTokens.cardElevated),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.locationName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: PeeplAppTokens.accentBlue,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lastUpdatedLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: PeeplAppTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CrowdMeter(level: item.crowdingLevel, size: 56),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: PeeplAppTokens.textMuted),
                tooltip: 'Remove favorite',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
