import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_share_links.dart';
import '../services/ad_cadence_service.dart';
import '../widgets/no_peeps_empty_state.dart';
import '../services/crowdsource_service.dart';
import '../services/feed_service.dart';
import '../services/location_service.dart';
import '../services/native_ads_service.dart';
import '../utils/post_crowd_format.dart';
import '../widgets/ad_card.dart';
import '../widgets/crowd_dot_ring_meter.dart';
import '../widgets/crowd_meter.dart';

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
  late int _likesCount;
  List<Map<String, dynamic>> _availableAds = [];

  @override
  void initState() {
    super.initState();
    _likesCount = (widget.postData['likesCount'] as num?)?.toInt() ?? 0;
    _checkIfLiked();
    _initAds();
  }

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
    _cadence.reset();
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

        final postOwnerUid = widget.postData['userId'] as String?;
        if (postOwnerUid != null && postOwnerUid != user.uid) {
          _sendLikeNotification(
            postOwnerUid: postOwnerUid,
            likerUsername: user.displayName ?? user.email?.split('@')[0] ?? 'Someone',
            postId: widget.postData['id'],
            locationName: widget.postData['locationName'] ?? '',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update like: $e')),
        );
      }
    }
  }

  void _sendLikeNotification({
    required String postOwnerUid,
    required String likerUsername,
    required String postId,
    required String locationName,
  }) async {
    try {
      await http.post(
        Uri.parse('https://peepl2025v1-production.up.railway.app/notifications/like'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'postOwnerUid': postOwnerUid,
          'likerUsername': likerUsername,
          'postId': postId,
          'locationName': locationName,
        }),
      );
    } catch (e) {
      debugPrint('[Like notification] Failed: $e');
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

  Color _getCrowdingColor(int level) {
    if (level <= 4) return const Color(0xFF4CAF50);
    if (level <= 6) return const Color(0xFFFFA726);
    return const Color(0xFFFF5722);
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

  Future<void> _shareLocationPost(Map<String, dynamic> post, int crowdingLevel) async {
    final name = post['locationName']?.toString().trim().isNotEmpty == true
        ? post['locationName'].toString().trim()
        : 'this spot';
    final status = CrowdDotRingMeter.statusWord(crowdingLevel);
    final text =
        'Check out $name on Peepl — it\'s $status right now! Download Peepl to know before you go: $kPeeplAppStoreLinkPlaceholder';
    try {
      await Share.share(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share: $e')),
        );
      }
    }
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
            foregroundColor: const Color(0xFF1565C0),
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
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            _buildImageHeader(context, post, crowdingLevel),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: _buildContent(post, postId, details),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsGrid(Map<String, String> details) {
    if (details.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: details.entries
          .map(
            (e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1565C0).withOpacity(0.2),
                ),
              ),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '${e.key}: ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: e.value),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildImageHeader(
    BuildContext context,
    Map<String, dynamic> post,
    int crowdingLevel,
  ) {
    return Stack(
      children: [
        SizedBox(
          height: 240,
          width: double.infinity,
          child: post['imageUrl'] != null &&
                  (post['imageUrl'] as String).isNotEmpty
              ? Image.network(
                  post['imageUrl'] as String,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.grey[300]),
                )
              : Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, size: 80, color: Colors.grey),
                ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.black.withOpacity(0.4),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Share',
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/share',
                    arguments: post,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Material(
                color: Colors.black.withOpacity(0.4),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Report',
                  icon: const Icon(Icons.flag_outlined, color: Colors.white),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/report',
                    arguments: post['id'] as String? ?? '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CrowdMeter(level: crowdingLevel, size: 56),
            ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post['locationName'] ?? 'Unknown Location',
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0)),
          ),
          const SizedBox(height: 4),
          Text(
            'Posted by ${post['username'] ?? 'Unknown'}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          _buildDetailsGrid(details),
          if (details.isNotEmpty) const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked ? Colors.red : Colors.grey,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          final postId =
                              widget.postData['id'] as String?;
                          if (postId != null && postId.isNotEmpty) {
                            Navigator.pushNamed(
                              context,
                              '/likers',
                              arguments: postId,
                            );
                          }
                        },
                        child: Text(
                          '$_likesCount',
                          style: TextStyle(
                            color: Colors.grey[700],
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.grey[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.comment_outlined,
                          color: Colors.grey, size: 24),
                      const SizedBox(width: 4),
                      Text(
                        '${post['commentsCount'] ?? 0}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: _sendAskRequest,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.campaign_outlined,
                              color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Ask Here Now',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_hasValidMapCoords(post)) ...[
            const SizedBox(height: 20),
            _buildLocationMapSection(post),
          ],
          _buildOtherPeepsSection(post),
          const Divider(height: 32),
          const Text('Comments',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (postId != null) _buildCommentsStream(postId),
          const SizedBox(height: 16),
          _buildCommentInput(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _sendAskRequest() async {
    final locationName =
        widget.postData['locationName'] as String? ?? '';
    final locationId =
        widget.postData['id'] as String? ?? locationName;
    final lat =
        (widget.postData['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng =
        (widget.postData['longitude'] as num?)?.toDouble() ?? 0.0;

    if (locationName.isEmpty) return;

    try {
      final requestId = await CrowdsourceService.instance.createRequest(
        locationId: locationId,
        locationName: locationName,
        latitude: lat,
        longitude: lng,
      );
      if (mounted && requestId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Asked everyone at $locationName to report crowd levels!',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFF1565C0),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to send request. Try again.')),
        );
      }
    }
  }

  /// Shows [NoPeepsEmptyState] when no other users have posted about this
  /// location — encouraging the viewer to be the first (or add another Peep).
  Widget _buildOtherPeepsSection(Map<String, dynamic> post) {
    final locationName = post['locationName'] as String? ?? '';
    final currentPostId = post['id'] as String?;
    if (locationName.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('location_posts')
          .where('locationName', isEqualTo: locationName)
          .limit(10)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final othersExist = (snap.data?.docs ?? [])
            .any((d) => d.id != currentPostId);
        if (othersExist) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: NoPeepsEmptyState(locationName: locationName),
        );
      },
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
            child: Text('Could not load comments',
                style: TextStyle(color: Colors.grey[500])));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Text('No comments yet. Be the first!',
              style: TextStyle(color: Colors.grey[500]));
        }

        final items = _interleaveAdsIntoComments(snapshot.data!.docs);

        return Column(
          children: items.map((item) {
            // Ad slot
            if (item is Map<String, dynamic> && item['_isAd'] == true) {
              return _buildAdCard(item);
            }

            // Comment row
            final data =
                (item as QueryDocumentSnapshot).data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF1565C0),
                    child: Text(
                      (data['username'] ?? 'A')[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['username'] ?? 'Anonymous',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          data['text'] ?? '',
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCommentInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: 'Add a comment...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _isSubmittingComment ? null : _submitComment,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              shape: BoxShape.circle,
            ),
            child: _isSubmittingComment
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
