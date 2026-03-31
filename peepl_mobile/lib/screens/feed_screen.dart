import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/feed_service.dart';
import '../services/native_ads_service.dart';
import 'location_detail_screen.dart';
import 'post_screen.dart';

class FeedScreen extends StatefulWidget {
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FeedService _feedService = FeedService();
  final NativeAdsService _adsService = NativeAdsService();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _feedItems = [];
  List<Map<String, dynamic>> _availableAds = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFeedData();
    _loadAds();
  }

  Future<void> _loadFeedData() async {
    try {
      setState(() { _isLoading = true; _hasError = false; });
      _feedService.getLocationFeedStream().listen(
        (snapshot) { _processFeedData(snapshot.docs); },
        onError: (error) {
          setState(() { _hasError = true; _errorMessage = 'Failed to load feed: $error'; _isLoading = false; });
        },
      );
    } catch (e) {
      setState(() { _hasError = true; _errorMessage = 'Failed to load feed: $e'; _isLoading = false; });
    }
  }

  Future<void> _loadAds() async {
    try {
      final ads = await _adsService.getAdsForFeed(limit: 10);
      setState(() { _availableAds = ads; });
    } catch (e) { print('Failed to load ads: $e'); }
  }

  void _processFeedData(List<QueryDocumentSnapshot> postDocs) {
    final posts = postDocs.map((doc) => {'id': doc.id, 'type': 'post', ...doc.data() as Map<String, dynamic>}).toList();
    final feedItems = <Map<String, dynamic>>[];
    int adIndex = 0;
    for (int i = 0; i < posts.length; i++) {
      feedItems.add(posts[i]);
      if ((i + 1) % 2 == 0 && adIndex < _availableAds.length) {
        feedItems.add({'type': 'ad', ..._availableAds[adIndex]});
        adIndex++;
      }
    }
    setState(() { _feedItems = feedItems; _isLoading = false; });
  }

  Color _getCrowdingColor(int level) {
    if (level <= 4) return Color(0xFF4CAF50);
    if (level <= 6) return Color(0xFFFFA726);
    return Color(0xFFFF5722);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(child: _buildFeedContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(builder: (_) => const PostScreen()),
            ),
            child: Column(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.add, color: Colors.white)),
              SizedBox(height: 4),
              Text('POST', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          Text('Peepl', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/settings'),
            child: Column(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.help_outline, color: Colors.white)),
              SizedBox(height: 4),
              Text("WHAT'S\nCROWDED?", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, height: 1.1), textAlign: TextAlign.center),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedContent() {
    if (_isLoading) return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)));
    if (_hasError) return Center(child: Text(_errorMessage ?? 'Something went wrong', style: TextStyle(color: Colors.white)));
    if (_feedItems.isEmpty) return Center(child: Text('No posts yet!', style: TextStyle(color: Colors.white, fontSize: 18)));

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: _feedItems.length,
      itemBuilder: (context, index) {
        final item = _feedItems[index];
        return item['type'] == 'ad' ? _buildAdCard() : _buildLocationCard(item);
      },
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> post) {
    final crowdingLevel = post['crowdingLevel'] ?? 0;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LocationDetailScreen(postData: post))),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(image: NetworkImage(post['imageUrl'] ?? 'https://via.placeholder.com/400x120'), fit: BoxFit.cover),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight,
              colors: [Colors.black.withOpacity(0.6), Colors.transparent]),
          ),
          child: Stack(children: [
            Positioned(left: 20, bottom: 20, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post['locationName'] ?? 'Unknown', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              Text(post['username'] ?? 'Unknown', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16)),
            ])),
            Positioned(right: 16, top: 16, child: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: _getCrowdingColor(crowdingLevel), shape: BoxShape.circle),
              child: Center(child: Text(crowdingLevel.toString(), style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildAdCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      height: 80,
      decoration: BoxDecoration(color: Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(16)),
      child: Center(child: Text('ADVERTISEMENT', style: TextStyle(color: Color(0xFF1976D2), fontSize: 18, fontWeight: FontWeight.bold))),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}