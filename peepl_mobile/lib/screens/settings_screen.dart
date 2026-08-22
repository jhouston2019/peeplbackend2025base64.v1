import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/peepl_app_tokens.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/presence_service.dart';
import '../theme_notifier.dart';
import '../widgets/home/peepl_home_tokens.dart';

class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // SharedPreferences-backed toggles
  bool _pushEnabled = true;
  bool _locationAlertsEnabled = true;

  // Firestore-backed privacy settings
  String _profileVisibility = 'Public';
  bool _locationSharingEnabled = true;
  bool _loadingPrivacy = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadPrivacySettings();
  }

  // ── Load / save helpers ───────────────────────────────────────────────────

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _pushEnabled = prefs.getBool('pushNotificationsEnabled') ?? true;
        _locationAlertsEnabled =
            prefs.getBool('locationAlertsEnabled') ?? true;
      });
    }
  }

  Future<void> _loadPrivacySettings() async {
    if (_uid.isEmpty) {
      if (mounted) setState(() => _loadingPrivacy = false);
      return;
    }
    try {
      final doc = await _db.collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3').doc(_uid).get();
      final data = doc.data() ?? {};
      const validVisibilities = ['Public', 'Friends Only'];
      if (mounted) {
        setState(() {
          _profileVisibility =
              validVisibilities.contains(data['profileVisibility'])
                  ? data['profileVisibility'] as String
                  : 'Public';
          _locationSharingEnabled =
              (data['locationSharingEnabled'] as bool?) ?? true;
          _loadingPrivacy = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPrivacy = false);
    }
  }

  Future<void> _setPushEnabled(bool val) async {
    setState(() => _pushEnabled = val);
    try {
      await NotificationService.instance.applyPushPreference(val);
    } catch (e) {
      debugPrint('[SettingsScreen] _setPushEnabled error: $e');
    }
  }

  Future<void> _setLocationAlerts(bool val) async {
    setState(() => _locationAlertsEnabled = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('locationAlertsEnabled', val);
  }

  Future<void> _setProfileVisibility(String? val) async {
    if (val == null || _uid.isEmpty) return;
    setState(() => _profileVisibility = val);
    try {
      await _db.collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3').doc(_uid).set(
        {'profileVisibility': val},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[SettingsScreen] _setProfileVisibility error: $e');
    }
  }

  Future<void> _setLocationSharing(bool val) async {
    setState(() => _locationSharingEnabled = val);
    if (_uid.isEmpty) return;
    try {
      await _db.collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3').doc(_uid).set(
        {'locationSharingEnabled': val},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[SettingsScreen] _setLocationSharing error: $e');
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await PresenceService.instance.clearPresence();
      await AuthService().signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      backgroundColor: PeeplAppTokens.shellNavy,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: Container(
                decoration: PeeplAppTokens.shellBodyDecoration(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  children: [
                    // ── APPEARANCE ──────────────────────────────────────────
                    _sectionTitle('APPEARANCE'),
                    _tile(
                      icon: Icons.dark_mode_outlined,
                      title: 'Dark Mode',
                      trailing: Switch(
                        value: themeNotifier.isDarkMode,
                        onChanged: themeNotifier.setDarkMode,
                        activeColor: PeeplAppTokens.accentBlue,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── NOTIFICATIONS ────────────────────────────────────────
                    _sectionTitle('NOTIFICATIONS'),
                    _tile(
                      icon: Icons.notifications_outlined,
                      title: 'Push Notifications',
                      trailing: Switch(
                        value: _pushEnabled,
                        onChanged: _setPushEnabled,
                        activeColor: PeeplAppTokens.accentBlue,
                      ),
                    ),
                    _tile(
                      icon: Icons.location_on_outlined,
                      title: 'Location Alerts',
                      trailing: Switch(
                        value: _locationAlertsEnabled,
                        onChanged: _setLocationAlerts,
                        activeColor: PeeplAppTokens.accentBlue,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── PRIVACY ──────────────────────────────────────────────
                    _sectionTitle('PRIVACY'),
                    if (_loadingPrivacy)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      )
                    else ...[
                      ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        leading: _tileIcon(Icons.visibility_outlined),
                        title: const Text(
                          'Profile Visibility',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _profileVisibility,
                            isDense: true,
                            items: ['Public', 'Friends Only']
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(
                                      v,
                                      style:
                                          const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _setProfileVisibility,
                          ),
                        ),
                      ),
                      _tile(
                        icon: Icons.share_location_outlined,
                        title: 'Location Sharing',
                        trailing: Switch(
                          value: _locationSharingEnabled,
                          onChanged: _setLocationSharing,
                          activeColor: PeeplAppTokens.accentBlue,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // ── ACCOUNT ──────────────────────────────────────────────
                    _sectionTitle('ACCOUNT'),
                    _buildAdminPanelTile(context),
                    _tile(
                      icon: Icons.storefront_outlined,
                      title: 'Merchant Portal',
                      onTap: () =>
                          Navigator.pushNamed(context, '/merchant_portal'),
                    ),
                    _tile(
                      icon: Icons.edit_outlined,
                      title: 'Edit Profile',
                      onTap: () =>
                          Navigator.pushNamed(context, '/account_info'),
                    ),
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      leading: _tileIcon(
                        Icons.logout,
                        bgColor: const Color(0xFFFFEBEE),
                        iconColor: Colors.red,
                      ),
                      title: const Text(
                        'Log Out',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.grey,
                      ),
                      onTap: () => _confirmSignOut(context),
                    ),
                    const SizedBox(height: 24),

                    // ── CROWDING GUIDE ───────────────────────────────────────
                    _sectionTitle('CROWDING GUIDE'),
                    _buildCrowdingGuide(),
                    const SizedBox(height: 24),

                    // ── ABOUT ────────────────────────────────────────────────
                    _sectionTitle('ABOUT'),
                    _tile(
                      icon: Icons.info_outline,
                      title: 'About Peepl',
                      onTap: () => _showAboutDialog(context),
                    ),
                    const SizedBox(height: 32),

                    // ── FOOTER ───────────────────────────────────────────────
                    const Center(
                      child: Text(
                        'Peepl v1.0.0',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
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

  // ── Reusable widgets ──────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: PeeplAppTokens.textPrimary, size: 28),
          ),
          const SizedBox(width: 16),
          const Text(
            'Settings',
            style: TextStyle(
              color: PeeplAppTokens.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: PeeplAppTokens.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _tileIcon(
    IconData icon, {
    Color bgColor = const Color(0xFFE3F2FD),
    Color iconColor = PeeplAppTokens.accentBlue,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: iconColor, size: 22),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: _tileIcon(icon),
      title: Text(
        title,
        style:
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      trailing: trailing ??
          const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
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
        if (snap.hasError) {
          return const SizedBox.shrink();
        }

        final data = snap.data?.data();
        if (data == null || data['isAdmin'] != true) {
          return const SizedBox.shrink();
        }
        return _tile(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Admin Panel',
          onTap: () => Navigator.pushNamed(context, '/admin'),
        );
      },
    );
  }

  Widget _buildCrowdingGuide() {
    final levels = [
      {
        'label': '1–4',
        'text': 'Light',
        'color': PeeplHomeTokens.crowdLight,
      },
      {
        'label': '5–7',
        'text': 'Getting Busy',
        'color': PeeplHomeTokens.crowdMedium,
      },
      {
        'label': '8–10',
        'text': 'Very Busy',
        'color': PeeplHomeTokens.crowdHigh,
      },
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
                      color: PeeplHomeTokens.dealsForeground,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                level['text'] as String,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
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
            color: PeeplAppTokens.accentBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Peepl helps you see how crowded places are in real time, '
          'shared by people just like you.\n\nVersion 1.0.0',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: PeeplAppTokens.accentBlue),
            ),
          ),
        ],
      ),
    );
  }
}
