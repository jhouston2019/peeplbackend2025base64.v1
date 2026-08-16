import 'package:flutter/material.dart';
import '../theme/peepl_app_tokens.dart';

import '../services/notification_service.dart';

class PushPermissionScreen extends StatelessWidget {
  const PushPermissionScreen({super.key});

  Future<void> _requestAndContinue(BuildContext context) async {
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.onUserSignedIn();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/home');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.instance.processPendingNotification();
      });
    }
  }

  Future<void> _skipAndContinue(BuildContext context) async {
    await NotificationService.instance.markPermissionPromptShown();
    // Still refresh token if OS permission was granted earlier.
    await NotificationService.instance.onUserSignedIn();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/home');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.instance.processPendingNotification();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: PeeplAppTokens.background,
        body: Column(
          children: [
            Container(
              color: PeeplAppTokens.background,
              width: double.infinity,
              padding: EdgeInsets.only(
                top: topPadding + 16,
                bottom: 20,
              ),
              child: const Center(
                child: Text(
                  'peepl',
                  style: TextStyle(
                    color: PeeplAppTokens.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  children: [
                    const Text('🔔', style: TextStyle(fontSize: 72)),
                    const SizedBox(height: 24),
                    const Text(
                      'Stay in the Know',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Get notified when your favorite spots get crowded, when someone Peeps a venue you Pioneer, or when friends check in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: PeeplAppTokens.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _PermissionCard(
                      rows: [
                        _PermissionRowData(
                          label: 'Allow',
                          color: PeeplAppTokens.background,
                          onTap: () => _requestAndContinue(context),
                        ),
                        _PermissionRowData(
                          label: "Don't Allow",
                          color: Colors.red,
                          onTap: () => _skipAndContinue(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionRowData {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PermissionRowData({
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _PermissionCard extends StatelessWidget {
  final List<_PermissionRowData> rows;

  const _PermissionCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PeeplAppTokens.textPrimary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: PeeplAppTokens.textPrimary.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            for (int i = 0; i < rows.length; i++) ...[
              InkWell(
                onTap: rows[i].onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 17, horizontal: 20),
                  child: Center(
                    child: Text(
                      rows[i].label,
                      style: TextStyle(
                        color: rows[i].color,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              if (i < rows.length - 1)
                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFE8E8E8)),
            ],
          ],
        ),
      ),
    );
  }
}
