import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/local_deals.dart';
import '../services/location_service.dart';
import '../services/native_ads_service.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  final _adsService = NativeAdsService();
  List<Map<String, dynamic>> _deals = [];
  bool _loading = true;
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _loadDeals();
  }

  Future<void> _loadDeals() async {
    setState(() {
      _loading = true;
    });

    final pos = await LocationService.getCurrentLocation();
    _userLat = pos?.latitude;
    _userLng = pos?.longitude;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('native_ads')
          .where('isActive', isEqualTo: true)
          .where('endDate', isGreaterThan: Timestamp.now())
          .orderBy('endDate')
          .orderBy('priority', descending: true)
          .get();

      var deals = snap.docs
          .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
          .toList();

      deals.sort((a, b) {
        final dA = _distanceMeters(a);
        final dB = _distanceMeters(b);
        if (dA == null && dB == null) return 0;
        if (dA == null) return 1;
        if (dB == null) return -1;
        return dA.compareTo(dB);
      });

      if (mounted) {
        setState(() {
          _deals = deals;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deals = LocalDeals.fallback
              .map((d) => Map<String, dynamic>.from(d))
              .toList();
          _loading = false;
        });
      }
    }
  }

  double? _distanceMeters(Map<String, dynamic> ad) {
    if (_userLat == null || _userLng == null) return null;
    final lat = (ad['venueLat'] as num?)?.toDouble() ??
        (ad['latitude'] as num?)?.toDouble();
    final lng = (ad['venueLng'] as num?)?.toDouble() ??
        (ad['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return _haversine(_userLat!, _userLng!, lat, lng);
  }

  String _distanceLabel(Map<String, dynamic> ad) {
    final cached = ad['distance'] as String?;
    if (cached != null && cached.trim().isNotEmpty) return cached.trim();
    final meters = _distanceMeters(ad);
    if (meters == null) return '';
    final miles = meters / 1609.344;
    if (miles < 0.1) return 'nearby';
    return '${miles.toStringAsFixed(1)} mi';
  }

  static double _haversine(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(p1) *
            math.cos(p2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static String _advertiserName(Map<String, dynamic> ad) =>
      LocalDeals.advertiser(ad);

  static String _discountText(Map<String, dynamic> ad) {
    final discount = LocalDeals.discount(ad);
    if (discount.isNotEmpty) return discount;
    return (ad['dealHeadline'] as String?) ??
        (ad['headline'] as String?) ??
        '';
  }

  static String _tagline(Map<String, dynamic> ad) {
    for (final key in ['tagline', 'subline', 'bodyText', 'body']) {
      final v = ad[key] as String?;
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  static String? _imageUrl(Map<String, dynamic> ad) {
    for (final key in ['imageUrl', 'logoUrl', 'merchantLogo']) {
      final v = ad[key] as String?;
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static Color _accentColor(Map<String, dynamic> ad) =>
      Color((ad['accentColor'] as int?) ?? 0xFF1565C0);

  static String _ctaLabel(Map<String, dynamic> ad) {
    final cta = (ad['cta'] ?? ad['ctaText']) as String?;
    if (cta != null && cta.trim().isNotEmpty) return cta.trim();
    return 'Get Offer';
  }

  void _onCtaTap(Map<String, dynamic> ad) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final adId = (ad['id'] ?? '').toString();
    if (adId.isNotEmpty) {
      _adsService.recordAdClick(adId, uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deals Near You'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _deals.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadDeals,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _deals.length,
                    itemBuilder: (context, index) {
                      final ad = _deals[index];
                      return _DealCard(
                        ad: ad,
                        advertiser: _advertiserName(ad),
                        discount: _discountText(ad),
                        tagline: _tagline(ad),
                        distance: _distanceLabel(ad),
                        imageUrl: _imageUrl(ad),
                        accentColor: _accentColor(ad),
                        ctaLabel: _ctaLabel(ad),
                        onCta: () => _onCtaTap(ad),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
        const Icon(Icons.local_offer_outlined, size: 64, color: Colors.black38),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'No deals available right now',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      ],
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({
    required this.ad,
    required this.advertiser,
    required this.discount,
    required this.tagline,
    required this.distance,
    required this.imageUrl,
    required this.accentColor,
    required this.ctaLabel,
    required this.onCta,
  });

  final Map<String, dynamic> ad;
  final String advertiser;
  final String discount;
  final String tagline;
  final String distance;
  final String? imageUrl;
  final Color accentColor;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      height: 160,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _gradientBackground(),
            )
          else
            _gradientBackground(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.72),
                  Colors.black.withValues(alpha: 0.25),
                ],
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'SPONSORED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 36, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  advertiser,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (discount.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    discount,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFF9C4),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (tagline.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (distance.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    distance,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: onCta,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        ctaLabel,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientBackground() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor,
            Color.lerp(accentColor, Colors.black, 0.35)!,
          ],
        ),
      ),
    );
  }
}
