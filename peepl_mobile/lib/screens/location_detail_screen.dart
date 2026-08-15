import 'dart:math';
import '../theme/peepl_app_tokens.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ad_cadence_service.dart';
import '../services/share_service.dart';
import '../services/crowdsource_service.dart';
import '../services/feed_service.dart';
import '../services/location_service.dart';
import '../services/native_ads_service.dart';
import '../services/venue_name_service.dart';
import '../utils/post_crowd_format.dart';
import '../widgets/ad_card.dart';
import '../widgets/detail/detail_comment_input.dart';
import '../widgets/detail/detail_comment_tile.dart';
import '../widgets/detail/detail_crowd_score_card.dart';
import '../widgets/detail/detail_deals_card.dart';
import '../widgets/detail/detail_hero_header.dart';
import '../widgets/detail/detail_live_now_module.dart';
import '../widgets/detail/detail_metrics_grid.dart';
import '../widgets/detail/detail_peep_card.dart';
import '../widgets/detail/detail_section_card.dart';
import '../widgets/detail/detail_social_bar.dart';
import '../widgets/detail/peepl_detail_tokens.dart';
import '../widgets/home/peepl_home_background.dart';

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
  bool _isSubmittingCrowdsource = false;
  late int _likesCount;
  List<Map<String, dynamic>> _availableAds = [];
  List<Map<String, dynamic>> _venuePeeps = [];
  bool _loadingVenuePeeps = true;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  int? _contributorCount;
  late final String _locationId;
  late String _displayVenueName;

  static String _resolveLocationId(Map<String, dynamic> post) {
    final venueId = post['venueId'] as String?;
    if (venueId != null && venueId.trim().isNotEmpty) return venueId.trim();
    final locationName = post['locationName'] as String?;
    if (locationName != null && locationName.trim().isNotEmpty) {
      return locationName.trim();
    }
    return 'unknown';
  }

  @override
  void initState() {
    super.initState();
    _locationId = _resolveLocationId(widget.postData);
    _displayVenueName = VenueNameService.storedVenueName(widget.postData) ??
        VenueNameService.addressFallback(widget.postData) ??
        'Unknown Location';
    _likesCount = (widget.postData['likesCount'] as num?)?.toInt() ?? 0;
    _checkIfLiked();
    _loadFollowState();
    _initAds();
    _loadVenuePeeps();
    _loadContributorCount();
    _recordPeepViewForVenue();
    _resolveDisplayVenueName();
  }

  Future<void> _resolveDisplayVenueName() async {
    final resolved = await VenueNameService.displayNameForPost(widget.postData);
    if (mounted && resolved != _displayVenueName) {
      setState(() => _displayVenueName = resolved);
    }
  }

  Future<void> _loadContributorCount() async {
    final locationName = widget.postData['locationName'] as String? ?? '';
    if (locationName.isEmpty) return;

    try {
      final count =
          await _feedService.getVenueContributorCount(locationName);
      if (!mounted) return;
      setState(() => _contributorCount = count);
    } catch (_) {}
  }

  Future<void> _recordPeepViewForVenue() async {
    final postId = widget.postData['id'] as String?;
    if (postId == null || postId.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final locationName = widget.postData['locationName'] as String? ?? '';
    if (locationName.isEmpty) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('location_posts')
          .where('locationName', isEqualTo: locationName)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return;
      await _feedService.recordPeepView(snap.docs.first.id, user.uid);
    } catch (_) {}
  }

  Future<void> _loadFollowState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final followed =
        await _feedService.isLocationFollowed(user.uid, _locationId);
    if (!mounted) return;
    setState(() => _isFollowing = followed);
  }

  Future<void> _toggleFollow(String locationName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to follow this location.')),
      );
      return;
    }

    setState(() => _isFollowLoading = true);
    try {
      if (_isFollowing) {
        await _feedService.unfollowLocation(user.uid, _locationId);
      } else {
        await _feedService.followLocation(
          user.uid,
          _locationId,
          locationName,
        );
      }
      if (!mounted) return;
      setState(() => _isFollowing = !_isFollowing);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update follow status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
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

    const radiusKm = 0.2;

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
    await _cadence.init(pattern: [3, 3, 3, 3]);

    final pos = await LocationService.getCurrentLocation();
    final userLat = pos?.latitude;
    final userLng = pos?.longitude;

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
      padding: const EdgeInsets.only(bottom: 8),
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
      case 'Age':
        return Icons.cake_outlined;
      case 'Wait':
        return Icons.hourglass_empty_outlined;
      case 'Vibe':
        return Icons.emoji_emotions_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  List<DetailMetricItem> _horizontalMetrics(Map<String, dynamic> post) {
    const keys = ['M/F', 'Age', 'Wait', 'Vibe'];
    final values = <String, String>{};

    final mfShort = PostCrowdFormat.maleFemaleShort(post['maleFemaleRatio']);
    if (mfShort != null) values['M/F'] = mfShort;

    final ageRange = post['ageRange']?.toString().trim();
    if (ageRange != null && ageRange.isNotEmpty) {
      values['Age'] = ageRange;
    } else {
      final akShort = PostCrowdFormat.adultKidShort(post['adultKidRatio']);
      if (akShort != null) values['Age'] = akShort;
    }

    if (post['waitTime'] != null) values['Wait'] = '${post['waitTime']}';
    if (post['vibe'] != null) values['Vibe'] = '${post['vibe']}';

    return keys
        .where(values.containsKey)
        .map(
          (key) => DetailMetricItem(
            icon: _metricIconForKey(key),
            title: key,
            value: values[key]!,
          ),
        )
        .toList();
  }

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

  String? _locationSubtitle(Map<String, dynamic> post) {
    final address =
        post['address'] as String? ?? post['formattedAddress'] as String?;
    if (address != null && address.trim().isNotEmpty) return address.trim();
    final locationName = post['locationName'] as String?;
    if (locationName != null &&
        locationName.trim().isNotEmpty &&
        VenueNameService.looksLikeAddress(locationName)) {
      return locationName.trim();
    }
    return null;
  }

  Widget _buildCompactLocationSection(Map<String, dynamic> post) {
    final lat = (post['latitude'] as num).toDouble();
    final lng = (post['longitude'] as num).toDouble();
    final target = LatLng(lat, lng);
    final locationName = _displayVenueName;
    final subtitle = _locationSubtitle(post);

    return DetailSectionCard(
      title: 'Location',
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 96,
              height: 96,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PeeplDetailTokens.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null && subtitle != locationName) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PeeplDetailTokens.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => _openGeoInMaps(lat, lng),
                  style: TextButton.styleFrom(
                    foregroundColor: PeeplDetailTokens.accentBlue,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Open in Maps',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
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

  List<String> _liveUsernames() {
    final currentPostId = widget.postData['id'] as String?;
    final others = _venuePeeps.where((p) => p['id'] != currentPostId).toList();
    final currentInVenue =
        _venuePeeps.where((p) => p['id'] == currentPostId).toList();
    final displayPeeps = [...currentInVenue, ...others];
    return displayPeeps
        .map((p) => p['username'] as String? ?? 'Anonymous')
        .toList();
  }

  String? _liveActivityText() {
    if (_venuePeeps.isEmpty) return null;
    final latest = _venuePeeps.last;
    final name = latest['username'] as String? ?? 'Someone';
    return '$name posted';
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.postData;
    final crowdingLevel = (post['crowdingLevel'] as num?)?.toInt() ?? 0;
    final postId = post['id'] as String?;
    final horizontalMetrics = _horizontalMetrics(post);
    final commentsCount = (post['commentsCount'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PeeplHomeBackground(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroSection(context, post, crowdingLevel),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _buildContent(
                        post,
                        postId,
                        horizontalMetrics,
                        commentsCount,
                        crowdingLevel,
                      ),
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
      ),
    );
  }

  Widget _buildHeroSection(
    BuildContext context,
    Map<String, dynamic> post,
    int crowdingLevel,
  ) {
    final imageUrl = post['imageUrl'] as String?;
    final locationName = _displayVenueName;
    final venueType = post['venueType']?.toString();
    final trendRaw = (post['crowdTrend'] ?? post['trend'])?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailHeroHeader(
          imageUrl: imageUrl,
          locationName: locationName,
          venueType: venueType,
          locationSubtitle: _locationSubtitle(post),
          onBack: () => Navigator.pop(context),
          onShare: () async {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sign in to share this venue.')),
              );
              return;
            }
            await ShareService.instance.shareVenueStatus(
              locationName: locationName,
              crowdingLevel: crowdingLevel,
              sharingUserId: user.uid,
              venueId: post['venueId'] as String?,
            );
          },
          onFollow: () => _toggleFollow(locationName),
          isFollowing: _isFollowing,
          isFollowLoading: _isFollowLoading,
          onMenu: () => Navigator.pushNamed(
            context,
            '/report',
            arguments: {
              'postId': post['id'] as String? ?? '',
              'reportedUserId': post['userId'] as String? ?? '',
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DetailCrowdScoreCard(
            crowdingLevel: crowdingLevel,
            trendRaw: trendRaw,
            contributorCount: _contributorCount,
            isLive: crowdingLevel > 0 || _venuePeeps.isNotEmpty,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    Map<String, dynamic> post,
    String? postId,
    List<DetailMetricItem> horizontalMetrics,
    int commentsCount,
    int crowdingLevel,
  ) {
    final description = post['description'] as String? ?? '';
    final username = post['username'] as String? ?? 'Unknown';
    final timeLabel = _relativeTime(post['timestamp']);
    final hasDeals = post['hasDeals'] == true;
    final locationName = post['locationName'] as String? ?? '';
    final photoUrl = post['photoUrl'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (horizontalMetrics.isNotEmpty)
          DetailMetricsGrid(metrics: horizontalMetrics),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: CrowdsourceService.instance
              .getActiveRequestsForLocation(locationName),
          builder: (context, snapshot) {
            final crowdsourceCount =
                snapshot.hasData ? snapshot.data!.docs.length : null;
            return DetailLiveNowModule(
              usernames: _liveUsernames(),
              totalCount: _venuePeeps.length,
              isLoading: _loadingVenuePeeps,
              isSubmittingExploreLive: _isSubmittingCrowdsource,
              onExploreLive: _sendExploreLiveRequest,
              activityText: _liveActivityText(),
              crowdsourceCount: crowdsourceCount,
              onPeepHere: locationName.isEmpty
                  ? null
                  : () => Navigator.pushNamed(
                        context,
                        '/post',
                        arguments: {'locationName': locationName},
                      ),
            );
          },
        ),
        DetailSocialBar(
          isLiked: _isLiked,
          likesCount: _likesCount,
          commentsCount: commentsCount,
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
        DetailPeepCard(
          caption: description,
          author: username,
          timeLabel: timeLabel,
          isLiked: _isLiked,
          onLikeTap: _toggleLike,
          photoUrl: photoUrl,
          onMenu: () => Navigator.pushNamed(
            context,
            '/report',
            arguments: {
              'postId': widget.postData['id'] as String? ?? '',
              'reportedUserId': widget.postData['userId'] as String? ?? '',
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Comments · $commentsCount',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PeeplDetailTokens.textPrimary,
            ),
          ),
        ),
        if (postId != null) _buildCommentsStream(postId),
        if (_hasValidMapCoords(post)) _buildCompactLocationSection(post),
        if (hasDeals) DetailDealsCard(onTap: () {}),
      ],
    );
  }

  Future<void> _sendExploreLiveRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final locationName =
        widget.postData['locationName'] as String? ?? 'this location';
    final latitude = (widget.postData['latitude'] as num?)?.toDouble();
    final longitude = (widget.postData['longitude'] as num?)?.toDouble();

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location data not available')),
      );
      return;
    }

    setState(() => _isSubmittingCrowdsource = true);

    try {
      final postAuthorId = widget.postData['userId'] as String?;
      final result = await CrowdsourceService.instance.createRequestAndAwaitDelivery(
        requestedBy: user.uid,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        source: 'location_detail',
        postAuthorId: postAuthorId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.userMessage),
          backgroundColor: result.delivered
              ? PeeplAppTokens.shellNavy
              : Colors.orange.shade800,
        ),
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Invalid location')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send request. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingCrowdsource = false);
    }
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
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(
                color: PeeplDetailTokens.accentBlue,
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Be the first to comment.',
              style: TextStyle(
                color: PeeplDetailTokens.textSecondary,
                fontSize: 14,
              ),
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
