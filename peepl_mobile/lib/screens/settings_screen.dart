import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_notifier.dart';
import '../services/auth_service.dart';
import '../services/presence_service.dart';
import '../shell_tab_bus.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

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
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SizedBox(height: 8),
                    _buildSectionTitle('CROWDING GUIDE'),
                    _buildCrowdingGuide(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('PREFERENCES'),
                    _buildSettingsTile(
                      icon: Icons.dark_mode_outlined,
                      title: 'Dark Mode',
                      trailing: Switch(
                        value: themeNotifier.isDarkMode,
                        onChanged: (val) => themeNotifier.setDarkMode(val),
                        activeColor: const Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('ACCOUNT'),
                    _buildAdminPanelTile(context),
                    _buildSettingsTile(
                      icon: Icons.person_outline,
                      title: 'Profile',
                      onTap: () {
                        Navigator.pop(context);
                        ShellTabBus.requestTab(3);
                      },
                    ),
                    _buildSettingsTile(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      onTap: () {},
                    ),
                    _buildSettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy',
                      onTap: () {},
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('ABOUT'),
                    _buildSettingsTile(
                      icon: Icons.info_outline,
                      title: 'About Peepl',
                      onTap: () => _showAboutDialog(context),
                    ),
                    _buildSettingsTile(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      onTap: () {},
                    ),
                    const SizedBox(height: 24),
                    _buildSignOutButton(context),
                    const SizedBox(height: 16),
                  ],
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
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Text(
            'Settings',
            style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminPanelTile(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        if (data == null || data['isAdmin'] != true) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            _buildSettingsTile(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Admin Panel',
              onTap: () => Navigator.pushNamed(context, '/admin'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey[500],
            letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF1565C0), size: 22),
      ),
      title: Text(title,
          style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildCrowdingGuide() {
    final levels = [
      {'label': '1–4', 'text': 'Not Crowded', 'color': const Color(0xFF4CAF50)},
      {'label': '5–6', 'text': 'Moderate', 'color': const Color(0xFFFFA726)},
      {'label': '7–10', 'text': 'Very Crowded', 'color': const Color(0xFFFF5722)},
    ];
    return Column(
      children: levels.map((level) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: level['color'] as Color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    level['label'] as String,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                level['text'] as String,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'About Peepl',
          style: TextStyle(
              color: Color(0xFF1565C0), fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Peepl helps you see how crowded places are in real time, shared by people just like you.\n\nVersion 1.0.0',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(color: Color(0xFF1565C0))),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () async {
          await PresenceService.instance.clearPresence();
          await AuthService().signOut();
          Navigator.pushNamedAndRemoveUntil(
              context, '/login', (_) => false);
        },
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text(
          'Sign Out',
          style: TextStyle(
              color: Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
