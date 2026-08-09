import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/peepl_app_tokens.dart';

import '../services/auth_service.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _displayName =>
      FirebaseAuth.instance.currentUser?.displayName ??
      FirebaseAuth.instance.currentUser?.email?.split('@').first ??
      'You';

  // ── Palette ───────────────────────────────────────────────────────────────

  static const List<List<Color>> _palettes = [
    [PeeplAppTokens.shellNavy, PeeplAppTokens.accentBlue],
    [Color(0xFF1B5E20), Color(0xFF388E3C)],
    [Color(0xFF4A148C), Color(0xFF7B1FA2)],
    [Color(0xFF004D40), Color(0xFF00796B)],
    [Color(0xFF7F0000), Color(0xFFC62828)],
    [Color(0xFF263238), Color(0xFF455A64)],
  ];

  List<Color> _paletteFor(String name) {
    final idx = name.isNotEmpty ? name.codeUnitAt(0) % _palettes.length : 0;
    return _palettes[idx];
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> _signOut(BuildContext context) async {
    await AuthService().signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplAppTokens.shellNavy,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(context),
            GestureDetector(
              onTap: () => Navigator.pushNamed(
                  context, '/user_profile', arguments: _uid),
              child: _buildBanner(),
            ),
            Expanded(
              child: Container(
                decoration: PeeplAppTokens.shellBodyDecoration(),
                clipBehavior: Clip.antiAlias,
                child: _buildNavList(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: PeeplAppTokens.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Menu',
            style: TextStyle(
              color: PeeplAppTokens.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    final name = _displayName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final colors = _paletteFor(name);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: PeeplAppTokens.background.withValues(alpha: 0.25),
              child: Text(
                initial,
                style: const TextStyle(
                  color: PeeplAppTokens.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: PeeplAppTokens.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'View profile →',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavList(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _NavRow(
          icon: Icons.radar_outlined,
          label: 'Get Peeps',
          onTap: () => Navigator.pushNamed(context, '/get_peeps'),
        ),
        const _Divider(),
        _NavRow(
          icon: Icons.balance_outlined,
          label: 'Where Should We Go?',
          onTap: () => Navigator.pushNamed(context, '/where_should_we_go'),
        ),
        const _Divider(),
        _NavRow(
          icon: Icons.whatshot_outlined,
          label: 'Trending',
          onTap: () => Navigator.pushNamed(context, '/trending'),
        ),
        const _Divider(),
        _NavRow(
          icon: Icons.emoji_events_outlined,
          label: 'Pioneers',
          onTap: () => Navigator.pushNamed(context, '/pioneers'),
        ),
        const _Divider(),
        _NavRow(
          icon: Icons.photo_library_outlined,
          label: 'Gallery',
          onTap: () => Navigator.pushNamed(context, '/gallery'),
        ),
        const _Divider(),
        _NavRow(
          icon: Icons.chat_bubble_outline,
          label: 'Chat',
          onTap: () => Navigator.pushNamed(context, '/chat'),
        ),
        const _Divider(),
        _NavRow(
          icon: Icons.home_outlined,
          label: 'Feed',
          onTap: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/feed',
            (_) => false,
          ),
        ),
        const _Divider(),
        _NavRow(
          icon: Icons.explore_outlined,
          label: 'Discover',
          onTap: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/discover',
            (_) => false,
          ),
        ),
        const _Divider(),
        _NavRow(
          icon: Icons.grid_view_outlined,
          label: 'My Peeps',
          onTap: () => Navigator.pushNamed(context, '/my_peeps'),
        ),
        const _Divider(),
        _NavRow(
          icon: Icons.favorite_outline,
          label: 'Favorites',
          onTap: () => Navigator.pushNamed(context, '/favorites'),
        ),
        const _Divider(),
        _NavRow(
          icon: Icons.groups_outlined,
          label: 'Groups',
          onTap: () => Navigator.pushNamed(context, '/groups'),
        ),
        const _Divider(),
        _NavRow(
          icon: Icons.leaderboard_outlined,
          label: 'Leaderboard',
          onTap: () => Navigator.pushNamed(context, '/leaderboard'),
        ),
        const _Divider(),
        _NavRow(
          icon: Icons.local_offer_outlined,
          label: 'Deals',
          onTap: () => Navigator.pushNamed(context, '/deals'),
        ),
        const _Divider(),
        _NavRow(
          icon: Icons.star_outline,
          label: 'VIPeeps',
          labelColor: const Color(0xFFB8860B),
          onTap: () => Navigator.pushNamed(context, '/vip_peeps'),
        ),
        const _Divider(),
        _NavRow(
          icon: Icons.person_add_outlined,
          label: 'Invite Friends',
          onTap: () => Navigator.pushNamed(context, '/invite'),
        ),
        const _Divider(),
        _NavRow(
          icon: Icons.settings_outlined,
          label: 'Settings',
          onTap: () => Navigator.pushNamed(context, '/settings'),
        ),
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 8),
        _NavRow(
          icon: Icons.logout,
          label: 'Sign Out',
          labelColor: Colors.red,
          showChevron: false,
          onTap: () => _signOut(context),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Nav row ───────────────────────────────────────────────────────────────────

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: labelColor ?? PeeplAppTokens.accentBlue,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? Colors.black87,
                ),
              ),
            ),
            if (showChevron)
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, indent: 64, endIndent: 20);
}
