import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ad_cadence_service.dart';
import '../services/native_ads_service.dart';
import '../widgets/ad_card.dart';
import '../widgets/crowd_dot_ring_meter.dart';
import '../widgets/no_peeps_empty_state.dart';
import 'location_detail_screen.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class VenueScreen extends StatefulWidget {
  /// Optionally supplied when pushed directly.
  /// Falls back to named-route arguments (a Map<String,dynamic>).
  final Map<String, dynamic>? venueData;

  const VenueScreen({super.key, this.venueData});

  @override
  State<VenueScreen> createState() => _VenueScreenState();
}

class _VenueScreenState extends State<VenueScreen> {
  // ── Services ────────────────────────────────────────────────────────────────
  final NativeAdsService _adsService = NativeAdsService();
  final AdCadenceService _cadence = AdCadenceService();

  // ── Scroll / keys ────────────────────────────────────────────────────────────
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _dealBannerKey = GlobalKey();

  // ── State ────────────────────────────────────────────────────────────────────
  Map<String, dynamic> _venue = {};
  bool _didInit = false;

  double? _averageCrowding;
  int? _crowdingReports;
  Map<String, dynamic>? _activeDeal;
  String? _pioneerUsername;
  List<Map<String, dynamic>> _availableAds = [];

  // ── Derived helpers ───────────────────────────────────────────────────────────
  String get _venueName =>
      _venue['locationName'] as String? ??
      _venue['venueName'] as String? ??
      _venue['name'] as String? ??
      '';

  String get _cityAddress =>
      _venue['city'] as String? ??
      _venue['address'] as String? ??
      _venue['subLocality'] as String? ??
      '';

  String? get _venueType => _venue['venueType'] as String?;

  // ── Lifecycle ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _venue = widget.venueData ?? {};
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      if (_venue.isEmpty) {
        _venue = (ModalRoute.of(context)?.settings.arguments
                as Map<String, dynamic>?) ??
            {};
      }
      if (_venueName.isNotEmpty) _loadAllData();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────────
  Future<void> _loadAllData() async {
    await Future.wait([
      _loadVenueStats(),
      _loadActiveDeal(),
      _loadPioneer(),
      _initAds(),
    ]);
  }

  Future<void> _loadVenueStats() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('locations')
          .where('locationName', isEqualTo: _venueName)
          .limit(1)
          .get();
      if (!mounted || snap.docs.isEmpty) return;
      final data = snap.docs.first.data();
      setState(() {
        _averageCrowding = (data['averageCrowding'] as num?)?.toDouble();
        _crowdingReports = (data['crowdingReports'] as num?)?.toInt();
      });
    } catch (e) {
      debugPrint('VenueScreen stats: $e');
    }
  }

  Future<void> _loadActiveDeal() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('native_ads')
          .where('targetLocations', arrayContains: _venueName)
          .where('isActive', isEqualTo: true)
          .where('endDate', isGreaterThan: Timestamp.now())
          .limit(1)
          .get();
      if (!mounted || snap.docs.isEmpty) return;
      setState(() => _activeDeal = {
            'id': snap.docs.first.id,
            ...snap.docs.first.data(),
          });
    } catch (e) {
      debugPrint('VenueScreen deal: $e');
    }
  }

  Future<void> _loadPioneer() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('pioneers')
          .where('locationName', isEqualTo: _venueName)
          .orderBy('timestamp', descending: false)
          .limit(1)
          .get();
      if (!mounted || snap.docs.isEmpty) return;

      final data = snap.docs.first.data();
      String name = data['username'] as String? ?? '';

      // Pioneer doc may only store userId — look up display name.
      if (name.isEmpty) {
        final uid = data['userId'] as String?;
        if (uid != null) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get();
            name = userDoc.data()?['username'] as String? ??
                userDoc.data()?['displayName'] as String? ??
                (uid.length >= 6 ? uid.substring(0, 6) : uid);
          } catch (_) {
            name = uid.length >= 6 ? uid.substring(0, 6) : uid;
          }
        }
      }

      if (mounted && name.isNotEmpty) setState(() => _pioneerUsername = name);
    } catch (e) {
      debugPrint('VenueScreen pioneer: $e');
    }
  }

  Future<void> _initAds() async {
    await _cadence.init(pattern: [3, 3, 3, 3]);
    try {
      // Use userLocation to target ads to this venue; context filters to
      // 'venue' placement slots only.
      final ads = await _adsService.getAdsForFeed(
        context: 'venue',
        userLocation: _venueName,
        limit: 10,
      );
      if (mounted) setState(() => _availableAds = ads);
    } catch (e) {
      debugPrint('VenueScreen ads: $e');
    }
  }

  // ── Ad merge (same pattern as FeedScreen / LocationDetailScreen) ──────────────
  List<Map<String, dynamic>> _mergeAds(List<QueryDocumentSnapshot> docs) {
    _cadence.reset();
    final items = <Map<String, dynamic>>[];
    var adIdx = 0;

    for (final doc in docs) {
      final post = {'id': doc.id, ...(doc.data() as Map<String, dynamic>)};

      if (_availableAds.isNotEmpty) {
        bool added = false;
        for (var i = 0; i < _availableAds.length; i++) {
          final c = _availableAds[(adIdx + i) % _availableAds.length];
          if (_cadence.shouldShowAd(candidateAdId: c['id'] as String?)) {
            items.add({'_isAd': true, ...c});
            adIdx += i + 1;
            added = true;
            break;
          }
          if (!_cadence.isSlotPending) break;
        }
        if (!added && _cadence.isSlotPending) _cadence.skipSlot();
      }

      items.add(post);
    }
    return items;
  }

  // ── Actions ───────────────────────────────────────────────────────────────────
  void _scrollToDeals() {
    if (_activeDeal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active deals at this venue')),
      );
      return;
    }
    final ctx = _dealBannerKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  void _openMap() {
    Navigator.pushNamed(context, '/map', arguments: {
      'latitude': (_venue['latitude'] as num?)?.toDouble(),
      'longitude': (_venue['longitude'] as num?)?.toDouble(),
      'locationName': _venueName,
    });
  }

  void _showMenuSheet() {
    final website = _venue['website'] as String?;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _venueName.isNotEmpty ? _venueName : 'Venue Info',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (website != null && website.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.open_in_browser,
                      color: Color(0xFF2244EE)),
                  title: const Text('Visit Website'),
                  subtitle: Text(
                    website,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final uri = Uri.tryParse(website);
                    if (uri != null) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No website available for this venue.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _shareVenue() {
    final level = _averageCrowding?.round() ?? 5;
    final status = CrowdDotRingMeter.statusWord(level);
    Share.share(
      'Check out $_venueName on Peepl — it\'s $status right now! '
      'Know Before You Go 👇\nhttps://peepl.app',
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      bottomNavigationBar: _buildBottomBar(),
      floatingActionButton: _buildFAB(),
      body: Column(
        children: [
          _buildHeader(topPad),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ── Header (non-scrollable, 90 px content area) ───────────────────────────────
  static LinearGradient _gradientForCategory(String? category) {
    final c = (category ?? '').toLowerCase();
    if (c.contains('bar') || c.contains('brew') || c.contains('night')) {
      return const LinearGradient(
        colors: [Color(0xFF1A0535), Color(0xFF3D1A6E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (c.contains('restaurant') ||
        c.contains('cafe') ||
        c.contains('food truck')) {
      return const LinearGradient(
        colors: [Color(0xFF7B1900), Color(0xFFBF360C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (c.contains('park') || c.contains('beach')) {
      return const LinearGradient(
        colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (c.contains('gym') || c.contains('spa')) {
      return const LinearGradient(
        colors: [Color(0xFF006064), Color(0xFF00838F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (c.contains('mall') ||
        c.contains('grocery') ||
        c.contains('retail')) {
      return const LinearGradient(
        colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (c.contains('hospital') ||
        c.contains('clinic') ||
        c.contains('urgent')) {
      return const LinearGradient(
        colors: [Color(0xFF1565C0), Color(0xFF0288D1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (c.contains('airport') ||
        c.contains('train') ||
        c.contains('bus terminal')) {
      return const LinearGradient(
        colors: [Color(0xFF37474F), Color(0xFF546E7A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    // Peepl blue default
    return const LinearGradient(
      colors: [Color(0xFF2244EE), Color(0xFF1565C0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Widget _buildHeader(double topPad) {
    return Container(
      height: 90 + topPad,
      padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 12),
      decoration: BoxDecoration(gradient: _gradientForCategory(_venueType)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Back
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.only(right: 12, bottom: 2),
              child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
            ),
          ),
          // Venue name + city
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _venueName.isEmpty ? 'Venue' : _venueName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 4,
                          color: Colors.black54),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_cityAddress.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _cityAddress,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Stat chips
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatChip(
                label: _averageCrowding != null
                    ? 'Avg now: ${_averageCrowding!.toStringAsFixed(1)}'
                    : 'Avg now: —',
              ),
              const SizedBox(height: 4),
              _StatChip(
                label: _crowdingReports != null
                    ? 'All-time: $_crowdingReports'
                    : 'All-time: —',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Scrollable body ───────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_venueName.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('location_posts')
          .where('locationName', isEqualTo: _venueName)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load peeps: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final items = _mergeAds(docs);

        // 2 fixed header slots (deal banner + pioneer badge) always present,
        // followed by either the empty-state widget or the post/ad list.
        const headerSlots = 2;
        final bodyCount = items.isEmpty ? 1 : items.length;

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: headerSlots + bodyCount,
          itemBuilder: (context, index) {
            if (index == 0) return _buildDealBanner();
            if (index == 1) return _buildPioneerBadge();

            if (items.isEmpty) {
              return NoPeepsEmptyState(locationName: _venueName);
            }

            final item = items[index - headerSlots];
            if (item['_isAd'] == true) {
              final adId = item['id'] as String? ?? '';
              final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
              return AdCard(
                ad: item,
                onImpression: () => _adsService.recordAdImpression(adId, uid),
                onTap: () => _adsService.recordAdClick(adId, uid),
              );
            }
            return _buildPostCard(item);
          },
        );
      },
    );
  }

  // ── Deal banner ───────────────────────────────────────────────────────────────
  Widget _buildDealBanner() {
    if (_activeDeal == null) return const SizedBox.shrink();
    final text = _activeDeal!['dealText'] as String? ??
        _activeDeal!['headline'] as String? ??
        'Active deal — tap for details';

    return Container(
      key: _dealBannerKey,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.red, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.red,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // ── Pioneer badge ─────────────────────────────────────────────────────────────
  Widget _buildPioneerBadge() {
    if (_pioneerUsername == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2244EE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '🏅 Pioneered by $_pioneerUsername',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Post card (mirrors FeedScreen style) ──────────────────────────────────────
  Widget _buildPostCard(Map<String, dynamic> post) {
    final imageUrl = post['imageUrl'] as String? ?? '';
    if (imageUrl.isEmpty) return const SizedBox.shrink();

    final crowdLevel = (post['crowdingLevel'] as num?)?.toInt() ?? 0;
    final w = MediaQuery.sizeOf(context).width;
    final cardH = w * 0.22;

    return GestureDetector(
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => LocationDetailScreen(postData: post),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: cardH,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.grey[300]),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['username'] as String? ?? 'Anonymous',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 4,
                                  color: Colors.black87),
                            ],
                          ),
                        ),
                        Text(
                          _relativeTime(post['timestamp']),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 9,
                          ),
                        ),
                        const Spacer(),
                        if ((post['description'] as String?)?.isNotEmpty ==
                            true)
                          Text(
                            post['description'] as String,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  CrowdDotRingMeter(level: crowdLevel, size: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _relativeTime(dynamic ts) {
    if (ts is! Timestamp) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      height: 56 + MediaQuery.of(context).padding.bottom,
      color: const Color(0xFF2244EE),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          _BarAction(
            label: 'DEALS',
            color: const Color(0xFFFFD700),
            icon: Icons.local_offer_outlined,
            onTap: _scrollToDeals,
          ),
          _BarAction(
            label: 'Map',
            color: Colors.white,
            icon: Icons.map_outlined,
            onTap: _openMap,
          ),
          _BarAction(
            label: 'Menu',
            color: Colors.white,
            icon: Icons.menu_book_outlined,
            onTap: _showMenuSheet,
          ),
          _BarAction(
            label: 'SHARE',
            color: const Color(0xFFFFD700),
            icon: Icons.share_outlined,
            onTap: _shareVenue,
          ),
        ],
      ),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.pushNamed(
        context,
        '/post',
        arguments: {'locationName': _venueName},
      ),
      backgroundColor: const Color(0xFF2244EE),
      foregroundColor: Colors.white,
      label: const Text(
        'Peep Here',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      icon: const Icon(Icons.camera_alt_outlined),
    );
  }
}

// ─── Private helper widgets ───────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  const _StatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _BarAction({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
