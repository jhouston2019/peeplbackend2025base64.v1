import 'dart:math' as math;
import '../theme/peepl_app_tokens.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../widgets/crowd_meter.dart';
import 'location_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _initLocation();
  }

  Future<void> _initLocation() async {
    final pos = await LocationService.getCurrentLocation();
    if (!mounted || pos == null) return;
    setState(() {
      _userLat = pos.latitude;
      _userLng = pos.longitude;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterPosts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final posts = docs
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .where((post) {
      final imageUrl = (post['imageUrl'] ?? '').toString().trim();
      return imageUrl.isNotEmpty;
    }).toList();

    if (_searchQuery.isEmpty) return posts;

    final q = _searchQuery.toLowerCase();
    return posts.where((post) {
      final name = (post['locationName'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  int _crowdingLevel(Map<String, dynamic> post) {
    final ai = post['aiScore'];
    if (ai is num) return ai.round().clamp(0, 10);
    final level = post['crowdingLevel'];
    if (level is num) return level.round().clamp(0, 10);
    return 0;
  }

  String _relativeTime(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime? dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else {
      try {
        dt = (timestamp as dynamic).toDate() as DateTime;
      } catch (_) {
        return '';
      }
    }
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  double? _milesTo(Map<String, dynamic> post) {
    if (_userLat == null || _userLng == null) return null;
    final lat = post['latitude'];
    final lng = post['longitude'];
    if (lat is! num || lng is! num) return null;
    return _haversineMiles(
      _userLat!,
      _userLng!,
      lat.toDouble(),
      lng.toDouble(),
    );
  }

  double _haversineMiles(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const radiusMiles = 3958.8;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radiusMiles * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * math.pi / 180.0;

  String? _subtitleLine(Map<String, dynamic> post) {
    final parts = <String>[];
    final miles = _milesTo(post);
    if (miles != null) parts.add('${miles.toStringAsFixed(1)} mi');
    final time = _relativeTime(post['timestamp']);
    if (time.isNotEmpty) parts.add(time);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplAppTokens.background,
      appBar: AppBar(
        title: const Text('Explore'),
        backgroundColor: PeeplAppTokens.shellNavy,
        foregroundColor: PeeplAppTokens.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search for a venue or place...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('location_posts')
                  .orderBy('timestamp', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Could not load venues',
                      style: TextStyle(color: PeeplAppTokens.textSecondary),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final posts = _filterPosts(snapshot.data?.docs ?? []);
                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: PeeplAppTokens.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No venues found',
                          style: TextStyle(
                            fontSize: 16,
                            color: PeeplAppTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return _ExploreVenueCard(
                      name: (post['locationName'] ?? 'Unknown Venue').toString(),
                      subtitle: _subtitleLine(post),
                      crowdLevel: _crowdingLevel(post),
                      imageUrl: (post['imageUrl'] ?? '').toString(),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                LocationDetailScreen(postData: post),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreVenueCard extends StatelessWidget {
  const _ExploreVenueCard({
    required this.name,
    required this.subtitle,
    required this.crowdLevel,
    required this.imageUrl,
    required this.onTap,
  });

  final String name;
  final String? subtitle;
  final int crowdLevel;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 72,
        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: PeeplAppTokens.shellNavy,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: PeeplAppTokens.shellNavy),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PeeplAppTokens.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  CrowdMeter(level: crowdLevel, size: 44),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
