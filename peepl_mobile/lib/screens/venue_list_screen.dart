import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../widgets/crowd_meter.dart';

class VenueListScreen extends StatefulWidget {
  const VenueListScreen({super.key});

  @override
  State<VenueListScreen> createState() => _VenueListScreenState();
}

class _VenueListScreenState extends State<VenueListScreen> {
  static const _kNearRadiusM = 10000.0;

  static const List<String> _categories = [
    'All',
    'Restaurant',
    'Bar',
    'Café',
    'Park',
    'Beach',
    'Mall',
    'Museum',
    'Concert/Event',
    'Sports Event',
    'Airport',
    'Gym',
    'Grocery Store',
    'Hotel',
    'Hospital',
    'Club',
    'Other',
  ];

  static const Map<String, List<String>> _categoryTypes = {
    'Restaurant': ['Restaurant'],
    'Bar': ['Bar', 'Brewery'],
    'Café': ['Cafe', 'Café'],
    'Park': ['Park'],
    'Beach': ['Beach'],
    'Mall': ['Mall'],
    'Museum': ['Museum'],
    'Concert/Event': ['Concert Venue', 'Event Space', 'Event'],
    'Sports Event': ['Stadium'],
    'Airport': ['Airport'],
    'Gym': ['Gym'],
    'Grocery Store': ['Grocery Store'],
    'Hotel': ['Hotel'],
    'Hospital': ['Hospital', 'Clinic', 'Urgent Care'],
    'Club': ['Club', 'Nightclub'],
    'Other': ['Other'],
  };

  static final Set<String> _knownTypes = {
    for (final types in _categoryTypes.values) ...types,
  };

  final TextEditingController _searchCtrl = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<_VenueRow> _venues = [];
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _nearMeEnabled = false;
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVenues() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos != null) {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      }

      final snap = await _db
          .collection('location_posts')
          .orderBy('timestamp', descending: true)
          .limit(2000)
          .get();

      final venues = _aggregateVenues(snap.docs);

      if (mounted) {
        setState(() {
          _venues = venues;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('VenueListScreen load: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<_VenueRow> _aggregateVenues(List<QueryDocumentSnapshot> docs) {
    final byName = <String, _VenueRow>{};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['locationName'] as String? ?? '';
      if (name.isEmpty) continue;

      final existing = byName[name];
      if (existing == null) {
        byName[name] = _VenueRow.fromPost(name, data, 1);
      } else {
        byName[name] = existing.copyWith(postCount: existing.postCount + 1);
      }
    }

    final list = byName.values.toList()
      ..sort((a, b) => b.lastPosted.compareTo(a.lastPosted));
    return list;
  }

  List<_VenueRow> get _filteredVenues {
    var list = List<_VenueRow>.from(_venues);

    if (_selectedCategory != 'All') {
      list = list.where((v) => _matchesCategory(v.venueType, _selectedCategory)).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((v) => v.locationName.toLowerCase().contains(q))
          .toList();
    }

    if (_nearMeEnabled) {
      list = list.where((v) {
        final dist = _distanceMeters(v.latitude, v.longitude);
        return dist != null && dist <= _kNearRadiusM;
      }).toList();
    }

    list.sort((a, b) => b.lastPosted.compareTo(a.lastPosted));
    return list;
  }

  bool _matchesCategory(String? venueType, String category) {
    if (category == 'All') return true;
    final type = venueType?.trim() ?? '';
    if (category == 'Other') {
      return type.isEmpty || type == 'Other' || !_knownTypes.contains(type);
    }
    final allowed = _categoryTypes[category] ?? [];
    return allowed.contains(type);
  }

  double? _distanceMeters(double? lat, double? lng) {
    if (_userLat == null || _userLng == null) return null;
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return _haversineMeters(_userLat!, _userLng!, lat, lng);
  }

  static double _haversineMeters(
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
        math.cos(p1) * math.cos(p2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  void _onNearMeChanged(bool value) {
    if (value && (_userLat == null || _userLng == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location unavailable — enable location to use Near Me'),
        ),
      );
      return;
    }
    setState(() => _nearMeEnabled = value);
  }

  void _openVenue(String locationName) {
    Navigator.pushNamed(
      context,
      '/venue',
      arguments: {'locationName': locationName},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchAndToggle(),
            _buildCategoryChips(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              'Browse Venues',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: 'Search venues...',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.white.withValues(alpha: 0.8),
                size: 18,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 18,
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(21),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(21),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(21),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Switch(
                value: _nearMeEnabled,
                onChanged: _onNearMeChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF2244EE),
                inactiveThumbColor: Colors.white70,
                inactiveTrackColor: Colors.white24,
              ),
              const Text(
                'Near Me',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(within 10 km)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = _selectedCategory == category;
          return FilterChip(
            label: Text(category),
            selected: selected,
            onSelected: (_) => setState(() => _selectedCategory = category),
            labelStyle: TextStyle(
              color: selected ? const Color(0xFF1565C0) : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            checkmarkColor: const Color(0xFF1565C0),
            side: BorderSide(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load venues',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadVenues,
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final venues = _filteredVenues;
    if (venues.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_off_outlined,
                size: 56,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'No venues found',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: venues.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _buildVenueCard(venues[index]),
      ),
    );
  }

  Widget _buildVenueCard(_VenueRow venue) {
    final typeLabel = venue.venueType?.trim().isNotEmpty == true
        ? venue.venueType!.trim()
        : 'Other';

    return InkWell(
      onTap: () => _openVenue(venue.locationName),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.locationName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      typeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${venue.postCount} ${venue.postCount == 1 ? 'post' : 'posts'} · ${_formatLastPosted(venue.lastPosted)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CrowdMeter(level: venue.currentCrowd, size: 52),
          ],
        ),
      ),
    );
  }

  static String _formatLastPosted(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${when.month}/${when.day}/${when.year}';
  }
}

class _VenueRow {
  final String locationName;
  final String? venueType;
  final int currentCrowd;
  final int postCount;
  final DateTime lastPosted;
  final double? latitude;
  final double? longitude;

  const _VenueRow({
    required this.locationName,
    required this.venueType,
    required this.currentCrowd,
    required this.postCount,
    required this.lastPosted,
    required this.latitude,
    required this.longitude,
  });

  factory _VenueRow.fromPost(
    String name,
    Map<String, dynamic> data,
    int count,
  ) {
    DateTime lastPosted = DateTime.fromMillisecondsSinceEpoch(0);
    final ts = data['timestamp'];
    if (ts is Timestamp) {
      lastPosted = ts.toDate();
    } else if (ts is DateTime) {
      lastPosted = ts;
    }

    return _VenueRow(
      locationName: name,
      venueType: data['venueType'] as String?,
      currentCrowd: (data['crowdingLevel'] as num?)?.toInt() ?? 0,
      postCount: count,
      lastPosted: lastPosted,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  _VenueRow copyWith({int? postCount}) {
    return _VenueRow(
      locationName: locationName,
      venueType: venueType,
      currentCrowd: currentCrowd,
      postCount: postCount ?? this.postCount,
      lastPosted: lastPosted,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
