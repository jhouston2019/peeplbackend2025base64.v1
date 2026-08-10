import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/milestone.dart';
import '../services/feed_service.dart';
import '../theme/peepl_app_tokens.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _accentBlue = Color(0xFF1565C0);

  final FeedService _feedService = FeedService();

  Map<String, dynamic>? _stats;
  List<String> _earnedMilestones = [];
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
      final stats = await _feedService.getUserStats(user.uid);
      final userSnap = await FirebaseFirestore.instance
          .collection(FeedService.usersCollection)
          .doc(user.uid)
          .get();
      final earned = List<String>.from(
        (userSnap.data()?['earnedMilestones'] as List<dynamic>? ?? [])
            .map((e) => e.toString()),
      );

      if (!mounted) return;
      setState(() {
        _stats = stats;
        _earnedMilestones = earned;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplAppTokens.shellNavy,
      body: SafeArea(
        child: Column(
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
              _buildStatsGrid(stats),
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
