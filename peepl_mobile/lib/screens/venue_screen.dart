import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/crowdsource_service.dart';
import '../widgets/crowd_meter.dart';
import 'location_detail_screen.dart';

const _kUsersCollection = 'CAASNAhaDbPrl0zH1yDn5qRqAtJ3';

class VenueScreen extends StatefulWidget {
  final String? locationName;

  const VenueScreen({super.key, this.locationName});

  @override
  State<VenueScreen> createState() => _VenueScreenState();
}

class _VenueScreenState extends State<VenueScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _venueName = '';
  bool _didInit = false;
  bool _isFavorite = false;

  double? _latitude;
  double? _longitude;
  String? _latestPostId;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    _venueName = _resolveLocationName();
    if (_venueName.isNotEmpty) _checkFavorite();
  }

  String _resolveLocationName() {
    if (widget.locationName != null && widget.locationName!.isNotEmpty) {
      return widget.locationName!;
    }
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) return args;
    if (args is Map<String, dynamic>) {
      return args['locationName'] as String? ??
          args['venueName'] as String? ??
          args['name'] as String? ??
          '';
    }
    return '';
  }

  Future<void> _checkFavorite() async {
    if (_uid.isEmpty || _venueName.isEmpty) return;
    try {
      final doc = await _db
          .collection(_kUsersCollection)
          .doc(_uid)
          .collection('favorites')
          .doc(_venueName)
          .get();
      if (mounted) setState(() => _isFavorite = doc.exists);
    } catch (e) {
      debugPrint('VenueScreen favorite check: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save favorites')),
      );
      return;
    }
    final ref = _db
        .collection(_kUsersCollection)
        .doc(_uid)
        .collection('favorites')
        .doc(_venueName);

    try {
      if (_isFavorite) {
        await ref.delete();
        if (mounted) setState(() => _isFavorite = false);
      } else {
        await ref.set({
          'locationName': _venueName,
          'savedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) setState(() => _isFavorite = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update favorite: $e')),
        );
      }
    }
  }

  Future<void> _shareVenue(int currentCrowd) async {
    final crowdingWord = CrowdMeter.wordLabel(currentCrowd);
    await Share.share(
      'Check out $_venueName on Peepl — currently $crowdingWord! '
      'https://peepl.app',
    );
  }

  Future<void> _sendAskRequest() async {
    if (_venueName.isEmpty) return;
    try {
      final requestId = await CrowdsourceService.instance.createRequest(
        locationId: _latestPostId ?? _venueName,
        locationName: _venueName,
        latitude: _latitude ?? 0.0,
        longitude: _longitude ?? 0.0,
      );
      if (mounted && requestId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Asked everyone at $_venueName to report crowd levels!',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFF1565C0),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send request. Try again.')),
        );
      }
    }
  }

  void _openPostScreen() {
    Navigator.pushNamed(
      context,
      '/post',
      arguments: {'locationName': _venueName},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_venueName.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Venue'),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('No venue specified')),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('location_posts')
          .where('locationName', isEqualTo: _venueName)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildShell(
            currentCrowd: 0,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load venue: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final posts = docs.map((d) {
          return {'id': d.id, ...d.data() as Map<String, dynamic>};
        }).toList();

        if (posts.isNotEmpty) {
          final latest = posts.first;
          _latitude = (latest['latitude'] as num?)?.toDouble();
          _longitude = (latest['longitude'] as num?)?.toDouble();
          _latestPostId = latest['id'] as String?;
        }

        final stats = _computeStats(posts);
        final heroImageUrl = _heroImageUrl(posts);
        final recentPosts = posts.take(10).toList();
        final chartSpots = _chartSpots(posts);

        return _buildShell(
          currentCrowd: stats.currentCrowd,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHero(heroImageUrl)),
              SliverToBoxAdapter(child: _buildStatCards(stats)),
              SliverToBoxAdapter(child: _buildCrowdHistory(chartSpots)),
              SliverToBoxAdapter(child: _buildRecentPostsHeader()),
              if (recentPosts.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No posts yet — be the first to Peep here!',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildRecentPostCard(recentPosts[index]),
                    childCount: recentPosts.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShell({
    required Widget body,
    required int currentCrowd,
  }) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: _isFavorite ? 'Remove favorite' : 'Save favorite',
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.amber : Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share),
            onPressed: () => _shareVenue(currentCrowd),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildHero(String? imageUrl) {
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: const Color(0xFF1565C0)),
            )
          else
            Container(color: const Color(0xFF1565C0)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF2244EE).withValues(alpha: 0.55),
                  const Color(0xFF1565C0).withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Text(
              _venueName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 6,
                    color: Colors.black54,
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(_VenueStats stats) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Current Crowd',
              child: CrowdMeter(level: stats.currentCrowd, size: 44),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: 'Total Posts',
              child: Text(
                '${stats.totalPosts}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: 'Avg Crowd',
              child: Text(
                stats.totalPosts > 0
                    ? stats.averageCrowd.toStringAsFixed(1)
                    : '—',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: 'Peak Hour',
              child: Text(
                stats.peakHourLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrowdHistory(List<FlSpot> spots) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Crowd History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1565C0),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last 7 days',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: spots.isEmpty
                ? Center(
                    child: Text(
                      'No crowd data yet',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 10,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 2,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withValues(alpha: 0.2),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 2,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final labels = _dayLabels();
                              final i = value.toInt();
                              if (i < 0 || i >= labels.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  labels[i],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: const Color(0xFF1565C0),
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) =>
                                FlDotCirclePainter(
                              radius: 4,
                              color: const Color(0xFF1565C0),
                              strokeWidth: 1,
                              strokeColor: Colors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF1565C0)
                                .withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPostsHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        'Recent Posts',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1565C0),
        ),
      ),
    );
  }

  Widget _buildRecentPostCard(Map<String, dynamic> post) {
    final crowdLevel = (post['crowdingLevel'] as num?)?.toInt() ?? 0;
    return InkWell(
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => LocationDetailScreen(postData: post),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post['username'] as String? ?? 'Anonymous',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _relativeTime(post['timestamp']),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            CrowdMeter(level: crowdLevel, size: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openPostScreen,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text(
                  'Post Here',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2244EE),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _sendAskRequest,
                icon: const Icon(Icons.campaign_outlined),
                label: const Text(
                  'Ask Here Now',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0),
                  side: const BorderSide(color: Color(0xFF1565C0)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _heroImageUrl(List<Map<String, dynamic>> posts) {
    for (final post in posts) {
      final url = post['imageUrl'] as String?;
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  _VenueStats _computeStats(List<Map<String, dynamic>> posts) {
    if (posts.isEmpty) {
      return const _VenueStats(
        currentCrowd: 0,
        totalPosts: 0,
        averageCrowd: 0,
        peakHourLabel: '—',
      );
    }

    final currentCrowd = (posts.first['crowdingLevel'] as num?)?.toInt() ?? 0;
    final totalPosts = posts.length;

    var sum = 0.0;
    var count = 0;
    final hourCounts = List<int>.filled(24, 0);

    for (final post in posts) {
      final level = post['crowdingLevel'];
      if (level is num) {
        sum += level.toDouble();
        count++;
      }
      final ts = post['timestamp'];
      if (ts is Timestamp) {
        hourCounts[ts.toDate().hour]++;
      }
    }

    var peakHour = 0;
    var peakCount = 0;
    for (var h = 0; h < 24; h++) {
      if (hourCounts[h] > peakCount) {
        peakCount = hourCounts[h];
        peakHour = h;
      }
    }

    return _VenueStats(
      currentCrowd: currentCrowd,
      totalPosts: totalPosts,
      averageCrowd: count > 0 ? sum / count : 0,
      peakHourLabel: peakCount > 0 ? _formatHour(peakHour) : '—',
    );
  }

  List<FlSpot> _chartSpots(List<Map<String, dynamic>> posts) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));

    final buckets = List<List<double>>.generate(7, (_) => []);

    for (final post in posts) {
      final ts = post['timestamp'];
      final level = post['crowdingLevel'];
      if (ts is! Timestamp || level is! num) continue;

      final date = ts.toDate();
      if (date.isBefore(start)) continue;

      final dayIndex = DateTime(date.year, date.month, date.day)
          .difference(start)
          .inDays;
      if (dayIndex >= 0 && dayIndex < 7) {
        buckets[dayIndex].add(level.toDouble());
      }
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < 7; i++) {
      if (buckets[i].isEmpty) continue;
      final avg = buckets[i].reduce((a, b) => a + b) / buckets[i].length;
      spots.add(FlSpot(i.toDouble(), avg));
    }
    return spots;
  }

  List<String> _dayLabels() {
    final now = DateTime.now();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return weekdays[day.weekday - 1];
    });
  }

  static String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  static String _relativeTime(dynamic ts) {
    if (ts is! Timestamp) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _VenueStats {
  final int currentCrowd;
  final int totalPosts;
  final double averageCrowd;
  final String peakHourLabel;

  const _VenueStats({
    required this.currentCrowd,
    required this.totalPosts,
    required this.averageCrowd,
    required this.peakHourLabel,
  });
}

class _StatCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _StatCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
