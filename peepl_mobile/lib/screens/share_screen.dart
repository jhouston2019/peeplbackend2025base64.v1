import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/peepl_app_tokens.dart';

import '../widgets/crowd_dot_ring_meter.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({
    super.key,
    this.postId,
    this.locationName,
    this.crowdingLevel,
    this.postData = const {},
  });

  final String? postId;
  final String? locationName;
  final int? crowdingLevel;
  final Map<String, dynamic> postData;

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  static const _kAppLink = 'https://peepl.app';
  static const _kInviteCountKey = 'invite_count';

  bool _didInit = false;
  String? _postId;
  String _locationName = 'this place';
  int? _crowdingLevel;
  int _inviteCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInviteCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    _postId = widget.postId;
    if (widget.locationName?.trim().isNotEmpty == true) {
      _locationName = widget.locationName!.trim();
    }
    _crowdingLevel = widget.crowdingLevel;

    final data = widget.postData;
    if (data.isNotEmpty) {
      _postId ??= data['postId'] as String? ?? data['id'] as String?;
      if (_locationName == 'this place') {
        final name = data['locationName'] as String?;
        if (name?.trim().isNotEmpty == true) {
          _locationName = name!.trim();
        }
      }
      _crowdingLevel ??= (data['crowdingLevel'] as num?)?.toInt();
    }

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _postId ??= args['postId'] as String? ?? args['id'] as String?;
      if (_locationName == 'this place') {
        final name = args['locationName'] as String?;
        if (name?.trim().isNotEmpty == true) {
          _locationName = name!.trim();
        }
      }
      _crowdingLevel ??= (args['crowdingLevel'] as num?)?.toInt();
    }
  }

  Future<void> _loadInviteCount() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _inviteCount = prefs.getInt(_kInviteCountKey) ?? 0);
    }
  }

  String get _crowdingWord {
    final level = _crowdingLevel ?? 5;
    return CrowdDotRingMeter.statusWord(level).toLowerCase();
  }

  String get _postShareText =>
      "I'm at $_locationName — it's $_crowdingWord! Know before you go 📍 $_kAppLink";

  String get _locationShareText =>
      'Check out $_locationName on Peepl for real-time crowd info! $_kAppLink';

  String get _appShareText =>
      'Know before you go! Peepl shows you how crowded any place is in real time. Download: $_kAppLink';

  Future<void> _share(String text) async {
    try {
      await Share.share(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share: $e')),
        );
      }
    }
  }

  Future<void> _copyLink(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (_postId != null && _postId!.isNotEmpty)
        _ShareCard(
          icon: Icons.post_add_outlined,
          title: 'Share this Post',
          message: _postShareText,
          onShare: () => _share(_postShareText),
          onCopy: () => _copyLink(_postShareText),
        ),
      _ShareCard(
        icon: Icons.place_outlined,
        title: 'Share this Location',
        message: _locationShareText,
        onShare: () => _share(_locationShareText),
        onCopy: () => _copyLink(_locationShareText),
      ),
      _ShareCard(
        icon: Icons.phone_android_outlined,
        title: 'Share the App',
        message: _appShareText,
        onShare: () => _share(_appShareText),
        onCopy: () => _copyLink(_appShareText),
      ),
    ];

    return Scaffold(
      backgroundColor: PeeplAppTokens.shellNavy,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: PeeplAppTokens.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Share',
                      style: TextStyle(
                        color: PeeplAppTokens.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: PeeplAppTokens.shellBodyDecoration(),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        children: [
                          Text(
                            'Spread the word',
                            style: TextStyle(
                              fontSize: 15,
                              color: PeeplAppTokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...cards.map(
                            (card) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: card,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F8FF),
                        border: Border(
                          top: BorderSide(
                            color: PeeplAppTokens.cardElevated,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 20,
                            color: PeeplAppTokens.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "You've invited $_inviteCount "
                            'friend${_inviteCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: PeeplAppTokens.accentBlue,
                            ),
                          ),
                        ],
                      ),
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

class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.onShare,
    required this.onCopy,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onShare;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PeeplAppTokens.textPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PeeplAppTokens.accentBlue.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: PeeplAppTokens.textPrimary.withValues(alpha: 0.06),
            blurRadius: 10,
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PeeplAppTokens.accentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: PeeplAppTokens.accentBlue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: PeeplAppTokens.accentBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: PeeplAppTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text(
                    'Share',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PeeplAppTokens.shellNavy,
                    foregroundColor: PeeplAppTokens.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text(
                    'Copy Link',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PeeplAppTokens.accentBlue,
                    side: const BorderSide(color: PeeplAppTokens.accentBlue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
