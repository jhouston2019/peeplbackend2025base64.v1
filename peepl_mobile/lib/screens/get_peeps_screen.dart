import 'dart:async';
import '../theme/peepl_app_tokens.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/crowdsource_service.dart';
import '../widgets/crowd_meter.dart';
import 'location_detail_screen.dart';

const _kRecentRequestsKey = 'recent_requests';
const _kMaxRecent = 8;

class _SelectedLocation {
  final String locationName;
  final String locationId;
  final double latitude;
  final double longitude;

  const _SelectedLocation({
    required this.locationName,
    required this.locationId,
    required this.latitude,
    required this.longitude,
  });
}

class GetPeepsScreen extends StatefulWidget {
  const GetPeepsScreen({super.key});

  @override
  State<GetPeepsScreen> createState() => _GetPeepsScreenState();
}

class _GetPeepsScreenState extends State<GetPeepsScreen> {
  final _db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<String> _recentRequests = [];
  List<Map<String, dynamic>> _searchResults = [];
  _SelectedLocation? _selected;
  bool _searchLoading = false;
  bool _sending = false;
  String _searchTerm = '';

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadRecentRequests();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kRecentRequestsKey) ?? [];
      if (mounted) setState(() => _recentRequests = raw);
    } catch (e) {
      debugPrint('GetPeepsScreen recent_requests: $e');
    }
  }

  Future<void> _saveRecentRequest(String locationName) async {
    final name = locationName.trim();
    if (name.isEmpty) return;
    final updated = [name, ..._recentRequests.where((r) => r != name)]
        .take(_kMaxRecent)
        .toList();
    setState(() => _recentRequests = updated);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kRecentRequestsKey, updated);
    } catch (e) {
      debugPrint('GetPeepsScreen save recent: $e');
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final term = value.trim();
    setState(() => _searchTerm = term);
    if (term.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _searchLocations(term),
    );
  }

  Future<void> _searchLocations(String term) async {
    setState(() => _searchLoading = true);
    try {
      final snap = await _db
          .collection('location_posts')
          .where('locationName', isGreaterThanOrEqualTo: term)
          .where('locationName', isLessThanOrEqualTo: '$term\uf8ff')
          .orderBy('locationName')
          .limit(20)
          .get();

      final byName = <String, Map<String, dynamic>>{};
      for (final doc in snap.docs) {
        final data = {...doc.data(), 'id': doc.id};
        final name = data['locationName'] as String? ?? '';
        if (name.isNotEmpty) byName.putIfAbsent(name, () => data);
      }

      if (mounted) {
        setState(() {
          _searchResults = byName.values.toList();
          _searchLoading = false;
        });
      }
    } catch (e) {
      debugPrint('GetPeepsScreen search: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searchLoading = false;
        });
      }
    }
  }

  Future<void> _selectFromPost(Map<String, dynamic> post) async {
    final name = post['locationName'] as String? ?? '';
    if (name.isEmpty) return;
    _searchController.text = name;
    setState(() {
      _selected = _SelectedLocation(
        locationName: name,
        locationId: post['id'] as String? ?? name,
        latitude: (post['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (post['longitude'] as num?)?.toDouble() ?? 0.0,
      );
      _searchResults = [];
      _searchTerm = name;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _selectByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    _searchController.text = trimmed;
    setState(() => _searchLoading = true);

    try {
      final snap = await _db
          .collection('location_posts')
          .where('locationName', isEqualTo: trimmed)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      double lat = 0;
      double lng = 0;
      String locationId = trimmed;
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        lat = (data['latitude'] as num?)?.toDouble() ?? 0;
        lng = (data['longitude'] as num?)?.toDouble() ?? 0;
        locationId = snap.docs.first.id;
      }

      if (mounted) {
        setState(() {
          _selected = _SelectedLocation(
            locationName: trimmed,
            locationId: locationId,
            latitude: lat,
            longitude: lng,
          );
          _searchResults = [];
          _searchTerm = trimmed;
          _searchLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selected = _SelectedLocation(
            locationName: trimmed,
            locationId: trimmed,
            latitude: 0,
            longitude: 0,
          );
          _searchLoading = false;
        });
      }
    }
    if (mounted) FocusScope.of(context).unfocus();
  }

  Future<void> _sendRequest() async {
    final loc = _selected;
    if (loc == null || _uid.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final requestId = await CrowdsourceService.instance.createRequest(
        locationId: loc.locationId,
        locationName: loc.locationName,
        latitude: loc.latitude,
        longitude: loc.longitude,
      );

      if (!mounted) return;

      if (requestId != null) {
        await _saveRecentRequest(loc.locationName);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Request sent! We'll notify you when someone responds.",
            ),
            backgroundColor: PeeplAppTokens.shellNavy,
          ),
        );
        setState(() {
          _selected = null;
          _searchController.clear();
          _searchTerm = '';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send request. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static String _statusLabel(String? status) {
    if (status == 'pending') return 'Pending';
    if (status == 'fulfilled' || status == 'responded') return 'Responded';
    return status ?? 'Unknown';
  }

  static Color _statusColor(String? status) {
    if (status == 'pending') return const Color(0xFFFFA726);
    if (status == 'fulfilled' || status == 'responded') {
      return const Color(0xFF4CAF50);
    }
    return Colors.grey;
  }

  static String _formatTimestamp(dynamic ts) {
    if (ts is! Timestamp) return '';
    final dt = ts.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}';
  }

  static int _compareDocTimestamp(
    QueryDocumentSnapshot a,
    QueryDocumentSnapshot b,
  ) {
    final ta = (a.data() as Map<String, dynamic>?)?['timestamp'];
    final tb = (b.data() as Map<String, dynamic>?)?['timestamp'];
    if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
    return 0;
  }

  Future<void> _openResponse(Map<String, dynamic> response) async {
    final postId = response['postId'] as String?;
    if (postId == null || postId.isEmpty) return;

    try {
      final postDoc = await _db.collection('location_posts').doc(postId).get();
      if (!mounted) return;

      final postData = postDoc.exists
          ? {...postDoc.data()!, 'id': postDoc.id}
          : <String, dynamic>{
              'id': postId,
              'locationName': response['locationName'],
              'crowdingLevel': response['crowdingLevel'],
              'latitude': response['latitude'],
              'longitude': response['longitude'],
            };

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => LocationDetailScreen(postData: postData),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open post: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplAppTokens.shellNavy,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            _buildSearchBar(),
            Expanded(
              child: Container(
                decoration: PeeplAppTokens.shellBodyDecoration(),
                child: _uid.isEmpty
                    ? const Center(child: Text('Sign in to ask for crowd updates'))
                    : RefreshIndicator(
                        onRefresh: () async {
                          await _loadRecentRequests();
                          if (_searchTerm.isNotEmpty) {
                            await _searchLocations(_searchTerm);
                          }
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          children: [
                            if (_recentRequests.isNotEmpty) ...[
                              _buildRecentSection(),
                              const SizedBox(height: 16),
                            ],
                            if (_searchTerm.isNotEmpty && _selected == null)
                              _buildSearchResults(),
                            if (_selected != null) ...[
                              _buildPreviewCard(),
                              const SizedBox(height: 20),
                            ],
                            _buildActiveRequestsSection(),
                            const SizedBox(height: 20),
                            _buildResponsesSection(),
                          ],
                        ),
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
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: PeeplAppTokens.textPrimary),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask People Here Now',
                  style: TextStyle(
                    color: PeeplAppTokens.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Request a live crowd update',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        onSubmitted: _selectByName,
        textInputAction: TextInputAction.search,
        style: const TextStyle(color: PeeplAppTokens.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search for a location...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.85)),
          suffixIcon: _searchTerm.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.white.withValues(alpha: 0.8)),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    setState(() => _selected = null);
                  },
                )
              : null,
          filled: true,
          fillColor: PeeplAppTokens.searchField.withValues(alpha: 0.15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recentRequests.map((name) {
            return ActionChip(
              label: Text(name, style: const TextStyle(fontSize: 12)),
              avatar: const Icon(Icons.history, size: 16),
              onPressed: () => _selectByName(name),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searchLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              'No venues found — press Enter to use "$_searchTerm"',
              style: TextStyle(color: PeeplAppTokens.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _selectByName(_searchTerm),
              child: const Text('Use this location'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Results',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        ..._searchResults.map((post) {
          final name = post['locationName'] as String? ?? 'Unknown';
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined, color: PeeplAppTokens.accentBlue),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => _selectFromPost(post),
          );
        }),
      ],
    );
  }

  Widget _buildPreviewCard() {
    final loc = _selected!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PeeplAppTokens.accentBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PeeplAppTokens.accentBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: PeeplAppTokens.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on, color: PeeplAppTokens.accentBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.locationName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: PeeplAppTokens.accentBlue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Ask people there now for a crowd update',
                      style: TextStyle(fontSize: 12, color: PeeplAppTokens.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : _sendRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: PeeplAppTokens.shellNavy,
                foregroundColor: PeeplAppTokens.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PeeplAppTokens.textPrimary,
                      ),
                    )
                  : const Text(
                      'Send Request',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Requests',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: PeeplAppTokens.accentBlue,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _db
              .collectionGroup('requests')
              .where('requesterId', isEqualTo: _uid)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Text(
                'Could not load requests',
                style: TextStyle(color: PeeplAppTokens.textSecondary, fontSize: 13),
              );
            }

            final docs = snap.data?.docs ?? [];
            docs.sort(_compareDocTimestamp);

            if (docs.isEmpty) {
              return Text(
                'No active requests yet',
                style: TextStyle(color: PeeplAppTokens.textSecondary, fontSize: 13),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null) return const SizedBox.shrink();
                final status = data['status'] as String?;
                final name = data['locationName'] as String? ?? 'Unknown';
                return _RequestRow(
                  locationName: name,
                  statusLabel: _statusLabel(status),
                  statusColor: _statusColor(status),
                  timeLabel: _formatTimestamp(data['timestamp']),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildResponsesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Responses',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: PeeplAppTokens.accentBlue,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('crowdsource_responses')
              .where('requesterId', isEqualTo: _uid)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Text(
                'Could not load responses',
                style: TextStyle(color: PeeplAppTokens.textSecondary, fontSize: 13),
              );
            }

            final docs = snap.data?.docs ?? [];
            docs.sort(_compareDocTimestamp);

            if (docs.isEmpty) {
              return Text(
                'Responses will appear here when someone posts',
                style: TextStyle(color: PeeplAppTokens.textSecondary, fontSize: 13),
              );
            }

            return Column(
              children: docs.map((doc) {
                final raw = doc.data() as Map<String, dynamic>?;
                if (raw == null) return const SizedBox.shrink();
                final data = {...raw, 'id': doc.id};
                final name = data['locationName'] as String? ?? 'Unknown';
                final level = (data['crowdingLevel'] as num?)?.toInt() ?? 0;
                final username = data['responderUsername'] as String? ?? 'Someone';
                return _ResponseCard(
                  locationName: name,
                  username: username,
                  crowdingLevel: level,
                  timeLabel: _formatTimestamp(data['timestamp']),
                  onTap: () => _openResponse(data),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.locationName,
    required this.statusLabel,
    required this.statusColor,
    required this.timeLabel,
  });

  final String locationName;
  final String statusLabel;
  final Color statusColor;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: PeeplAppTokens.cardElevated),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locationName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (timeLabel.isNotEmpty)
                  Text(
                    timeLabel,
                    style: TextStyle(fontSize: 11, color: PeeplAppTokens.textSecondary),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  const _ResponseCard({
    required this.locationName,
    required this.username,
    required this.crowdingLevel,
    required this.timeLabel,
    required this.onTap,
  });

  final String locationName;
  final String username;
  final int crowdingLevel;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PeeplAppTokens.textPrimary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PeeplAppTokens.cardElevated),
          ),
          child: Row(
            children: [
              CrowdMeter(level: crowdingLevel, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locationName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: PeeplAppTokens.accentBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'From $username',
                      style: TextStyle(fontSize: 12, color: PeeplAppTokens.textSecondary),
                    ),
                    if (timeLabel.isNotEmpty)
                      Text(
                        timeLabel,
                        style: TextStyle(fontSize: 11, color: PeeplAppTokens.textMuted),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
