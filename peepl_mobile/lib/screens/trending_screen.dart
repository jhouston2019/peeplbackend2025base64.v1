import 'dart:async';
import 'dart:math' as math;
import '../theme/peepl_app_tokens.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/ad_cadence_service.dart';
import '../services/location_service.dart';
import '../services/native_ads_service.dart';
import '../widgets/ad_card.dart';
import '../widgets/crowd_dot_ring_meter.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

class _VenueTrend {
  final String name;
  final int peepCount;
  final double avgCrowd;
  final int currentCrowdLevel;
  final double? distanceM;
  final String trend; // "↑ Getting busier" | "→ Steady" | "↓ Clearing out"
  final String? imageUrl;
  final String? venueType;
  final Map<String, dynamic> rawPost;

  const _VenueTrend({
    required this.name,
    required this.peepCount,
    required this.avgCrowd,
    required this.currentCrowdLevel,
    this.distanceM,
    required this.trend,
    this.imageUrl,
    this.venueType,
    required this.rawPost,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  final NativeAdsService _adsService = NativeAdsService();
  final AdCadenceService _cadence = AdCadenceService();

  List<_VenueTrend> _venues = [];
  List<Map<String, dynamic>> _ads = [];
  List<Object> _displayItems = []; // _VenueTrend | Map (ad)

  bool _loading = false;
  String? _error;
  DateTime? _lastRefreshed;

  double? _userLat;
  double? _userLng;

  Timer? _refreshTimer;

  // ── Lifecycle ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _bootstrap();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _loadTrending(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── Bootstrap ─────────────────────────────────────────────────────────────────
  Future<void> _bootstrap() async {
    await Future.wait([_initAds(), _loadTrending()]);
  }

  Future<void> _initAds() async {
    await _cadence.init(pattern: [3, 3, 3, 3]);
    final pos = await LocationService.getCurrentLocation();
    if (pos != null && mounted) {
      _userLat = pos.latitude;
      _userLng = pos.longitude;
    }
    try {
      final ads = await _adsService.getAdsForFeed(
        context: 'discover',
        userLat: _userLat,
        userLng: _userLng,
        limit: 8,
      );
      if (mounted) setState(() => _ads = ads);
    } catch (e) {
      debugPrint('TrendingScreen ads: $e');
    }
  }

  // ── Data loading ──────────────────────────────────────────────────────────────
  Future<void> _loadTrending({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() { _loading = _venues.isEmpty; _error = null; });

    try {
      final sixHoursAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 6)),
      );

      final snap = await FirebaseFirestore.instance
          .collection('location_posts')
          .where('timestamp', isGreaterThan: sixHoursAgo)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      // Group posts by locationName — preserving desc timestamp order
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final doc in snap.docs) {
        final data = {'id': doc.id, ...(doc.data() as Map<String, dynamic>)};
        final name = data['locationName'] as String? ?? '';
        if (name.isEmpty) continue;
        grouped.putIfAbsent(name, () => []).add(data);
      }

      // Get user location if not yet resolved
      if (_userLat == null) {
        final pos = await LocationService.getCurrentLocation();
        if (pos != null && mounted) {
          _userLat = pos.latitude;
          _userLng = pos.longitude;
        }
      }

      // Build _VenueTrend per venue
      final venues = <_VenueTrend>[];
      for (final entry in grouped.entries) {
        final posts = entry.value; // already desc timestamp
        final crowdLevels = posts
            .map((p) => (p['crowdingLevel'] as num?)?.toDouble() ?? 0.0)
            .toList();

        final avgCrowd = crowdLevels.reduce((a, b) => a + b) / crowdLevels.length;

        // Last 3 peeps trend vs overall average
        final last3 = crowdLevels.take(3).toList();
        final last3Avg = last3.reduce((a, b) => a + b) / last3.length;
        final diff = last3Avg - avgCrowd;

        final String trend;
        if (diff > 1.0) {
          trend = '↑ Getting busier';
        } else if (diff < -1.0) {
          trend = '↓ Clearing out';
        } else {
          trend = '→ Steady';
        }

        final latest = posts.first;
        final currentCrowd = (latest['crowdingLevel'] as num?)?.toInt() ?? 0;

        // Haversine distance from user
        double? distM;
        if (_userLat != null && _userLng != null) {
          final lat = (latest['latitude'] as num?)?.toDouble();
          final lng = (latest['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null && !(lat == 0 && lng == 0)) {
            distM = _haversineM(_userLat!, _userLng!, lat, lng);
          }
        }

        venues.add(_VenueTrend(
          name: entry.key,
          peepCount: posts.length,
          avgCrowd: avgCrowd,
          currentCrowdLevel: currentCrowd,
          distanceM: distM,
          trend: trend,
          imageUrl: latest['imageUrl'] as String?,
          venueType: latest['venueType'] as String?,
          rawPost: latest,
        ));
      }

      // Sort by peep count descending (most-peepled first)
      venues.sort((a, b) => b.peepCount.compareTo(a.peepCount));

      if (mounted) {
        setState(() {
          _venues = venues;
          _displayItems = _buildDisplayList(venues);
          _loading = false;
          _lastRefreshed = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load trending — tap to retry';
        });
      }
      debugPrint('TrendingScreen load: $e');
    }
  }

  // ── Ad injection ──────────────────────────────────────────────────────────────
  List<Object> _buildDisplayList(List<_VenueTrend> venues) {
    _cadence.resetForMerge(postCount: venues.length);
    final items = <Object>[];
    var adIndex = 0;

    for (final venue in venues) {
      if (_ads.isNotEmpty) {
        bool adAdded = false;
        for (var i = 0; i < _ads.length; i++) {
          final candidate = _ads[(adIndex + i) % _ads.length];
          if (_cadence.shouldShowAd(
              candidateAdId: candidate['id'] as String?)) {
            items.add(Map<String, dynamic>.from(candidate));
            adIndex += i + 1;
            adAdded = true;
            break;
          }
          if (!_cadence.isSlotPending) break;
        }
        if (!adAdded && _cadence.isSlotPending) _cadence.skipSlot();
      }
      items.add(venue);
    }
    return items;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  static double _haversineM(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dl = (lat2 - lat1) * math.pi / 180;
    final dn = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dl / 2) * math.sin(dl / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dn / 2) * math.sin(dn / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static String _formatDist(double m) {
    final mi = m * 0.000621371;
    if (mi < 0.1) return '${(m * 3.28084).round()} ft';
    if (mi < 10) return '${mi.toStringAsFixed(1)} mi';
    return '${mi.round()} mi';
  }

  static LinearGradient _crowdGradient(int level) {
    if (level <= 3) {
      return const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]);
    } else if (level <= 6) {
      return const LinearGradient(
          colors: [Color(0xFFBF360C), Color(0xFFE64A19)]);
    } else {
      return const LinearGradient(
          colors: [Color(0xFF7B1619), Color(0xFFB71C1C)]);
    }
  }

  String _refreshLabel() {
    if (_lastRefreshed == null) return '';
    final diff = DateTime.now().difference(_lastRefreshed!);
    if (diff.inSeconds < 60) return 'Just updated';
    if (diff.inMinutes < 5) return 'Updated ${diff.inMinutes}m ago';
    return 'Updates every 5 min';
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: Column(
        children: [
          _buildHeader(topPad),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(double topPad) {
    return Column(
      children: [
        // peepl logo bar
        Container(
          color: PeeplAppTokens.background,
          padding: EdgeInsets.fromLTRB(0, topPad + 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: PeeplAppTokens.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              const Text(
                'peepl',
                style: TextStyle(
                  color: PeeplAppTokens.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const Spacer(),
              if (_lastRefreshed != null)
                Text(
                  _refreshLabel(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        // Trending Now strip
        Container(
          width: double.infinity,
          color: const Color(0xFF1535C8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              const Text(
                '🔥 Trending Now',
                style: TextStyle(
                  color: PeeplAppTokens.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· last 6 hours',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: PeeplAppTokens.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadTrending(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_venues.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _loadTrending(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: _displayItems.length,
        itemBuilder: (context, index) {
          final item = _displayItems[index];
          if (item is Map<String, dynamic>) return _buildAdCard(item);
          return _buildVenueCard(item as _VenueTrend);
        },
      ),
    );
  }

  // ── Venue card ────────────────────────────────────────────────────────────────
  Widget _buildVenueCard(_VenueTrend venue) {
    final distText = venue.distanceM != null
        ? ' · ${_formatDist(venue.distanceM!)}'
        : '';
    final subText = '${venue.peepCount} peep${venue.peepCount == 1 ? '' : 's'} today$distText';

    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/venue', arguments: venue.rawPost),
      child: Container(
        height: 80,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration:
            BoxDecoration(borderRadius: BorderRadius.circular(14)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background — image with crowd-level gradient fallback
              if ((venue.imageUrl ?? '').isNotEmpty)
                Image.network(
                  venue.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: _crowdGradient(venue.currentCrowdLevel)),
                  ),
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: _crowdGradient(venue.currentCrowdLevel)),
                ),
              // Dark overlay for text legibility
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xBB000000), Color(0x55000000)],
                  ),
                ),
              ),

              // Top-left: trend label
              Positioned(
                top: 8,
                left: 10,
                child: Text(
                  venue.trend,
                  style: const TextStyle(
                    color: Color(0xFF00BBDD),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(blurRadius: 4, color: PeeplAppTokens.textPrimary),
                    ],
                  ),
                ),
              ),

              // Top-right: DotRing badge
              Positioned(
                top: 4,
                right: 8,
                child: CrowdDotRingMeter(
                    level: venue.currentCrowdLevel, size: 38),
              ),

              // Bottom-left: venue name + peep/distance meta
              Positioned(
                left: 10,
                bottom: 7,
                right: 58,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      venue.name,
                      style: const TextStyle(
                        color: PeeplAppTokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 4,
                              color: PeeplAppTokens.textPrimary),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subText,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 10,
                        shadows: const [
                          Shadow(blurRadius: 3, color: PeeplAppTokens.textMuted),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Rank badge (position 1-3 show gold/silver/bronze dot)
              _buildRankBadge(venue),
            ],
          ),
        ),
      ),
    );
  }

  /// Small rank indicator for top 3 trending venues.
  Widget _buildRankBadge(_VenueTrend venue) {
    final rank = _venues.indexOf(venue) + 1;
    if (rank > 3) return const SizedBox.shrink();
    final color = switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      _ => const Color(0xFFCD7F32),
    };
    final emoji = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      _ => '🥉',
    };
    return Positioned(
      bottom: 7,
      right: 8,
      child: Text(
        emoji,
        style: TextStyle(fontSize: 16, color: color),
      ),
    );
  }

  // ── Ad card ───────────────────────────────────────────────────────────────────
  Widget _buildAdCard(Map<String, dynamic> ad) {
    final adId = ad['id'] as String? ?? '';
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AdCard(
        ad: ad,
        onImpression: () => _adsService.recordAdImpression(adId, uid),
        onTap: () => _adsService.recordAdClick(adId, uid),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 14),
            const Text(
              'Nothing trending yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to Peep a spot and start the trend!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: PeeplAppTokens.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/post'),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Post a Peep'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PeeplAppTokens.background,
                foregroundColor: PeeplAppTokens.textPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
