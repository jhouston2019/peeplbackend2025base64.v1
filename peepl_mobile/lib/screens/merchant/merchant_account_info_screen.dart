import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MerchantAccountInfoScreen extends StatefulWidget {
  const MerchantAccountInfoScreen({super.key});

  @override
  State<MerchantAccountInfoScreen> createState() =>
      _MerchantAccountInfoScreenState();
}

class _MerchantAccountInfoScreenState
    extends State<MerchantAccountInfoScreen> {
  static const Color _blue = Color(0xFF1565C0);

  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _accountNumber {
    final suffix = _uid.length >= 5
        ? _uid.substring(_uid.length - 5).toUpperCase()
        : _uid.toUpperCase().padLeft(5, 'X');
    return 'MRC-$suffix';
  }

  // Editable controllers
  final _bizNameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final Set<String> _editing = {};

  String _origBizName = '';
  String _origContact = '';
  String _origEmail = '';
  String _origPhone = '';

  bool _loading = true;
  bool _saving = false;

  bool get _hasChanges =>
      _bizNameCtrl.text != _origBizName ||
      _contactCtrl.text != _origContact ||
      _emailCtrl.text != _origEmail ||
      _phoneCtrl.text != _origPhone;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    for (final c in [_bizNameCtrl, _contactCtrl, _emailCtrl, _phoneCtrl]) {
      c.addListener(() => setState(() {}));
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_bizNameCtrl, _contactCtrl, _emailCtrl, _phoneCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final doc = await _db.collection('users').doc(_uid).get();
      final data = doc.data() ?? {};
      final user = FirebaseAuth.instance.currentUser;

      _origBizName = (data['businessName'] as String?) ?? '';
      _origContact = (data['contactName'] as String?) ?? (user?.displayName ?? '');
      _origEmail = (data['merchantEmail'] as String?) ?? (user?.email ?? '');
      _origPhone = (data['phone'] as String?) ?? '';

      _bizNameCtrl.text = _origBizName;
      _contactCtrl.text = _origContact;
      _emailCtrl.text = _origEmail;
      _phoneCtrl.text = _origPhone;

      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_hasChanges || _saving) return;
    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{};
      if (_bizNameCtrl.text.trim() != _origBizName) {
        updates['businessName'] = _bizNameCtrl.text.trim();
      }
      if (_contactCtrl.text.trim() != _origContact) {
        updates['contactName'] = _contactCtrl.text.trim();
      }
      if (_emailCtrl.text.trim() != _origEmail) {
        updates['merchantEmail'] = _emailCtrl.text.trim();
      }
      if (_phoneCtrl.text.trim() != _origPhone) {
        updates['phone'] = _phoneCtrl.text.trim();
      }
      if (updates.isNotEmpty) {
        await _db.collection('users').doc(_uid).update(updates);
      }
      _origBizName = _bizNameCtrl.text;
      _origContact = _contactCtrl.text;
      _origEmail = _emailCtrl.text;
      _origPhone = _phoneCtrl.text;
      _editing.clear();
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(context),
            _buildStrip(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: _blue,
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Account Info',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrip() {
    return Container(
      color: const Color(0xFF0D47A1),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: const Text(
        'Account Info',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Business Info card
              _sectionLabel('BUSINESS INFO'),
              const SizedBox(height: 8),
              _infoCard(children: [
                _editRow(label: 'Business', field: 'biz', ctrl: _bizNameCtrl),
                _divider(),
                _editRow(label: 'Contact', field: 'contact', ctrl: _contactCtrl),
                _divider(),
                _editRow(
                  label: 'Email',
                  field: 'email',
                  ctrl: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                ),
                _divider(),
                _editRow(
                  label: 'Phone',
                  field: 'phone',
                  ctrl: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                ),
                _divider(),
                // Read-only account number
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 86,
                        child: Text(
                          'Acct No.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _accountNumber,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: 24),

              // Billing section
              _sectionLabel('BILLING'),
              const SizedBox(height: 8),
              _infoCard(children: [
                _readRow(label: 'Payment method', value: 'Add payment method'),
                _divider(),
                _readRow(label: 'Billing cycle', value: 'Monthly'),
                _divider(),
                _readRow(label: 'Total spent', value: 'Tracked on payment'),
              ]),

              const SizedBox(height: 16),

              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Payment method setup coming soon (Stripe — Phase 5)',
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  side: const BorderSide(color: _blue),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Update Payment Method'),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),

        // Save button
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _hasChanges
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ── Row builders ──────────────────────────────────────────────────────────

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: children),
    );
  }

  Widget _editRow({
    required String label,
    required String field,
    required TextEditingController ctrl,
    TextInputType? keyboardType,
  }) {
    final isEditing = _editing.contains(field);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: isEditing
                ? TextField(
                    controller: ctrl,
                    keyboardType: keyboardType,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  )
                : Text(
                    ctrl.text.isEmpty ? '—' : ctrl.text,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() {
              if (isEditing) {
                _editing.remove(field);
              } else {
                _editing.add(field);
              }
            }),
            child: Text(
              isEditing ? 'Done' : '(edit)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    isEditing ? Colors.green : _blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey[500],
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        thickness: 1,
        color: Colors.grey.shade100,
      );
}
