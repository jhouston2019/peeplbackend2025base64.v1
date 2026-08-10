import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../models/milestone.dart';
import '../services/feed_service.dart';
import '../theme/peepl_app_tokens.dart';
import '../widgets/recap_share_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _accentBlue = Color(0xFF1565C0);

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  final FeedService _feedService = FeedService();
  final GlobalKey _monthlyShareKey = GlobalKey();
  final GlobalKey _annualShareKey = GlobalKey();

  Map<String, dynamic>? _stats;
  List<String> _earnedMilestones = [];
  int _totalImpact = 0;
  Map<String, dynamic>? _displayRecap;
  String _recapTitle = '';
  String? _pioneerVenueName;
  bool _loading = true;
  String? _error;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _user;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in to view your contributions.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _feedService.getUserStats(user.uid),
        _feedService.getWeeklyRecap(user.uid),
        _feedService.getMonthlyRecap(user.uid),
        FirebaseFirestore.instance
            .collection(FeedService.usersCollection)
            .doc(user.uid)
            .get(),
      ]);

      final stats = results[0] as Map<String, dynamic>;
      final weekly = results[1] as Map<String, dynamic>;
      final monthly = results[2] as Map<String, dynamic>;
      final userSnap = results[3] as DocumentSnapshot<Map<String, dynamic>>;
      final userData = userSnap.data() ?? {};

      final earned = List<String>.from(
        (userData['earnedMilestones'] as List<dynamic>? ?? [])
            .map((e) => e.toString()),
      );
      final totalImpact = (userData['totalImpact'] as num?)?.toInt() ?? 0;

      String? pioneerVenue;
      if (earned.contains(Milestone.pioneer)) {
        pioneerVenue = await _loadPioneerVenue(user.uid);
      }

      final recapPick = _pickRecap(weekly, monthly);

      if (!mounted) return;
      setState(() {
        _stats = stats;
        _earnedMilestones = earned;
        _totalImpact = totalImpact;
        _displayRecap = recapPick.recap;
        _recapTitle = recapPick.title;
        _pioneerVenueName = pioneerVenue;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your contributions. Please try again.';
      });
    }
  }

  Future<String?> _loadPioneerVenue(String userId) async {
    final recentSnap = await FirebaseFirestore.instance
        .collection('location_posts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (recentSnap.docs.isEmpty) return null;
    final locationName =
        recentSnap.docs.first.data()['locationName'] as String? ?? '';
    if (locationName.isEmpty) return null;

    final firstSnap = await FirebaseFirestore.instance
        .collection('location_posts')
        .where('locationName', isEqualTo: locationName)
        .orderBy('timestamp', descending: false)
        .limit(1)
        .get();

    if (firstSnap.docs.isEmpty) return null;
    if (firstSnap.docs.first.data()['userId'] == userId) {
      return locationName;
    }
    return null;
  }

  ({Map<String, dynamic>? recap, String title}) _pickRecap(
    Map<String, dynamic> weekly,
    Map<String, dynamic> monthly,
  ) {
    final now = DateTime.now();
    final useMonthly = now.day > 7;
    final primary = useMonthly ? monthly : weekly;
    final primaryTitle =
        useMonthly ? 'This month on Peepl' : 'This week on Peepl';

    if (_recapHasActivity(primary)) {
      return (recap: primary, title: primaryTitle);
    }

    final fallback = useMonthly ? weekly : monthly;
    final fallbackTitle =
        useMonthly ? 'This week on Peepl' : 'This month on Peepl';
    if (_recapHasActivity(fallback)) {
      return (recap: fallback, title: fallbackTitle);
    }

    return (recap: null, title: '');
  }

  bool _recapHasActivity(Map<String, dynamic> recap) {
    return (recap['peepCount'] as int? ?? 0) > 0 ||
        (recap['placeCount'] as int? ?? 0) > 0 ||
        (recap['impactCount'] as int? ?? 0) > 0;
  }

  String get _displayName {
    final user = _user;
    if (user == null) return 'Peepler';
    return user.displayName ??
        user.email?.split('@').first ??
        'Peepler';
  }

  Color _crowdingColor(int level) {
    if (level <= 4) return const Color(0xFF4CAF50);
    if (level <= 6) return const Color(0xFFFFA726);
    return const Color(0xFFFF5722);
  }

  String _memberSinceLabel(dynamic firstPeepDate) {
    if (firstPeepDate is! Timestamp) return '—';
    final dt = firstPeepDate.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  String _timeAgo(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime? dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else {
      return '';
    }
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _shareRecapCard({required bool annual}) async {
    final key = annual ? _annualShareKey : _monthlyShareKey;
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final file = File(
        '${Directory.systemTemp.path}/peepl_recap_'
        '${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: annual ? 'My year on Peepl' : 'My Peepl recap',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share recap')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final stats = _stats;
    final recap = _displayRecap;
    final monthLabel = 'My ${_monthNames[now.month - 1]} on Peepl';

    return Scaffold(
      backgroundColor: PeeplAppTokens.shellNavy,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: Container(
                    decoration: PeeplAppTokens.shellBodyDecoration(),
                    child: _buildBody(),
                  ),
                ),
              ],
            ),
            if (stats != null && recap != null)
              Positioned(
                left: -5000,
                top: 0,
                child: RepaintBoundary(
                  key: _monthlyShareKey,
                  child: RecapShareCard(
                    periodLabel: _recapTitle == 'This month on Peepl'
                        ? monthLabel
                        : 'My week on Peepl',
                    peepCount: recap['peepCount'] as int? ?? 0,
                    placeCount: recap['placeCount'] as int? ?? 0,
                    peopleHelped: recap['impactCount'] as int? ?? 0,
                    milestoneCount: _earnedMilestones.length,
                    pioneerVenueName: _earnedMilestones.contains(Milestone.pioneer)
                        ? _pioneerVenueName
                        : null,
                  ),
                ),
              ),
            if (stats != null)
              Positioned(
                left: -5000,
                top: 700,
                child: RepaintBoundary(
                  key: _annualShareKey,
                  child: RecapShareCardAnnual(
                    year: now.year,
                    peepCount: stats['totalPeeps'] as int? ?? 0,
                    placeCount: stats['totalPlaces'] as int? ?? 0,
                    peopleHelped: _totalImpact,
                    milestoneCount: _earnedMilestones.length,
                    pioneerVenueName: _earnedMilestones.contains(Milestone.pioneer)
                        ? _pioneerVenueName
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back,
                color: PeeplAppTokens.textPrimary, size: 28),
          ),
          const Text(
            'My Peepl',
            style: TextStyle(
              color: PeeplAppTokens.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/settings'),
            child: const Icon(Icons.settings_outlined,
                color: PeeplAppTokens.textPrimary, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_accentBlue),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: PeeplAppTokens.textSecondary, fontSize: 16),
          ),
        ),
      );
    }

    final stats = _stats!;
    final totalPeeps = stats['totalPeeps'] as int? ?? 0;

    return RefreshIndicator(
      color: _accentBlue,
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _displayName,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _accentBlue,
              ),
            ),
            const SizedBox(height: 24),
            if (totalPeeps == 0)
              _buildEmptyPrompt()
            else ...[
              if (_displayRecap != null) ...[
                _buildRecapCard(_displayRecap!, _recapTitle),
                const SizedBox(height: 16),
              ],
              _buildStatsGrid(stats),
              if (_totalImpact > 0) ...[
                const SizedBox(height: 12),
                _buildImpactTile(_totalImpact),
              ],
              const SizedBox(height: 28),
              _buildRecentPeepsSection(stats),
              if (_earnedMilestones.isNotEmpty) ...[
                const SizedBox(height: 28),
                _buildMilestonesSection(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecapCard(Map<String, dynamic> recap, String title) {
    final peeps = recap['peepCount'] as int? ?? 0;
    final places = recap['placeCount'] as int? ?? 0;
    final helped = recap['impactCount'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: PeeplAppTokens.textPrimary,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: _accentBlue, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: PeeplAppTokens.textPrimary.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$peeps Peeps · $places places · $helped people helped',
            style: TextStyle(
              fontSize: 14,
              color: PeeplAppTokens.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _shareRecapCard(annual: false),
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accentBlue,
              side: const BorderSide(color: _accentBlue),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _shareRecapCard(annual: true),
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: const Text('Share My Year'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accentBlue,
              side: const BorderSide(color: _accentBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactTile(int totalImpact) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: _accentBlue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _accentBlue.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        'Your Peeps have helped $totalImpact people',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildEmptyPrompt() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: PeeplAppTokens.textPrimary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: PeeplAppTokens.textPrimary.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Text(
        "You haven't Peeped anywhere yet.\nYour contributions will appear here.",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          height: 1.5,
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    final totalPeeps = stats['totalPeeps'] as int? ?? 0;
    final totalPlaces = stats['totalPlaces'] as int? ?? 0;
    final totalLikes = stats['totalLikes'] as int? ?? 0;
    final memberSince = _memberSinceLabel(stats['firstPeepDate']);

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _statTile('$totalPeeps Peeps')),
            const SizedBox(width: 12),
            Expanded(child: _statTile('$totalPlaces Places')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statTile('$totalLikes Likes')),
            const SizedBox(width: 12),
            Expanded(child: _statTile('Member since $memberSince')),
          ],
        ),
      ],
    );
  }

  Widget _statTile(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      decoration: BoxDecoration(
        color: PeeplAppTokens.textPrimary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: PeeplAppTokens.textPrimary.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _accentBlue,
        ),
      ),
    );
  }

  Widget _buildRecentPeepsSection(Map<String, dynamic> stats) {
    final recentPeeps =
        (stats['recentPeeps'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Peeps',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        ...recentPeeps.map(_buildRecentPeepCard),
      ],
    );
  }

  Widget _buildRecentPeepCard(Map<String, dynamic> peep) {
    final locationName = peep['locationName'] as String? ?? 'Unknown';
    final crowdingLevel = (peep['crowdingLevel'] as num?)?.toInt() ?? 0;
    final timeLabel = _timeAgo(peep['timestamp']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: PeeplAppTokens.textPrimary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: PeeplAppTokens.textPrimary.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locationName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1A1A1A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (timeLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: PeeplAppTokens.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _crowdingColor(crowdingLevel),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                crowdingLevel.toString(),
                style: const TextStyle(
                  color: PeeplAppTokens.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonesSection() {
    final rows = _earnedMilestones
        .map(Milestone.textFor)
        .whereType<String>()
        .toList();

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Milestones',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        ...rows.map(
          (text) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: PeeplAppTokens.textPrimary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentBlue.withOpacity(0.25)),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
