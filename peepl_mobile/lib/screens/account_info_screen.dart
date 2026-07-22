import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  // Editable field controllers
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Tracks which fields are currently open for editing
  final Set<String> _editing = {};

  // Original values — used to determine whether anything changed
  String _origName = '';
  String _origUsername = '';
  String _origEmail = '';
  String _origPhone = '';

  // Read-only data loaded from Firestore
  Map<String, dynamic> _userData = {};
  int _pioneersCount = 0;
  bool _isVIPeep = false;

  bool _loading = true;
  bool _saving = false;

  bool get _hasChanges =>
      _nameCtrl.text != _origName ||
      _usernameCtrl.text != _origUsername ||
      _emailCtrl.text != _origEmail ||
      _phoneCtrl.text != _origPhone;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Rebuild when any controller changes so _hasChanges is re-evaluated.
    for (final ctrl in [_nameCtrl, _usernameCtrl, _emailCtrl, _phoneCtrl]) {
      ctrl.addListener(_onFieldChange);
    }
    _load();
  }

  @override
  void dispose() {
    for (final ctrl in [_nameCtrl, _usernameCtrl, _emailCtrl, _phoneCtrl]) {
      ctrl.removeListener(_onFieldChange);
      ctrl.dispose();
    }
    super.dispose();
  }

  void _onFieldChange() => setState(() {});

  // ── Data ─────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _db.collection('users').doc(_uid).get(),
        _db.collection('CAASNAhaDbPrl0zH1yDn5qRqAtJ3').doc(_uid).get(),
        _db
            .collection('pioneers')
            .where('userId', isEqualTo: _uid)
            .count()
            .get(),
      ]);

      final doc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final vipDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;
      final countSnap = results[2] as AggregateQuerySnapshot;
      final data = doc.data() ?? {};
      final user = _auth.currentUser;

      _origName =
          (data['name'] as String?) ?? (user?.displayName ?? '');
      _origUsername = (data['username'] as String?) ?? '';
      _origEmail = user?.email ?? '';
      _origPhone = (data['phone'] as String?) ?? '';

      _nameCtrl.text = _origName;
      _usernameCtrl.text = _origUsername;
      _emailCtrl.text = _origEmail;
      _phoneCtrl.text = _origPhone;

      if (mounted) {
        setState(() {
          _userData = data;
          _isVIPeep = (vipDoc.data()?['isVIPeep'] as bool?) ?? false;
          _pioneersCount = countSnap.count ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_hasChanges || _saving) return;
    setState(() => _saving = true);

    try {
      final user = _auth.currentUser!;
      final updates = <String, dynamic>{};

      if (_nameCtrl.text.trim() != _origName) {
        updates['name'] = _nameCtrl.text.trim();
        await user.updateDisplayName(_nameCtrl.text.trim());
      }
      if (_usernameCtrl.text.trim() != _origUsername) {
        updates['username'] = _usernameCtrl.text.trim();
      }
      if (_phoneCtrl.text.trim() != _origPhone) {
        updates['phone'] = _phoneCtrl.text.trim();
      }
      if (updates.isNotEmpty) {
        final batch = _db.batch();
        batch.update(_db.collection('users').doc(_uid), updates);
        await batch.commit();
      }

      // Email change: send verification to the new address first.
      if (_emailCtrl.text.trim() != _origEmail &&
          _emailCtrl.text.trim().isNotEmpty) {
        await user.verifyBeforeUpdateEmail(_emailCtrl.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Verification email sent — check your inbox to confirm the change.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }

      _origName = _nameCtrl.text;
      _origUsername = _usernameCtrl.text;
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

  Future<void> _resetPassword() async {
    final email = _auth.currentUser?.email;
    if (email == null || email.isEmpty) return;
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $email')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send reset email. Try again.'),
          ),
        );
      }
    }
  }

  // ── Formatting ────────────────────────────────────────────────────────────

  static String _formatDate(DateTime? dt) {
    if (dt == null) return 'Unknown';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(context),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildBody(),
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
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Account Info',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final user = _auth.currentUser;
    final memberSince = _formatDate(user?.metadata.creationTime);
    final rating =
        (_userData['rating'] as num?)?.toStringAsFixed(1) ?? '—';
    final isVip = _isVIPeep;
    final pioneerLabel =
        '$_pioneersCount ${_pioneersCount == 1 ? 'pioneer venue' : 'pioneer venues'}';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            children: [
              // ── PROFILE (editable) ─────────────────────────────────────
              _sectionLabel('PROFILE'),
              _buildInfoCard(children: [
                _editableRow(
                  label: 'Name',
                  field: 'name',
                  ctrl: _nameCtrl,
                ),
                _divider(),
                _editableRow(
                  label: 'Username',
                  field: 'username',
                  ctrl: _usernameCtrl,
                ),
                _divider(),
                _editableRow(
                  label: 'Email',
                  field: 'email',
                  ctrl: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                ),
                _divider(),
                _editableRow(
                  label: 'Phone',
                  field: 'phone',
                  ctrl: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                ),
                _divider(),
                _passwordRow(),
              ]),

              const SizedBox(height: 24),

              // ── ACCOUNT DETAILS (read-only) ────────────────────────────
              _sectionLabel('ACCOUNT DETAILS'),
              _buildInfoCard(children: [
                _readOnlyRow(label: 'Member Since', value: memberSince),
                _divider(),
                _readOnlyRow(label: 'Peepl Rating', value: rating),
                _divider(),
                _readOnlyRow(
                  label: 'Pioneer Status',
                  value: pioneerLabel,
                ),
                _divider(),
                _readOnlyRow(
                  label: 'VIPeeps',
                  value: isVip ? 'Active ⭐' : 'Inactive',
                  valueColor:
                      isVip ? const Color(0xFFB8860B) : Colors.black54,
                ),
                _divider(),
                _readOnlyRow(
                  label: 'Linked Accounts',
                  value: 'Not connected',
                  valueColor: Colors.black38,
                ),
              ]),

              const SizedBox(height: 16),
            ],
          ),
        ),

        // ── Save Changes button ────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _hasChanges
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
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

  Widget _buildInfoCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: children),
    );
  }

  Widget _editableRow({
    required String label,
    required String field,
    required TextEditingController ctrl,
    TextInputType? keyboardType,
  }) {
    final isEditing = _editing.contains(field);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 86,
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
                color: isEditing ? Colors.green : const Color(0xFF1565C0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              'Password',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              '••••••••',
              style: TextStyle(fontSize: 14, color: Colors.black38),
            ),
          ),
          GestureDetector(
            onTap: _resetPassword,
            child: const Text(
              '(reset)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1565C0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
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
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        thickness: 1,
        color: Colors.grey.shade200,
      );
}
