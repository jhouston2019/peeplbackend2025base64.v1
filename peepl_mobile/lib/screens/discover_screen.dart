import 'package:flutter/material.dart';
import '../services/feed_service.dart';
import 'location_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final FeedService _feedService = FeedService();
  List<Map<String, dynamic>> _feedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _feedService.getLocationFeedStream().listen((snapshot) {
      final posts = snapshot.docs.map((doc) => {
            'id': doc.id,
            'type': 'post',
            ...doc.data() as Map<String, dynamic>,
          }).toList();
      if (mounted) setState(() { _feedItems = posts; _isLoading = false; });
    });
  }

  Color _getCrowdingColor(int level) {
    if (level <= 4) return const Color(0xFF4CAF50);
    if (level <= 6) return const Color(0xFFFFA726);
    return const Color(0xFFFF5722);
  }

  Widget _buildLocationCard(Map<String, dynamic> post) {
    final crowdingLevel = (post['crowdingLevel'] ?? 0) as int;
    final locationName = post['locationName'] as String? ?? 'Unknown Location';
    final username = post['username'] as String? ?? 'Unknown User';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => LocationDetailScreen(postData: post),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: NetworkImage(
              post['imageUrl'] as String? ?? 'https://via.placeholder.com/400x120',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withValues(alpha: 0.6),
                Colors.transparent,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 10,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locationName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      username,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getCrowdingColor(crowdingLevel),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      crowdingLevel.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const Row(
                children: [
                  Icon(Icons.explore, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Discover',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : _feedItems.isEmpty
                      ? const Center(
                          child: Text(
                            'No posts yet',
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _feedItems.length,
                          itemBuilder: (context, index) =>
                              _buildLocationCard(_feedItems[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
