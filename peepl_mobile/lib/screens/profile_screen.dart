import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_share_links.dart';
import '../services/auth_service.dart';
import 'location_detail_screen.dart';

// ── VIPeeps helpers (used inline in ProfileScreen) ────────────────────────────

String _vipRenewsLabel(dynamic renewsAt) {
  if (renewsAt is! Timestamp) return 'Active';
  final dt = renewsAt.toDate();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return 'Renews ${months[dt.month - 1]} ${dt.day}';
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? get _user => FirebaseAuth.instance.currentUser;

  Color _getCrowdingColor(int level) {
    if (level <= 4) return const Color(0xFF4CAF50);
    if (level <= 6) return const Color(0xFFFFA726);
    return const Color(0xFFFF5722);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildProfileHeader(context),
                      _buildVIPeepsSection(context),
                      const Divider(height: 1),
                      _buildPostsSection(context),
                    ],
                  ),
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
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          ),
          const Text(
            'Profile',
            style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/settings'),
            child: const Icon(Icons.settings_outlined,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final username =
        _user?.displayName ?? _user?.email?.split('@').first ?? 'Peepler';
    final email = _user?.email ?? '';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: const Color(0xFF1565C0),
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : 'P',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            username,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0)),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              email,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
          const SizedBox(height: 20),
          _buildPostsCount(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/account_info'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1565C0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Edit Profile',
                    style: TextStyle(
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await AuthService().signOut();
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/login', (_) => false);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/vip_peeps'),
              icon: const Icon(Icons.star_outline, color: Color(0xFF1565C0)),
              label: const Text(
                'Go VIPeeps',
                style: TextStyle(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1565C0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/invite'),
              icon: const Icon(Icons.person_add_outlined,
                  color: Color(0xFF1565C0)),
              label: const Text(
                'Invite Friends',
                style: TextStyle(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1565C0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _shareThisApp(context),
              icon: const Icon(Icons.share_outlined, color: Color(0xFF1565C0)),
              label: const Text(
                'Share this app',
                style: TextStyle(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1565C0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareThisApp(BuildContext context) async {
    const msg =
        "I'm using Peepl to see crowd levels before I go anywhere. Check it out: $kPeeplAppStoreLinkPlaceholder";
    try {
      await Share.share(msg);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share: $e')),
        );
      }
    }
  }

  Widget _buildPostsCount() {
    if (_user == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('location_posts')
          .where('userId', isEqualTo: _user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Column(
          children: [
            Text(
              count.toString(),
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0)),
            ),
            Text(
              count == 1 ? 'Post' : 'Posts',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPostsSection(BuildContext context) {
    if (_user == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Sign in to see your posts',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/my_peeps'),
              icon: const Icon(Icons.article_outlined),
              label: const Text(
                'My Posts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('location_posts')
              .where('userId', isEqualTo: _user!.uid)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: TextButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Failed to load posts — tap to retry'),
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF1565C0)),
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.add_location_alt_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('No posts yet',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(
                        'Share how crowded places are!',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = {
                  'id': docs[index].id,
                  ...docs[index].data() as Map<String, dynamic>
                };
                return _buildPostCard(context, data);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPostCard(
      BuildContext context, Map<String, dynamic> post) {
    final crowdingLevel = (post['crowdingLevel'] as num?)?.toInt() ?? 0;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => LocationDetailScreen(postData: post)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16)),
              child: post['imageUrl'] != null &&
                      (post['imageUrl'] as String).isNotEmpty
                  ? Image.network(
                      post['imageUrl'] as String,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post['locationName'] ?? 'Unknown',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (post['description'] != null &&
                        (post['description'] as String).isNotEmpty)
                      Text(
                        post['description'] as String,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.favorite,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${post['likesCount'] ?? 0}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        const SizedBox(width: 12),
                        const Icon(Icons.comment,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${post['commentsCount'] ?? 0}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getCrowdingColor(crowdingLevel),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    crowdingLevel.toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[200],
      child: Icon(Icons.image, color: Colors.grey[400], size: 28),
    );
  }

  // ── VIPeeps section ────────────────────────────────────────────────────────

  Widget _buildVIPeepsSection(BuildContext context) {
    final uid = _user?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        final data =
            snap.data?.data() as Map<String, dynamic>? ?? {};
        final isVIP = data['isVIPeep'] as bool? ?? false;

        return isVIP
            ? _buildVIPActiveBanner(
                context, data['vipeepsRenewsAt'])
            : _buildVIPUpgradeRow(context);
      },
    );
  }

  Widget _buildVIPActiveBanner(
      BuildContext context, dynamic renewsAt) {
    final label = _vipRenewsLabel(renewsAt);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AC0D), Color(0xFFFFD700)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('⭐', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'VIPeeps Active',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          GestureDetector(
            onTap: () =>
                Navigator.pushNamed(context, '/vip_peeps'),
            child: Text(
              '$label · Manage',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVIPUpgradeRow(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/vip_peeps'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          children: [
            const Text('⭐', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Upgrade to VIPeeps ⭐',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF1A1200),
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0xFFD4AC0D), size: 20),
          ],
        ),
      ),
    );
  }
}
