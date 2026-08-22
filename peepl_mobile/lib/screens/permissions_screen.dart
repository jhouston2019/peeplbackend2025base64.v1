import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/peepl_app_tokens.dart';

import '../services/notification_service.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _locationHandled = false;
  bool _notificationsHandled = false;
  bool _requestingLocation = false;
  bool _requestingNotifications = false;

  Future<void> _enableLocation() async {
    setState(() => _requestingLocation = true);
    try {
      await Geolocator.requestPermission();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _requestingLocation = false;
        _locationHandled = true;
      });
    }
  }

  void _skipLocation() {
    setState(() => _locationHandled = true);
  }

  Future<void> _enableNotifications() async {
    setState(() => _requestingNotifications = true);
    try {
      await NotificationService.instance.requestPermissions();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _requestingNotifications = false;
        _notificationsHandled = true;
      });
    }
  }

  void _skipNotifications() {
    setState(() => _notificationsHandled = true);
  }

  Future<void> _continueToHome() async {
    try {
      await NotificationService.instance.onUserSignedIn();
    } catch (e) {
      debugPrint('[PermissionsScreen] _continueToHome error: $e');
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.processPendingNotification();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: PeeplAppTokens.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: PeeplAppTokens.shellNavy,
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: const Text(
                  'peepl',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: PeeplAppTokens.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enable permissions',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Peepl works best with location and notifications. You can change these anytime in Settings.',
                        style: TextStyle(
                          fontSize: 15,
                          color: PeeplAppTokens.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _PermissionCard(
                        icon: Icons.location_on_outlined,
                        iconColor: PeeplAppTokens.accentBlue,
                        title: 'Location',
                        description:
                            'See crowd reports at bars, restaurants, parks, and events near you.',
                        handled: _locationHandled,
                        loading: _requestingLocation,
                        onEnable: _enableLocation,
                        onNotNow: _skipLocation,
                      ),
                      const SizedBox(height: 16),
                      _PermissionCard(
                        icon: Icons.notifications_outlined,
                        iconColor: PeeplAppTokens.accentBlue,
                        title: 'Notifications',
                        description:
                            'Get alerts when favorite spots get crowded or friends check in nearby.',
                        handled: _notificationsHandled,
                        loading: _requestingNotifications,
                        onEnable: _enableNotifications,
                        onNotNow: _skipNotifications,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _continueToHome,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PeeplAppTokens.shellNavy,
                      foregroundColor: PeeplAppTokens.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 17,
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
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.handled,
    required this.loading,
    required this.onEnable,
    required this.onNotNow,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool handled;
  final bool loading;
  final VoidCallback onEnable;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PeeplAppTokens.textPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PeeplAppTokens.cardElevated),
        boxShadow: [
          BoxShadow(
            color: PeeplAppTokens.textPrimary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              if (handled)
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 22),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.45,
            ),
          ),
          if (!handled) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : onEnable,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PeeplAppTokens.shellNavy,
                  foregroundColor: PeeplAppTokens.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PeeplAppTokens.textPrimary,
                        ),
                      )
                    : const Text(
                        'Enable',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: loading ? null : onNotNow,
                child: Text(
                  'Not now',
                  style: TextStyle(color: PeeplAppTokens.textSecondary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
