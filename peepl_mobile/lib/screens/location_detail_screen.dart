import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ad_cadence_service.dart';
import '../services/debug_log_service.dart';
import '../widgets/no_peeps_empty_state.dart';
import '../services/feed_service.dart';
import '../services/location_service.dart';
import '../services/native_ads_service.dart';
import '../services/presence_service.dart';
import '../utils/post_crowd_format.dart';
import '../widgets/ad_card.dart';
import '../widgets/detail/detail_activity_ticker.dart';
import '../widgets/detail/detail_comment_input.dart';
import '../widgets/detail/detail_comment_tile.dart';
import '../widgets/detail/detail_crowd_score_card.dart';
import '../widgets/detail/detail_deals_card.dart';
import '../widgets/detail/detail_explore_live_button.dart';
import '../widgets/detail/detail_hero_header.dart';
import '../widgets/detail/detail_live_peeps_row.dart';
import '../widgets/detail/detail_metrics_grid.dart';
import '../widgets/detail/detail_peep_card.dart';
import '../widgets/detail/detail_section_card.dart';
import '../widgets/detail/detail_social_bar.dart';
import '../widgets/detail/peepl_detail_tokens.dart';

class LocationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> postData;

  const LocationDetailScreen({Key? key, required this.postData})
      : super(key: key);

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  final FeedService _feedService = FeedService();
  final NativeAdsService _adsService = NativeAdsService();
  final AdCadenceService _cadence = AdCadenceService();
  final TextEditingController _commentController = TextEditingController();

  bool _isLiked = false;
  bool _isSubmittingComment = false;
  bool _isRequestingLive = false;
  late int _likesCount;
  List<Map<String, dynamic>> _availableAds = [];
  List<Map<String, dynamic>> _venuePeeps = [];
  bool _loadingVenuePeeps = true;

  @override
  void initState() {
    super.initState();
    _likesCount = (widget.postData['likesCount'] as num?)?.toInt() ?? 0;
    _checkIfLiked();
    _initAds();
    _loadVenuePeeps();
  }

  Future<void> _loadVenuePeeps() async {
    final peeps = await _fetchPeepsForVenue();
    if (!mounted) return;
    setState(() {
      _venuePeeps = peeps;
      _loadingVenuePeeps = false;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchPeepsForVenue() async {
    final latitude = (widget.postData['latitude'] as num?)?.toDouble();
    final longitude = (widget.postData['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('location_posts')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    const radiusKm = 0.2; // 200 metres — same venue threshold

    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .where((post) {
          final postLat = (post['latitude'] as num?)?.toDouble();
          final postLng = (post['longitude'] as num?)?.toDouble();
          if (postLat == null || postLng == null) return false;
          return _haversineKm(
                latitude,
                longitude,
                postLat,
                postLng,
              ) <=
              radiusKm;
        })
        .toList();
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * pi / 180;

  Future<void> _initAds() async {
    // Uniform every-3rd-slot spacing; overrides the irregular feed pattern.
    await _cadence.init(pattern: [3, 3, 3, 3]);

    // Get cached user location (no new permission request — already resolved
    // by FeedScreen or DiscoverScreen earlier in the session).
    final pos = await LocationService.getCurrentLocation();
    final userLat = pos?.latitude;
    final userLng = pos?.longitude;

    // Detect vicarious peepling for this specific venue.
    // If the user is >80 km from the venue, serve travel ads instead.
    final venueLat = (widget.postData['latitude'] as num?)?.toDouble();
    final venueLng = (widget.postData['longitude'] as num?)?.toDouble();
    String context = 'venue';
    if (userLat != null &&
        userLng != null &&
        venueLat != null &&
        venueLng != null &&
        venueLat != 0 &&
        venueLng != 0) {
      if (NativeAdsService.detectVicariousPeepling(
        userLat: userLat,
        userLng: userLng,
        venueLat: venueLat,
        venueLng: venueLng,
      )) {
        context = 'travel';
      }
    }

    try {
      final ads = await _adsService.getAdsForFeed(
        context: context,
        userLocation: widget.postData['locationName'] as String?,
        userLat: userLat,
        userLng: userLng,
        limit: 5,
      );
      if (mounted) setState(() => _availableAds = ads);
    } catch (e) {
      debugPrint('LocationDetail: failed to load ads: $e');
    }
  }

  /// Interleaves [_availableAds] into a comment doc list using the cadence.
  /// Returns a mixed list of [QueryDocumentSnapshot] and ad [Map] entries.
  List<dynamic> _interleaveAdsIntoComments(List<QueryDocumentSnapshot> docs) {
    _cadence.resetForMerge(postCount: docs.length);
    final items = <dynamic>[];
    var adIndex = 0;

    for (final doc in docs) {
      if (_availableAds.isNotEmpty) {
        bool adAdded = false;
        for (var i = 0; i < _availableAds.length; i++) {
          final candidate = _availableAds[(adIndex + i) % _availableAds.length];
          if (_cadence.shouldShowAd(candidateAdId: candidate['id'] as String?)) {
            items.add({'_isAd': true, ...candidate});
            adIndex += i + 1;
            adAdded = true;
            break;
          }
          if (!_cadence.isSlotPending) break;
        }
        if (!adAdded && _cadence.isSlotPending) _cadence.skipSlot();
      }

      items.add(doc);
    }
    return items;
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final adId = ad['id'] as String? ?? '';
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdCard(
        ad: ad,
        onImpression: () => _adsService.recordAdImpression(adId, uid),
        onTap: () => _adsService.recordAdClick(adId, uid),
      ),
    );
  }

  Future<void> _checkIfLiked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final postId = widget.postData['id'] as String?;
    if (postId == null) return;
    final liked = await _feedService.isLocationPostLiked(postId, user.uid);
    if (mounted) setState(() => _isLiked = liked);
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (_isLiked) {
        await _feedService.unlikeLocationPost(widget.postData['id'], user.uid);
        if (!mounted) return;
        setState(() {
          _isLiked = false;
          _likesCount--;
        });
      } else {
        await _feedService.likeLocationPost(widget.postData['id'], user.uid);
        if (!mounted) return;
        setState(() {
          _isLiked = true;
          _likesCount++;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update like: $e')),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final postId = widget.postData['id'] as String?;
    if (postId == null) return;

    setState(() => _isSubmittingComment = true);
    try {
      await FirebaseFirestore.instance
          .collection('location_posts')
          .doc(postId)
          .collection('comments')
          .add({
        'userId': user.uid,
        'username': user.displayName ?? user.email ?? 'Anonymous',
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('location_posts')
          .doc(widget.postData['id'])
          .update({'commentsCount': FieldValue.increment(1)});
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  static String _relativeTime(dynamic timestamp) {
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

  static IconData _metricIconForKey(String key) {
    switch (key) {
      case 'M/F':
        return Icons.people_outline_rounded;
      case 'A/K':
        return Icons.family_restroom_outlined;
      case 'Noise':
        return Icons.volume_up_outlined;
      case 'Wait':
        return Icons.hourglass_empty_outlined;
      case 'Staff':
        return Icons.support_agent_outlined;
      case 'Vibe':
        return Icons.emoji_emotions_outlined;
      case 'Venue type':
        return Icons.storefront_outlined;
      case 'Age range':
        return Icons.cake_outlined;
      case 'Pets':
        return Icons.pets_outlined;
      case 'Crowd':
        return Icons.groups_outlined;
      case 'Dress':
        return Icons.checkroom_outlined;
      case 'Music':
        return Icons.music_note_outlined;
      case 'Wheelchair':
        return Icons.accessible_outlined;
      case 'Stroller':
        return Icons.stroller_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  List<DetailMetricItem> _primaryMetrics(Map<String, String> details) {
    const primaryKeys = ['M/F', 'A/K', 'Noise', 'Wait', 'Staff', 'Vibe'];
    return primaryKeys
        .where((key) => details.containsKey(key))
        .map(
          (key) => DetailMetricItem(
            icon: _metricIconForKey(key),
            title: key,
            value: details[key]!,
          ),
        )
        .toList();
  }

  List<DetailMetricItem> _secondaryMetrics(Map<String, String> details) {
    const primaryKeys = {'M/F', 'A/K', 'Noise', 'Wait', 'Staff', 'Vibe', 'Deals'};
    return details.entries
        .where((e) => !primaryKeys.contains(e.key))
        .map(
          (e) => DetailMetricItem(
            icon: _metricIconForKey(e.key),
            title: e.key,
            value: e.value,
          ),
        )
        .toList();
  }

  /// True when post has usable GPS (not missing and not placeholder 0,0).
  static bool _hasValidMapCoords(Map<String, dynamic> post) {
    final lat = (post['latitude'] as num?)?.toDouble();
    final lng = (post['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return false;
    if (lat == 0 && lng == 0) return false;
    if (lat.abs() > 90 || lng.abs() > 180) return false;
    return true;
  }

  Future<void> _openGeoInMaps(double lat, double lng) async {
    final uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps app.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open maps: $e')),
        );
      }
    }
  }

  Widget _buildLocationMapSection(Map<String, dynamic> post) {
    final lat = (post['latitude'] as num).toDouble();
    final lng = (post['longitude'] as num).toDouble();
    final target = LatLng(lat, lng);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GoogleMap(
              key: ValueKey<String>('map_${lat}_$lng'),
              initialCameraPosition: CameraPosition(
                target: target,
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('post_location'),
                  position: target,
                ),
              },
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _openGeoInMaps(lat, lng),
          icon: const Icon(Icons.map_outlined),
          label: const Text('Open in Maps'),
          style: OutlinedButton.styleFrom(
            foregroundColor: PeeplDetailTokens.accentBlue,
            side: const BorderSide(color: PeeplDetailTokens.border),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.postData;
    final crowdingLevel =
        (post['crowdingLevel'] as num?)?.toInt() ?? 0;
    final postId = post['id'] as String?;

    final Map<String, String> details = {};
    final venue = post['venueType']?.toString().trim();
    if (venue != null && venue.isNotEmpty) {
      details['Venue type'] = venue;
    }
    final mfShort = PostCrowdFormat.maleFemaleShort(post['maleFemaleRatio']);
    if (mfShort != null) details['M/F'] = mfShort;
    final akShort = PostCrowdFormat.adultKidShort(post['adultKidRatio']);
    if (akShort != null) details['A/K'] = akShort;
    final ageR = post['ageRange']?.toString().trim();
    if (ageR != null && ageR.isNotEmpty) details['Age range'] = ageR;
    if (post['hasPets'] == true) details['Pets'] = 'Yes';
    if (post['vibe'] != null) details['Vibe'] = '${post['vibe']}';
    if (post['waitTime'] != null) details['Wait'] = '${post['waitTime']}';
    final noiseLevel = post['noiseLevel'];
    if (noiseLevel != null) {
      final n = noiseLevel is num
          ? noiseLevel.toInt()
          : int.tryParse('$noiseLevel');
      if (n != null) details['Noise'] = '$n/10';
    }
    final staffAvailability = post['staffAvailability'];
    if (staffAvailability != null) {
      final s = staffAvailability is num
          ? staffAvailability.toInt()
          : int.tryParse('$staffAvailability');
      if (s != null) details['Staff'] = '$s/10';
    }
    if (post['demographics'] != null) {
      details['Crowd'] = '${post['demographics']}';
    }
    if (post['dressCode'] != null) details['Dress'] = '${post['dressCode']}';
    if (post['hasMusic'] == true) details['Music'] = 'Yes';
    if (post['wheelchairAccessible'] == true) {
      details['Wheelchair'] = 'Accessible';
    }
    if (post['strollerFriendly'] == true) details['Stroller'] = 'Friendly';
    if (post['hasDeals'] == true) details['Deals'] = 'Available';

    return Scaffold(
      backgroundColor: PeeplDetailTokens.background,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroSection(context, post, crowdingLevel),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildContent(post, postId, details),
                  ),
                ],
              ),
            ),
          ),
          DetailCommentInput(
            controller: _commentController,
            isSubmitting: _isSubmittingComment,
            onSubmit: _submitComment,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(
    BuildContext context,
    Map<String, dynamic> post,
    int crowdingLevel,
  ) {
    final imageUrl = post['imageUrl'] as String?;
    final locationName = post['locationName'] as String? ?? 'Unknown Location';
    final username = post['username'] as String? ?? 'Unknown';
    final timeLabel = _relativeTime(post['timestamp']);
    final address = post['address'] as String? ?? post['formattedAddress'] as String?;
    final trendRaw = (post['crowdTrend'] ?? post['trend'])?.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        DetailHeroHeader(
          imageUrl: imageUrl,
          locationName: locationName,
          username: username,
          timeLabel: timeLabel,
          peepCountLabel: null,
          address: address,
          onBack: () => Navigator.pop(context),
          onShare: () {
            Navigator.pushNamed(
              context,
              '/share',
              arguments: {
                ...post,
                'postId': post['id'] as String? ?? post['postId'] as String?,
                'locationName': post['locationName'] as String?,
                'crowdingLevel': crowdingLevel,
              },
            );
          },
          onMenu: () => Navigator.pushNamed(
            context,
            '/report',
            arguments: {
              'postId': post['id'] as String? ?? '',
              'reportedUserId': post['userId'] as String? ?? '',
            },
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 272,
          child: DetailCrowdScoreCard(
            crowdingLevel: crowdingLevel,
            trendRaw: trendRaw,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    Map<String, dynamic> post,
    String? postId,
    Map<String, String> details,
  ) {
    final primaryMetrics = _primaryMetrics(details);
    final secondaryMetrics = _secondaryMetrics(details);
    final description = post['description'] as String? ?? '';
    final imageUrl = post['imageUrl'] as String?;
    final username = post['username'] as String? ?? 'Unknown';
    final timeLabel = _relativeTime(post['timestamp']);
    final hasDeals = post['hasDeals'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 56),
        if (primaryMetrics.isNotEmpty || secondaryMetrics.isNotEmpty)
          DetailMetricsGrid(
            metrics: primaryMetrics,
            secondaryMetrics: secondaryMetrics,
          ),
        if (primaryMetrics.isNotEmpty || secondaryMetrics.isNotEmpty)
          const SizedBox(height: 4),
        _buildVenuePeepsSection(post),
        DetailExploreLiveButton(
          isLoading: _isRequestingLive,
          onTap: () => _onExploreLiveTap(),
        ),
        DetailSocialBar(
          isLiked: _isLiked,
          likesCount: _likesCount,
          commentsCount: (post['commentsCount'] as num?)?.toInt() ?? 0,
          onLikeTap: _toggleLike,
          onLikesCountTap: () {
            final id = widget.postData['id'] as String?;
            if (id != null && id.isNotEmpty) {
              Navigator.pushNamed(
                context,
                '/likers',
                arguments: {
                  'postId': id,
                  'locationName':
                      widget.postData['locationName'] as String? ?? '',
                },
              );
            }
          },
          onShareTap: () {
            Navigator.pushNamed(
              context,
              '/share',
              arguments: {
                ...widget.postData,
                'postId': widget.postData['id'] as String? ??
                    widget.postData['postId'] as String?,
                'locationName': widget.postData['locationName'] as String?,
                'crowdingLevel':
                    (widget.postData['crowdingLevel'] as num?)?.toInt() ?? 0,
              },
            );
          },
          onReportTap: () => Navigator.pushNamed(
            context,
            '/report',
            arguments: {
              'postId': widget.postData['id'] as String? ?? '',
              'reportedUserId': widget.postData['userId'] as String? ?? '',
            },
          ),
        ),
        if (description.isNotEmpty || (imageUrl != null && imageUrl.isNotEmpty))
          DetailPeepCard(
            imageUrl: imageUrl,
            caption: description,
            author: username,
            timeLabel: timeLabel,
            isLiked: _isLiked,
            onLikeTap: _toggleLike,
          ),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Comments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: PeeplDetailTokens.textPrimary,
            ),
          ),
        ),
        if (postId != null) _buildCommentsStream(postId),
        if (_hasValidMapCoords(post)) ...[
          DetailSectionCard(
            title: 'Location',
            child: _buildLocationMapSection(post),
          ),
        ],
        if (hasDeals)
          DetailDealsCard(onTap: () {}),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _onExploreLiveTap() async {
    DebugLogService.log('EXPLORE_LIVE', 'Explore Live tapped');
    DebugLogService.log(
      'EXPLORE_LIVE',
      'Post data: ${widget.postData}',
    );
    DebugLogService.log(
      'EXPLORE_LIVE',
      'Lat: ${widget.postData['latitude']}, '
      'Lng: ${widget.postData['longitude']}',
    );
    DebugLogService.log(
      'EXPLORE_LIVE',
      'User: ${FirebaseAuth.instance.currentUser?.uid}',
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isRequestingLive = true);

    try {
      final latitude =
          (widget.postData['latitude'] as num?)?.toDouble() ?? 0.0;
      final longitude =
          (widget.postData['longitude'] as num?)?.toDouble() ?? 0.0;
      final locationName =
          widget.postData['locationName'] as String? ?? 'this location';

      List<Map<String, dynamic>> presence;
      try {
        DebugLogService.log(
          'EXPLORE_LIVE',
          'Calling getActivePresence...',
        );
        presence = await PresenceService.instance.getActivePresence(
          latitude,
          longitude,
        );
        DebugLogService.log(
          'EXPLORE_LIVE',
          'getActivePresence returned: ${presence.length} results',
        );
        DebugLogService.log(
          'EXPLORE_LIVE',
          'Presence result: $presence',
        );
      } catch (presenceError) {
        DebugLogService.log(
          'EXPLORE_LIVE',
          'getActivePresence FAILED: $presenceError',
        );
        rethrow;
      }

      if (presence.isNotEmpty) {
        await PresenceService.instance.sendCrowdsourceRequest(
          locationName: locationName,
          latitude: latitude,
          longitude: longitude,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📍 Request sent to ${presence.length} '
              '${presence.length == 1 ? 'person' : 'people'} at '
              '$locationName!',
            ),
            backgroundColor: PeeplDetailTokens.accentBlue,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        await FirebaseFirestore.instance
            .collection('crowdsource_requests')
            .add({
          'requesterId': user.uid,
          'locationName': widget.postData['locationName'] ?? '',
          'latitude': latitude,
          'longitude': longitude,
          'status': 'waiting',
          'createdAt': FieldValue.serverTimestamp(),
          'notifyOnArrival': true,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🔔 No one is there right now. '
              'We\'ll notify you when someone arrives at '
              '$locationName!',
            ),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
      DebugLogService.log(
        'EXPLORE_LIVE',
        'Explore Live error: $e — stack: $stackTrace',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          duration: const Duration(seconds: 8),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRequestingLive = false);
      }
    }
  }

  Widget _buildVenuePeepsSection(Map<String, dynamic> post) {
    final locationName = post['locationName'] as String? ?? '';
    final currentPostId = post['id'] as String?;
    if (locationName.isEmpty) return const SizedBox.shrink();

    if (_loadingVenuePeeps) return const SizedBox.shrink();

    final othersExist =
        _venuePeeps.any((p) => p['id'] != currentPostId);

    if (!othersExist) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: NoPeepsEmptyState(locationName: locationName),
      );
    }

    final others =
        _venuePeeps.where((p) => p['id'] != currentPostId).toList();
    final usernames = others
        .map(
          (p) => p['username'] as String? ?? 'Anonymous',
        )
        .toList();

    String? activityText;
    if (others.isNotEmpty) {
      final latest = others.last;
      final name = latest['username'] as String? ?? 'Someone';
      activityText = '$name posted';
    }

    return Column(
      children: [
        if (activityText != null) DetailActivityTicker(text: activityText),
        if (usernames.isNotEmpty)
          DetailLivePeepsRow(
            usernames: usernames,
            totalCount: _venuePeeps.length,
          ),
      ],
    );
  }

  Widget _buildCommentsStream(String postId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('location_posts')
          .doc(postId)
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load comments',
              style: TextStyle(
                color: PeeplDetailTokens.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: PeeplDetailTokens.accentBlue),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Text(
            'No comments yet. Be the first!',
            style: TextStyle(
              color: PeeplDetailTokens.textSecondary.withValues(alpha: 0.8),
            ),
          );
        }

        final items = _interleaveAdsIntoComments(snapshot.data!.docs);

        return Column(
          children: items.map((item) {
            if (item is Map<String, dynamic> && item['_isAd'] == true) {
              return _buildAdCard(item);
            }

            final data =
                (item as QueryDocumentSnapshot).data() as Map<String, dynamic>;
            final commentUser = data['username'] as String? ?? 'Anonymous';
            return DetailCommentTile(
              username: commentUser,
              text: data['text'] ?? '',
              timeLabel: _relativeTime(data['timestamp']),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
