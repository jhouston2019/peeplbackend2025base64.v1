import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/share_service.dart';
import '../theme/peepl_app_tokens.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  static const _kInviteCountKey = 'invite_count';
  static const _kAppLink = 'https://peepl.app';
  static const _kShareMessage =
      'Check out Peepl — the app that tells you how crowded any place is before you go! Download: https://peepl.app';

  int _inviteCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInviteCount();
  }

  Future<void> _loadInviteCount() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _inviteCount = prefs.getInt(_kInviteCountKey) ?? 0);
    }
  }

  Future<void> _incrementInviteCount() async {
    final prefs = await SharedPreferences.getInstance();
    final next = _inviteCount + 1;
    await prefs.setInt(_kInviteCountKey, next);
    if (mounted) setState(() => _inviteCount = next);
  }

  Future<void> _sharePeepl() async {
    try {
      await ShareService.instance.presentShareSheet(_kShareMessage);
      await _incrementInviteCount();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share: $e')),
        );
      }
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(const ClipboardData(text: _kAppLink));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplAppTokens.shellNavy,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: PeeplAppTokens.textPrimary),
                  ),
                  const Text(
                    'Invite Friends',
                    style: TextStyle(
                      color: PeeplAppTokens.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: PeeplAppTokens.shellBodyDecoration(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/icon/icon.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Know Before You Go',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: PeeplAppTokens.accentBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Invite friends so you always know how busy any place is',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.45,
                          color: PeeplAppTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        "You've invited $_inviteCount friend${_inviteCount == 1 ? '' : 's'}",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: PeeplAppTokens.accentBlue,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _sharePeepl,
                          icon: const Icon(Icons.share, size: 22),
                          label: const Text(
                            'Share Peepl',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PeeplAppTokens.shellNavy,
                            foregroundColor: PeeplAppTokens.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _copyLink,
                          icon: const Icon(Icons.link, size: 20),
                          label: const Text(
                            'Copy Link',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PeeplAppTokens.accentBlue,
                            side: const BorderSide(color: PeeplAppTokens.accentBlue),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
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
}
