import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/peepl_app_tokens.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    this.postId,
    this.reportedUserId,
  });

  final String? postId;
  final String? reportedUserId;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const List<String> _reasons = [
    'Spam or misleading',
    'Inappropriate content',
    'Harassment or bullying',
    'False crowd information',
    'Offensive language',
    'Other',
  ];

  static const _kOther = 'Other';

  final _customReasonController = TextEditingController();
  final _detailsController = TextEditingController();

  String? _selected;
  bool _submitting = false;
  bool _didInit = false;
  String _postId = '';
  String _reportedUserId = '';

  @override
  void dispose() {
    _customReasonController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _postId = widget.postId ?? '';
      _reportedUserId = widget.reportedUserId ?? '';

      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _postId = _postId.isNotEmpty
            ? _postId
            : (args['postId'] as String? ?? '');
        _reportedUserId = _reportedUserId.isNotEmpty
            ? _reportedUserId
            : (args['reportedUserId'] as String? ?? '');
      } else if (args is String && _postId.isEmpty) {
        _postId = args;
      }
    }
  }

  bool get _showCustomReason => _selected == _kOther;

  bool get _canSubmit {
    if (_selected == null) return false;
    if (_showCustomReason &&
        _customReasonController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to submit a report')),
      );
      return;
    }

    setState(() => _submitting = true);

    final reason = _showCustomReason
        ? _customReasonController.text.trim()
        : _selected!;
    final details = _detailsController.text.trim();

    try {
      final ref = FirebaseFirestore.instance.collection('reports').doc();
      await ref.set({
        'postId': _postId,
        'reportedUserId': _reportedUserId,
        'reporterId': uid,
        'reason': reason,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Report submitted. We'll review it within 24 hours.",
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplAppTokens.shellNavy,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(context),
            _buildStrip(),
            Expanded(
              child: Container(
                decoration: PeeplAppTokens.shellBodyDecoration(),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Why are you reporting this content?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: PeeplAppTokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ..._reasons.map(
                              (reason) => _ReasonRow(
                                label: reason,
                                selected: _selected == reason,
                                onTap: () => setState(() => _selected = reason),
                              ),
                            ),
                            if (_showCustomReason) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _customReasonController,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Describe the issue',
                                  hintText: 'Enter your reason...',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 2,
                              ),
                            ],
                            const SizedBox(height: 20),
                            const Text(
                              'Additional details (optional)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: PeeplAppTokens.accentBlue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _detailsController,
                              maxLength: 500,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText:
                                    'Add any extra context that may help us review...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Reports help keep Peepl safe and accurate for everyone',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: PeeplAppTokens.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildSubmitButton(),
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

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: PeeplAppTokens.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Report Content',
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
    );
  }

  Widget _buildStrip() {
    return Container(
      color: Colors.white.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: const Text(
        'Report Content',
        style: TextStyle(
          color: PeeplAppTokens.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: PeeplAppTokens.textPrimary,
            disabledBackgroundColor: Colors.red.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          onPressed: _canSubmit && !_submitting ? _submit : null,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: PeeplAppTokens.textPrimary,
                  ),
                )
              : const Text(
                  'Submit Report',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected ? PeeplAppTokens.accentBlue : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: selected ? PeeplAppTokens.accentBlue : Colors.black87,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
