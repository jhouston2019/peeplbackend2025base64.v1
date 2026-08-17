import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/peepl_app_tokens.dart';

import '../services/feed_service.dart';
import '../services/share_service.dart';
import '../services/venue_name_service.dart';
import '../utils/post_crowd_format.dart';
import '../utils/post_delete_actions.dart';
import '../widgets/crowd_meter.dart';
import '../widgets/detail/post_location_map_preview.dart';

class PeepDetailScreen extends StatefulWidget {
  const PeepDetailScreen({super.key, this.postData});

  final Map<String, dynamic>? postData;

  @override
  State<PeepDetailScreen> createState() => _PeepDetailScreenState();
}

class _PeepDetailScreenState extends State<PeepDetailScreen> {
  final _feedService = FeedService();
  final _commentController = TextEditingController();

  Map<String, dynamic>? _post;
  bool _didInit = false;
  bool _isLiked = false;
  bool _submittingComment = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  String _displayVenueName = 'Unknown';

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      _post = widget.postData ??
          (args is Map<String, dynamic> ? args : null);
      _likesCount = (_post?['likesCount'] as num?)?.toInt() ?? 0;
      _commentsCount = (_post?['commentsCount'] as num?)?.toInt() ?? 0;
      if (_post != null) {
        _displayVenueName = VenueNameService.storedVenueName(_post!) ??
            VenueNameService.addressFallback(_post!) ??
            'Unknown';
        _resolveDisplayVenueName();
      }
      _checkIfLiked();
    }
  }

  Future<void> _resolveDisplayVenueName() async {
    final post = _post;
    if (post == null) return;
    final resolved = await VenueNameService.displayNameForPost(post);
    if (mounted && resolved != _displayVenueName) {
      setState(() => _displayVenueName = resolved);
    }
  }

  Future<void> _checkIfLiked() async {
    final user = FirebaseAuth.instance.currentUser;
    final postId = _post?['id'] as String?;
    if (user == null || postId == null) return;
    final liked = await _feedService.isLocationPostLiked(postId, user.uid);
    if (mounted) setState(() => _isLiked = liked);
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    final postId = _post?['id'] as String?;
    if (user == null || postId == null) return;

    try {
      if (_isLiked) {
        await _feedService.unlikeLocationPost(postId, user.uid);
        if (!mounted) return;
        setState(() {
          _isLiked = false;
          _likesCount--;
        });
      } else {
        await _feedService.likeLocationPost(postId, user.uid);
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

  Future<void> _sharePost() async {
    final post = _post;
    final user = FirebaseAuth.instance.currentUser;
    if (post == null || user == null) return;

    final postId = post['id'] as String?;
    if (postId == null || postId.isEmpty) return;

    final name = _displayVenueName.trim().isNotEmpty == true
        ? _displayVenueName.trim()
        : 'this spot';
    final level = (post['crowdingLevel'] as num?)?.toInt() ?? 0;

    try {
      await ShareService.instance.sharePeep(
        peepId: postId,
        locationName: name,
        crowdingLevel: level,
        sharingUserId: user.uid,
        shareContext: 'detail_view',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share: $e')),
        );
      }
    }
  }

  Future<void> _deleteOwnPost(String postId, String locationName) async {
    final deleted = await confirmAndDeletePost(
      context,
      _feedService,
      postId: postId,
      locationName: locationName,
    );
    if (deleted && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _submitComment() async {
    final user = FirebaseAuth.instance.currentUser;
    final postId = _post?['id'] as String?;
    final text = _commentController.text.trim();
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to comment.')),
        );
      }
      return;
    }
    if (postId == null || text.isEmpty) return;

    setState(() => _submittingComment = true);
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
          .doc(postId)
          .update({'commentsCount': FieldValue.increment(1)});
      _commentController.clear();
      if (mounted) setState(() => _commentsCount++);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingComment = false);
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

  static bool _hasValidCoords(Map<String, dynamic> post) =>
      PostLocationMapPreview.hasValidCoords(post);

  static String? _fieldOrDescription(
    Map<String, dynamic> post,
    String key,
    String label,
  ) {
    final direct = post[key]?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final desc = post['description']?.toString() ?? '';
    final match = RegExp('$label:\\s*([^·]+)').firstMatch(desc);
    return match?.group(1)?.trim();
  }

  List<String> _criteriaChips(Map<String, dynamic> post) {
    final chips = <String>[];
    void add(String label, String? value) {
      if (value != null && value.isNotEmpty) chips.add('$label: $value');
    }

    add('Venue', post['venueType']?.toString().trim());
    add('Parking', _fieldOrDescription(post, 'parking', 'Parking'));
    add('Queue', _fieldOrDescription(post, 'queueTime', 'Queue'));
    add('Safety', _fieldOrDescription(post, 'safetyFeel', 'Safety'));
    add('Weather', _fieldOrDescription(post, 'weather', 'Weather'));

    final mf = PostCrowdFormat.maleFemaleLine(post['maleFemaleRatio']);
    if (mf != null) add('Male/Female', mf);
    final ak = PostCrowdFormat.adultKidLine(post['adultKidRatio']);
    if (ak != null) add('Adult/Kid', ak);

    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    if (post == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: PeeplAppTokens.shellNavy,
          foregroundColor: PeeplAppTokens.textPrimary,
          title: const Text('Post'),
        ),
        body: const Center(child: Text('Post not found')),
      );
    }

    final locationName = _displayVenueName;
    final username = post['username'] as String? ?? 'Anonymous';
    final userId = post['userId'] as String? ?? '';
    final crowdLevel = (post['crowdingLevel'] as num?)?.toInt() ?? 0;
    final imageUrl = post['imageUrl'] as String? ?? '';
    final description = post['description'] as String? ?? '';
    final postId = post['id'] as String?;
    final timeStr = _relativeTime(post['timestamp']);
    final chips = _criteriaChips(post);
    final crowdLabel = CrowdMeter.wordLabel(crowdLevel);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = FeedService.isPostOwner(post, currentUser?.uid);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHero(post, locationName, imageUrl)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Column(
                      children: [
                        CrowdMeter(level: crowdLevel, size: 100),
                        const SizedBox(height: 8),
                        Text(
                          crowdLabel,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: CrowdMeter.levelColor(crowdLevel),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _sectionCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: PeeplAppTokens.shellNavy,
                          child: Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: PeeplAppTokens.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: userId.isNotEmpty
                                    ? () => Navigator.pushNamed(
                                          context,
                                          '/user_profile',
                                          arguments: userId,
                                        )
                                    : null,
                                child: Text(
                                  username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: PeeplAppTokens.accentBlue,
                                  ),
                                ),
                              ),
                              if (timeStr.isNotEmpty)
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: PeeplAppTokens.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (chips.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: PeeplAppTokens.accentBlue,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: chips
                                .map(
                                  (c) => Chip(
                                    label: Text(c),
                                    backgroundColor: PeeplAppTokens.shellNavy
                                        .withValues(alpha: 0.08),
                                    side: BorderSide(
                                      color: PeeplAppTokens.accentBlue
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (description.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: PeeplAppTokens.accentBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: PeeplAppTokens.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _sectionCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: _toggleLike,
                          icon: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            color: _isLiked ? Colors.red : Colors.grey[700],
                          ),
                          label: Text('$_likesCount'),
                        ),
                        TextButton.icon(
                          onPressed: _sharePost,
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Share'),
                        ),
                        TextButton.icon(
                          onPressed: isOwner && postId != null
                              ? () => _deleteOwnPost(postId, locationName)
                              : postId != null
                                  ? () => Navigator.pushNamed(
                                        context,
                                        '/report',
                                        arguments: postId,
                                      )
                                  : null,
                          icon: Icon(
                            isOwner
                                ? Icons.delete_outline
                                : Icons.flag_outlined,
                          ),
                          label: Text(isOwner ? 'Delete' : 'Report'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_hasValidCoords(post))
                  SliverToBoxAdapter(
                    child: _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Location',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: PeeplAppTokens.accentBlue,
                            ),
                          ),
                          const SizedBox(height: 10),
                          PostLocationMapPreview(
                            latitude: (post['latitude'] as num).toDouble(),
                            longitude: (post['longitude'] as num).toDouble(),
                            locationName: locationName,
                            height: 140,
                            fullWidth: true,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap to open in Maps',
                            style: TextStyle(
                              fontSize: 12,
                              color: PeeplAppTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/post',
                          arguments: {
                            'locationName': locationName,
                            'latitude': post['latitude'],
                            'longitude': post['longitude'],
                          },
                        ),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Post Here Too'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PeeplAppTokens.shellNavy,
                          foregroundColor: PeeplAppTokens.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'Comments · $_commentsCount',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: PeeplAppTokens.accentBlue,
                      ),
                    ),
                  ),
                ),
                if (postId != null)
                  SliverToBoxAdapter(child: _buildComments(postId))
                else
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Comments unavailable'),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildHero(
    Map<String, dynamic> post,
    String locationName,
    String imageUrl,
  ) {
    return Stack(
      children: [
        SizedBox(
          height: 260,
          width: double.infinity,
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      ColoredBox(color: PeeplAppTokens.cardElevated!),
                )
              : ColoredBox(color: PeeplAppTokens.cardElevated!),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 8,
          child: CircleAvatar(
            backgroundColor: Colors.black.withValues(alpha: 0.45),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: PeeplAppTokens.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.75),
                  Colors.transparent,
                ],
              ),
            ),
            child: Text(
              locationName,
              style: const TextStyle(
                color: PeeplAppTokens.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(blurRadius: 8, color: PeeplAppTokens.textMuted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PeeplAppTokens.textPrimary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: PeeplAppTokens.textPrimary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildComments(String postId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('location_posts')
          .doc(postId)
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              FirebaseAuth.instance.currentUser == null
                  ? 'Sign in to view comments'
                  : 'Could not load comments',
              style: TextStyle(color: PeeplAppTokens.textSecondary),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (_commentsCount != docs.length && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _commentsCount = docs.length);
          });
        }
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No comments yet. Be the first!',
              style: TextStyle(color: PeeplAppTokens.textSecondary),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final commentUser = data['username'] as String? ?? 'Anonymous';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: PeeplAppTokens.shellNavy,
                      child: Text(
                        commentUser.isNotEmpty
                            ? commentUser[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: PeeplAppTokens.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            commentUser,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            data['text'] as String? ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: PeeplAppTokens.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildCommentInput() {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitComment(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _submittingComment ? null : _submitComment,
                icon: _submittingComment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PeeplAppTokens.textPrimary,
                        ),
                      )
                    : const Icon(Icons.send),
                style: IconButton.styleFrom(
                  backgroundColor: PeeplAppTokens.shellNavy,
                  foregroundColor: PeeplAppTokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
