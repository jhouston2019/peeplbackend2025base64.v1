import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/location_service.dart';

const _kCategories = <String>[
  'All',
  'Food & Drink',
  'Retail',
  'Entertainment',
  'Services',
];

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  final _db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _deals = [];
  bool _loading = true;
  String? _error;
  double? _userLat;
  double? _userLng;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    _loadDeals();
  }

  @override
  void dispose() {
    _ticker.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDeals() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final pos = await LocationService.getCurrentLocation();
    _userLat = pos?.latitude;
    _userLng = pos?.longitude;

    try {
      final snap = await _db
          .collection('native_ads')
          .where('isActive', isEqualTo: true)
          .where('hasDeal', isEqualTo: true)
          .where('dealExpiry', isGreaterThan: Timestamp.now())
          .orderBy('dealExpiry')
          .get();

      var deals = snap.docs
          .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
          .toList();

      deals.sort((a, b) {
        final dA = _distanceKm(a);
        final dB = _distanceKm(b);
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
          _loading = false;
          _error = 'Could not load deals. Tap to retry.';
        });
      }
    }
  }

  List<Map<String, dynamic>> get _visibleDeals {
    return _deals.where((ad) {
      if (!_matchesCategory(ad, _selectedCategory)) return false;
      if (_searchQuery.isEmpty) return true;
      final name = _businessName(ad).toLowerCase();
      final category = _dealCategory(ad).toLowerCase();
      return name.contains(_searchQuery) || category.contains(_searchQuery);
    }).toList();
  }

  static String _businessName(Map<String, dynamic> ad) =>
      (ad['businessName'] as String?)?.trim().isNotEmpty == true
          ? ad['businessName'] as String
          : (ad['headline'] as String?) ??
              (ad['venueName'] as String?) ??
              'Business';

  static String _dealHeadline(Map<String, dynamic> ad) =>
      (ad['dealHeadline'] as String?)?.trim().isNotEmpty == true
          ? ad['dealHeadline'] as String
          : (ad['subline'] as String?) ?? (ad['headline'] as String?) ?? '';

  static String _dealDescription(Map<String, dynamic> ad) =>
      (ad['dealDescription'] as String?)?.trim().isNotEmpty == true
          ? ad['dealDescription'] as String
          : (ad['subline'] as String?) ?? '';

  static String? _merchantLogo(Map<String, dynamic> ad) {
    for (final key in ['merchantLogo', 'logoUrl', 'imageUrl']) {
      final v = ad[key] as String?;
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static String _dealCategory(Map<String, dynamic> ad) =>
      (ad['category'] as String?) ??
      (ad['dealCategory'] as String?) ??
      '';

  static dynamic _dealExpiry(Map<String, dynamic> ad) =>
      ad['dealExpiry'] ?? ad['endDate'];

  static bool _matchesCategory(Map<String, dynamic> ad, String chip) {
    if (chip == 'All') return true;
    final raw = _dealCategory(ad).toLowerCase();
    if (raw.isEmpty) return chip == 'All';
    return switch (chip) {
      'Food & Drink' =>
        raw.contains('food') ||
            raw.contains('drink') ||
            raw.contains('restaurant') ||
            raw.contains('bar') ||
            raw.contains('cafe') ||
            raw.contains('brewery'),
      'Retail' =>
        raw.contains('retail') ||
            raw.contains('shop') ||
            raw.contains('store') ||
            raw.contains('mall') ||
            raw.contains('grocery'),
      'Entertainment' =>
        raw.contains('entertainment') ||
            raw.contains('event') ||
            raw.contains('concert') ||
            raw.contains('movie') ||
            raw.contains('theater') ||
            raw.contains('park'),
      'Services' =>
        raw.contains('service') ||
            raw.contains('spa') ||
            raw.contains('gym') ||
            raw.contains('bank') ||
            raw.contains('salon') ||
            raw.contains('clinic'),
      _ => raw.contains(chip.toLowerCase()),
    };
  }

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
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
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

  static String _formatExpiryDate(dynamic ts) {
    if (ts == null) return '';
    final dt = ts is Timestamp ? ts.toDate() : null;
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Expires ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  static String _countdown(dynamic ts) {
    if (ts == null) return '';
    final dt = ts is Timestamp ? ts.toDate() : null;
    if (dt == null) return '';
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 0) {
      return '${diff.inDays}d ${diff.inHours.remainder(24)}h left';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m left';
    }
    return '${diff.inMinutes}m ${diff.inSeconds.remainder(60)}s left';
  }

  static String? _formatPrice(dynamic value) {
    if (value == null) return null;
    if (value is num) return '\$${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}';
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return s.startsWith('\$') ? s : '\$$s';
  }

  Future<void> _confirmClaim(Map<String, dynamic> ad) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Claim this deal?'),
        content: Text(
          'Claim "${_dealHeadline(ad)}" at ${_businessName(ad)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
            child: const Text('Claim Deal'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.pushNamed(context, '/deal_claimed', arguments: ad);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(context),
            _buildSearchBar(),
            _buildCategoryChips(),
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
                        ? _buildError()
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by business or category...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.white.withValues(alpha: 0.8),
          ),
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

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
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
            selectedColor: const Color(0xFFFFD700),
            checkmarkColor: const Color(0xFF1A1A1A),
            labelStyle: TextStyle(
              color: selected ? const Color(0xFF1A1A1A) : Colors.white,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            side: BorderSide(
              color: selected
                  ? const Color(0xFFFFD700)
                  : Colors.white.withValues(alpha: 0.3),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStrip() {
    return Container(
      color: Colors.white.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      margin: const EdgeInsets.only(top: 4),
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

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadDeals, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final deals = _visibleDeals;
    if (deals.isEmpty) return _buildEmpty();

    return RefreshIndicator(
      onRefresh: _loadDeals,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: deals.length,
        itemBuilder: (ctx, i) {
          final ad = deals[i];
          return _DealCard(
            ad: ad,
            businessName: _businessName(ad),
            dealHeadline: _dealHeadline(ad),
            dealDescription: _dealDescription(ad),
            logoUrl: _merchantLogo(ad),
            originalPrice: _formatPrice(ad['originalPrice']),
            discountedPrice: _formatPrice(ad['discountedPrice']),
            expiryLabel: _formatExpiryDate(_dealExpiry(ad)),
            countdown: _countdown(_dealExpiry(ad)),
            distanceLabel: _distanceLabel(ad),
            onClaim: () => _confirmClaim(ad),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🏷️', style: TextStyle(fontSize: 56)),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'No deals near you right now — check back soon!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New local deals drop daily from Peepl merchants.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({
    required this.ad,
    required this.businessName,
    required this.dealHeadline,
    required this.dealDescription,
    required this.logoUrl,
    required this.originalPrice,
    required this.discountedPrice,
    required this.expiryLabel,
    required this.countdown,
    required this.distanceLabel,
    required this.onClaim,
  });

  final Map<String, dynamic> ad;
  final String businessName;
  final String dealHeadline;
  final String dealDescription;
  final String? logoUrl;
  final String? originalPrice;
  final String? discountedPrice;
  final String expiryLabel;
  final String countdown;
  final String distanceLabel;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LogoAvatar(logoUrl: logoUrl, name: businessName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1565C0),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dealHeadline.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          dealHeadline,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (dealDescription.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                dealDescription,
                style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (originalPrice != null || discountedPrice != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (originalPrice != null)
                    Text(
                      originalPrice!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  if (originalPrice != null && discountedPrice != null)
                    const SizedBox(width: 8),
                  if (discountedPrice != null)
                    Text(
                      discountedPrice!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (expiryLabel.isNotEmpty)
                  _InfoChip(icon: Icons.event, label: expiryLabel),
                if (countdown.isNotEmpty)
                  _InfoChip(icon: Icons.timer_outlined, label: countdown),
                if (distanceLabel.isNotEmpty)
                  _InfoChip(icon: Icons.near_me_outlined, label: distanceLabel),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClaim,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Claim Deal',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoAvatar extends StatelessWidget {
  const _LogoAvatar({required this.logoUrl, required this.name});

  final String? logoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 48,
        height: 48,
        color: const Color(0xFF1565C0).withValues(alpha: 0.1),
        child: logoUrl != null
            ? Image.network(
                logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}
