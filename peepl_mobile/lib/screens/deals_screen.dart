import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/location_service.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  final _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _deals = [];
  bool _loading = true;
  String? _error;
  double? _userLat;
  double? _userLng;
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    // Re-render every second so countdowns stay live.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _loadDeals();
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadDeals() async {
    setState(() { _loading = true; _error = null; });

    final pos = await LocationService.getCurrentLocation();
    _userLat = pos?.latitude;
    _userLng = pos?.longitude;

    try {
      // Range filter on endDate requires orderBy('endDate') first.
      final snap = await _db
          .collection('native_ads')
          .where('isActive', isEqualTo: true)
          .where('endDate', isGreaterThan: Timestamp.now())
          .orderBy('endDate')
          .get();

      var deals = snap.docs.map((doc) {
        return <String, dynamic>{'id': doc.id, ...doc.data()};
      }).toList();

      // Client-side: remove ads whose startDate is still in the future.
      final now = DateTime.now();
      deals = deals.where((ad) {
        final start = ad['startDate'] as Timestamp?;
        return start == null || start.toDate().isBefore(now);
      }).toList();

      // Client-side: priority desc, then distance asc.
      deals.sort((a, b) {
        final pA = (a['priority'] as num?)?.toInt() ?? 0;
        final pB = (b['priority'] as num?)?.toInt() ?? 0;
        if (pA != pB) return pB.compareTo(pA);
        final dA = _distanceKm(a);
        final dB = _distanceKm(b);
        if (dA == null && dB == null) return 0;
        if (dA == null) return 1;
        if (dB == null) return -1;
        return dA.compareTo(dB);
      });

      if (mounted) setState(() {
        _deals = deals;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load deals. Tap to retry.';
        });
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  double? _distanceKm(Map<String, dynamic> ad) {
    if (_userLat == null || _userLng == null) return null;
    final lat = (ad['venueLat'] as num?)?.toDouble();
    final lng = (ad['venueLng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return _haversine(_userLat!, _userLng!, lat, lng);
  }

  String _distanceLabel(Map<String, dynamic> ad) {
    final km = _distanceKm(ad);
    if (km == null) return '';
    if (km < 1) return '${(km * 1000).toInt()} m away';
    return '${km.toStringAsFixed(1)} km away';
  }

  static double _haversine(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static String _countdown(dynamic ts) {
    if (ts == null) return '';
    final dt = ts is Timestamp ? ts.toDate() : null;
    if (dt == null) return '';
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours.remainder(24)}h';
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    }
    if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ${diff.inSeconds.remainder(60)}s';
    }
    return '${diff.inSeconds}s';
  }

  static bool _isLive(Map<String, dynamic> ad) {
    final start = ad['startDate'];
    if (start == null) return true;
    final dt = start is Timestamp ? start.toDate() : null;
    return dt == null || !dt.isAfter(DateTime.now());
  }

  // Derive a two-stop gradient from the ad.  Uses bgColor when present,
  // otherwise picks from a deterministic palette based on the headline.
  static const List<List<Color>> _palettes = [
    [Color(0xFF0D47A1), Color(0xFF1976D2)],
    [Color(0xFF1B5E20), Color(0xFF388E3C)],
    [Color(0xFF4A148C), Color(0xFF7B1FA2)],
    [Color(0xFF004D40), Color(0xFF00796B)],
    [Color(0xFF7F0000), Color(0xFFC62828)],
    [Color(0xFF263238), Color(0xFF455A64)],
    [Color(0xFF1A237E), Color(0xFF303F9F)],
    [Color(0xFF3E2723), Color(0xFF6D4C41)],
  ];

  List<Color> _cardGradient(Map<String, dynamic> ad) {
    final bgV = ad['bgColor'];
    if (bgV != null) {
      Color c;
      if (bgV is int) {
        c = Color(bgV);
      } else if (bgV is String) {
        final hex = bgV.startsWith('0x') || bgV.startsWith('0X')
            ? bgV
            : '0x$bgV';
        c = Color(int.tryParse(hex) ?? 0xFF1565C0);
      } else {
        c = const Color(0xFF1565C0);
      }
      final darker = Color.fromARGB(
        c.alpha,
        (c.red * 0.55).clamp(0, 255).toInt(),
        (c.green * 0.55).clamp(0, 255).toInt(),
        (c.blue * 0.55).clamp(0, 255).toInt(),
      );
      return [darker, c];
    }
    final name = (ad['headline'] as String?) ?? '';
    final idx =
        name.isNotEmpty ? name.codeUnitAt(0) % _palettes.length : 0;
    return _palettes[idx];
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(context),
            _buildStrip(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('⚠️', style: TextStyle(fontSize: 40)),
                                  const SizedBox(height: 12),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadDeals,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _buildBody(context),
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
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            '💰  Deals',
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

  Widget _buildStrip() {
    return Container(
      color: Colors.white.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: const Text(
        '💰 Active Deals Near You',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_deals.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏷️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'No active deals near you right now',
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Check back soon — new deals drop daily.',
              style: TextStyle(fontSize: 13, color: Colors.black38),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/how_to_advertise'),
              child: const Text(
                'Advertise your venue →',
                style: TextStyle(color: Color(0xFF1565C0)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDeals,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 20),
        itemCount: _deals.length + 1,
        itemBuilder: (ctx, i) {
          if (i == _deals.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/how_to_advertise'),
                  child: const Text(
                    'Advertise your venue →',
                    style: TextStyle(color: Color(0xFF1565C0)),
                  ),
                ),
              ),
            );
          }
          final ad = _deals[i];
          return _DealCard(
            ad: ad,
            gradient: _cardGradient(ad),
            isLive: _isLive(ad),
            countdown: _countdown(ad['endDate']),
            distanceLabel: _distanceLabel(ad),
            onTap: () => Navigator.pushNamed(
              context,
              '/deal_claimed',
              arguments: ad,
            ),
          );
        },
      ),
    );
  }
}

// ── Deal card ─────────────────────────────────────────────────────────────────

class _DealCard extends StatelessWidget {
  const _DealCard({
    required this.ad,
    required this.gradient,
    required this.isLive,
    required this.countdown,
    required this.distanceLabel,
    required this.onTap,
  });

  final Map<String, dynamic> ad;
  final List<Color> gradient;
  final bool isLive;
  final String countdown;
  final String distanceLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final venueName = (ad['headline'] as String?) ?? 'Venue';
    final offerText = (ad['subline'] as String?) ?? '';

    final footerParts = <String>[];
    if (countdown.isNotEmpty) footerParts.add('⏱ Ends in $countdown');
    if (distanceLabel.isNotEmpty) footerParts.add(distanceLabel);
    final footer = footerParts.join('  ·  ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background gradient.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                ),
              ),

              // Dark scrim bottom-to-top for text legibility.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.62),
                      Colors.black.withValues(alpha: 0.12),
                    ],
                  ),
                ),
              ),

              // Content.
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LIVE / UPCOMING badge top-right.
                    Align(
                      alignment: Alignment.topRight,
                      child: _StatusBadge(isLive: isLive),
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Text column.
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                venueName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 4,
                                      color: Colors.black,
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (offerText.isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(
                                  offerText,
                                  style: const TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (footer.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  footer,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Claim pill.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Claim',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isLive});

  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isLive ? Colors.red : Colors.grey,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isLive ? 'LIVE' : 'UPCOMING',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
