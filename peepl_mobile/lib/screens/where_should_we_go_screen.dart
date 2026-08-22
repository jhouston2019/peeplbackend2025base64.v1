import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/crowdsource_service.dart';
import '../services/feed_service.dart';
import '../services/growth_analytics_service.dart';
import '../services/share_service.dart';
import '../theme/peepl_app_tokens.dart';
import '../widgets/crowd_meter.dart';

class WhereShouldWeGoScreen extends StatefulWidget {
  const WhereShouldWeGoScreen({
    super.key,
    this.groupId,
    this.presetVenueNames,
  });

  final String? groupId;
  final List<String>? presetVenueNames;

  @override
  State<WhereShouldWeGoScreen> createState() => _WhereShouldWeGoScreenState();
}

class _WhereShouldWeGoScreenState extends State<WhereShouldWeGoScreen> {
  static const _maxVenues = 4;
  static const _minVenues = 2;
  static const _staleHours = 2;

  final _feedService = FeedService();
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();

  List<VenueSummary> _allVenues = [];
  final Set<String> _selectedNames = {};
  List<Map<String, dynamic>> _comparisonVenues = [];
  String _searchQuery = '';
  bool _loadingVenues = true;
  bool _loadingComparison = false;
  bool _sharing = false;
  bool _requestingPeeps = false;
  String? _loadError;
  bool _expired = false;
  bool _showComparison = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    if (widget.groupId != null && widget.groupId!.isNotEmpty) {
      _loadSharedComparison(widget.groupId!);
    } else {
      _initSelection();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initSelection() async {
    final presets = widget.presetVenueNames ?? const [];
    if (presets.isNotEmpty) {
      _selectedNames.addAll(presets.take(_maxVenues));
    }
    await _loadVenueList();
  }

  Future<void> _loadVenueList() async {
    setState(() {
      _loadingVenues = true;
      _loadError = null;
    });
    try {
      final venues = await _feedService.fetchVenueSummaries();
      if (!mounted) return;
      setState(() {
        _allVenues = venues;
        _loadingVenues = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingVenues = false;
        _loadError = 'Could not load venues. Pull to retry.';
      });
    }
  }

  Future<void> _loadSharedComparison(String groupId) async {
    setState(() {
      _loadingComparison = true;
      _loadError = null;
      _expired = false;
      _showComparison = false;
    });

    try {
      final doc = await _db.collection('venue_comparisons').doc(groupId).get();
      if (!mounted) return;

      if (!doc.exists) {
        setState(() {
          _loadingComparison = false;
          _expired = true;
        });
        return;
      }

      final data = doc.data()!;
      final expiresAt = data['expiresAt'];
      if (expiresAt is Timestamp && expiresAt.toDate().isBefore(DateTime.now())) {
        setState(() {
          _loadingComparison = false;
          _expired = true;
        });
        return;
      }

      final venuesRaw = data['venues'];
      final venues = <Map<String, dynamic>>[];
      if (venuesRaw is List) {
        for (final item in venuesRaw) {
          if (item is Map) {
            final v = Map<String, dynamic>.from(item);
            if (v['hasRecentData'] == null) {
              v['hasRecentData'] = v['crowdingLevel'] != null;
            }
            final lastPeeped = v['lastPeeped'];
            if (v['lastPeepedMinutes'] == null && lastPeeped is String) {
              try {
                final dt = DateTime.parse(lastPeeped);
                v['lastPeepedMinutes'] =
                    DateTime.now().difference(dt).inMinutes;
              } catch (_) {}
            }
            venues.add(v);
          }
        }
      }

      await GrowthAnalyticsService.logEvent(
        'growth_venue_group_opened',
        {
          'groupId': groupId,
          'userId': _uid,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      setState(() {
        _comparisonVenues = venues;
        _showComparison = true;
        _loadingComparison = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingComparison = false;
        _expired = true;
      });
    }
  }

  List<VenueSummary> get _filteredVenues {
    if (_searchQuery.isEmpty) return _allVenues;
    final q = _searchQuery.toLowerCase();
    return _allVenues
        .where((v) => v.locationName.toLowerCase().contains(q))
        .toList();
  }

  void _toggleVenue(String locationName) {
    setState(() {
      if (_selectedNames.contains(locationName)) {
        _selectedNames.remove(locationName);
      } else if (_selectedNames.length < _maxVenues) {
        _selectedNames.add(locationName);
      }
    });
  }

  Future<void> _goToComparison() async {
    if (_selectedNames.length < _minVenues) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 2 venues to compare.')),
      );
      return;
    }

    setState(() {
      _loadingComparison = true;
      _loadError = null;
    });

    try {
      final comparison = await Future.wait(
        _selectedNames.map(_loadVenueComparison),
      );
      if (!mounted) return;
      setState(() {
        _comparisonVenues = comparison;
        _showComparison = true;
        _loadingComparison = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingComparison = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load comparison data.')),
      );
    }
  }

  Future<Map<String, dynamic>> _loadVenueComparison(String locationName) async {
    try {
      final snap = await _db
          .collection('location_posts')
          .where('locationName', isEqualTo: locationName)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        return _noDataVenue(locationName);
      }

      final doc = snap.docs.first;
      final data = doc.data();
      final ts = data['timestamp'];
      DateTime? postedAt;
      if (ts is Timestamp) postedAt = ts.toDate();
      if (postedAt == null) return _noDataVenue(locationName);

      final age = DateTime.now().difference(postedAt);
      if (age.inHours >= _staleHours) {
        return _noDataVenue(locationName, latitude: data['latitude'], longitude: data['longitude']);
      }

      final level = (data['crowdingLevel'] as num?)?.toInt() ?? 0;
      return {
        'locationName': locationName,
        'hasRecentData': true,
        'crowdingLevel': level,
        'crowdLabel': ShareService.crowdWordLabel(level),
        'lastPeeped': postedAt.toIso8601String(),
        'lastPeepedMinutes': age.inMinutes,
        'peepId': doc.id,
        'imageUrl': data['imageUrl'],
        'latitude': (data['latitude'] as num?)?.toDouble(),
        'longitude': (data['longitude'] as num?)?.toDouble(),
      };
    } catch (e) {
      debugPrint('[WhereShouldWeGoScreen] _loadVenueComparison error: $e');
      return _noDataVenue(locationName);
    }
  }

  Map<String, dynamic> _noDataVenue(
    String locationName, {
    dynamic latitude,
    dynamic longitude,
  }) {
    return {
      'locationName': locationName,
      'hasRecentData': false,
      'crowdingLevel': null,
      'crowdLabel': 'No recent data',
      'lastPeeped': null,
      'lastPeepedMinutes': null,
      'peepId': null,
      'imageUrl': null,
      'latitude': latitude is num ? latitude.toDouble() : null,
      'longitude': longitude is num ? longitude.toDouble() : null,
    };
  }

  Future<void> _shareComparison() async {
    if (_uid.isEmpty || _comparisonVenues.length < _minVenues) return;

    setState(() => _sharing = true);
    try {
      await ShareService.instance.shareVenueGroup(
        venues: _comparisonVenues,
        sharingUserId: _uid,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't generate share link. Try again."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _requestPeepsForStaleVenues() async {
    if (_uid.isEmpty) return;

    final stale = _comparisonVenues.where((v) => v['hasRecentData'] != true);
    if (stale.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All venues have recent data.')),
      );
      return;
    }

    setState(() => _requestingPeeps = true);
    var requested = 0;

    for (final venue in stale) {
      final name = venue['locationName'] as String? ?? '';
      final lat = (venue['latitude'] as num?)?.toDouble();
      final lng = (venue['longitude'] as num?)?.toDouble();
      if (name.isEmpty || lat == null || lng == null) continue;

      try {
        await CrowdsourceService.instance.createRequest(
          requestedBy: _uid,
          locationName: name,
          latitude: lat,
          longitude: lng,
          source: 'where_should_we_go',
        );
        requested++;
        await GrowthAnalyticsService.logEvent(
          'growth_request_peep_from_group',
          {
            'groupId': widget.groupId,
            'locationName': name,
            'userId': _uid,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      } catch (e) {
        debugPrint('[WhereShouldWeGo] request peep failed for $name: $e');
      }
    }

    if (!mounted) return;
    setState(() => _requestingPeeps = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          requested > 0
              ? 'Requested Peeps for $requested venue${requested == 1 ? '' : 's'}.'
              : 'Could not send requests. Location data may be missing.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplAppTokens.shellNavy,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: PeeplAppTokens.shellBodyDecoration(),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: PeeplAppTokens.textPrimary),
          ),
          Expanded(
            child: Text(
              _showComparison ? 'Compare Venues' : 'Where Should We Go?',
              style: const TextStyle(
                color: PeeplAppTokens.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_showComparison && widget.groupId == null)
            TextButton(
              onPressed: () => setState(() => _showComparison = false),
              child: const Text(
                'Edit',
                style: TextStyle(color: PeeplAppTokens.textPrimary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_expired) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'This comparison has expired',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: PeeplAppTokens.textMuted,
            ),
          ),
        ),
      );
    }

    if (_loadingComparison || (_loadingVenues && !_showComparison)) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_showComparison) {
      return _buildComparisonView();
    }

    return _buildSelectionView();
  }

  Widget _buildSelectionView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
            decoration: InputDecoration(
              hintText: 'Search venues...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: PeeplAppTokens.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Select 2–4 venues (${_selectedNames.length}/$_maxVenues)',
            style: TextStyle(
              color: PeeplAppTokens.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        if (_loadError != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_loadError!, textAlign: TextAlign.center),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadVenueList,
            child: _filteredVenues.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No venues found')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: _filteredVenues.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final venue = _filteredVenues[index];
                      final selected = _selectedNames.contains(venue.locationName);
                      final atMax =
                          _selectedNames.length >= _maxVenues && !selected;
                      return ListTile(
                        onTap: atMax ? null : () => _toggleVenue(venue.locationName),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: selected
                                ? PeeplAppTokens.accentBlue
                                : PeeplAppTokens.cardElevated,
                          ),
                        ),
                        tileColor: PeeplAppTokens.textPrimary,
                        leading: Icon(
                          selected ? Icons.check_circle : Icons.circle_outlined,
                          color: selected
                              ? PeeplAppTokens.accentBlue
                              : PeeplAppTokens.textMuted,
                        ),
                        title: Text(
                          venue.locationName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: PeeplAppTokens.accentBlue,
                          ),
                        ),
                        subtitle: Text(
                          '${venue.postCount} posts',
                          style: TextStyle(color: PeeplAppTokens.textSecondary),
                        ),
                        trailing: CrowdMeter(level: venue.currentCrowd, size: 40),
                      );
                    },
                  ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _selectedNames.length >= _minVenues ? _goToComparison : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PeeplAppTokens.accentBlue,
                  foregroundColor: PeeplAppTokens.textPrimary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Compare',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonView() {
    final staleCount =
        _comparisonVenues.where((v) => v['hasRecentData'] != true).length;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            itemCount: _comparisonVenues.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _buildComparisonCard(_comparisonVenues[index]),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sharing ? null : _shareComparison,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PeeplAppTokens.accentBlue,
                      foregroundColor: PeeplAppTokens.textPrimary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _sharing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Share with Friends',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                if (staleCount > 0) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _requestingPeeps ? null : _requestPeepsForStaleVenues,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PeeplAppTokens.accentBlue,
                        side: const BorderSide(color: PeeplAppTokens.accentBlue),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _requestingPeeps
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Request Peeps'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonCard(Map<String, dynamic> venue) {
    final name = venue['locationName'] as String? ?? 'Venue';
    final hasRecent = venue['hasRecentData'] == true;
    final level = (venue['crowdingLevel'] as num?)?.toInt() ?? 0;
    final label = venue['crowdLabel'] as String? ?? 'No recent data';
    final imageUrl = venue['imageUrl'] as String?;
    final minutes = venue['lastPeepedMinutes'] as int?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PeeplAppTokens.textPrimary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PeeplAppTokens.cardElevated),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: PeeplAppTokens.accentBlue,
            ),
          ),
          const SizedBox(height: 10),
          if (hasRecent) ...[
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: CrowdMeter.levelColor(level),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$level/10',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              minutes != null && minutes < 1
                  ? 'Last peeped just now'
                  : 'Last peeped ${minutes ?? 0} minutes ago',
              style: TextStyle(
                fontSize: 12,
                color: PeeplAppTokens.textSecondary,
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: PeeplAppTokens.textMuted.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'No recent data',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
