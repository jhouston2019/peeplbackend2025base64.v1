import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/feed_service.dart';
import '../utils/post_crowd_format.dart';

class LocationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> postData;

  const LocationDetailScreen({Key? key, required this.postData})
      : super(key: key);

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  final FeedService _feedService = FeedService();
  final TextEditingController _commentController = TextEditingController();
  bool _isLiked = false;
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
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
    final postId = widget.postData['id'] as String?;
    if (postId == null) return;
    try {
      if (_isLiked) {
        await _feedService.unlikeLocationPost(postId, user.uid);
      } else {
        await _feedService.likeLocationPost(postId, user.uid);
      }
      setState(() => _isLiked = !_isLiked);
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
            _buildImageHeader(post, crowdingLevel),
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

  Widget _buildImageHeader(Map<String, dynamic> post, int crowdingLevel) {
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
          top: 16,
          right: 16,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _getCrowdingColor(crowdingLevel),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                crowdingLevel.toString(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
              ),
            ),
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
          Row(
            children: [
              GestureDetector(
                onTap: _toggleLike,
                child: Row(
                  children: [
                    Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : Colors.grey,
                      size: 24,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post['likesCount'] ?? 0}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
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

  Widget _buildCommentsStream(String postId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('location_posts')
          .doc(postId)
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Text('No comments yet. Be the first!',
              style: TextStyle(color: Colors.grey[500]));
        }
        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
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
