// contacts_service (pre-null-safety) is incompatible with Dart >=3.0.
// flutter_contacts is the actively maintained null-safe successor.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

enum _PermState { unknown, granted, denied }

class _InviteScreenState extends State<InviteScreen> {
  _PermState _permState = _PermState.unknown;
  List<Contact> _contacts = [];
  List<Contact> _filtered = [];
  bool _loading = false;
  final TextEditingController _searchCtrl = TextEditingController();

  String _username = '';

  // ── derived ─────────────────────────────────────────────────────────────

  String get _inviteLink => 'peepl.app/invite/$_username';

  String get _inviteMessage =>
      'Join me on Peepl — know before you go! Sign up: $_inviteLink';

  // ── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filterContacts);
    _loadUsername();
    _tryLoadContacts();
  }

  Future<void> _loadUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final name = doc.data()?['username'] as String?;
      if (mounted) {
        setState(() {
          _username = name?.isNotEmpty == true
              ? name!
              : user.displayName ??
                  user.email?.split('@').first ??
                  user.uid;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _username = user.displayName ??
              user.email?.split('@').first ??
              user.uid;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── contacts ─────────────────────────────────────────────────────────────

  Future<void> _tryLoadContacts() async {
    setState(() => _loading = true);
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        if (mounted) {
          setState(() {
            _permState = _PermState.denied;
            _loading = false;
          });
        }
        return;
      }
      final raw = await FlutterContacts.getContacts();
      final sorted = [...raw]
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      if (mounted) {
        setState(() {
          _contacts = sorted;
          _filtered = sorted;
          _permState = _PermState.granted;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _permState = _PermState.denied;
          _loading = false;
        });
      }
    }
  }

  void _filterContacts() {
    final term = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = term.isEmpty
          ? _contacts
          : _contacts
              .where((c) => c.displayName.toLowerCase().contains(term))
              .toList();
    });
  }

  // ── actions ──────────────────────────────────────────────────────────────

  Future<void> _copyLink(BuildContext ctx) async {
    await Clipboard.setData(ClipboardData(text: _inviteLink));
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Link copied!'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF1565C0),
        ),
      );
    }
  }

  void _inviteContact(Contact contact) => Share.share(_inviteMessage);

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: _buildBody(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Text(
            'Invite Friends',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInviteLinkSection(context),
          const SizedBox(height: 28),
          if (_permState == _PermState.unknown)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_permState == _PermState.granted)
            _buildContactsSection()
          else if (_permState == _PermState.denied)
            _buildPermissionDeniedSection(),
        ],
      ),
    );
  }

  // ── INVITE LINK SECTION ─────────────────────────────────────────────────

  Widget _buildInviteLinkSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Share your invite link',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8EEFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF1565C0).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.link, size: 18, color: Color(0xFF1565C0)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _inviteLink,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1565C0),
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _copyLink(context),
                icon: const Icon(Icons.copy, size: 17),
                label: const Text('Copy Link'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Share.share(_inviteMessage),
                icon: const Icon(Icons.share, size: 17),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── CONTACTS SECTION ────────────────────────────────────────────────────

  Widget _buildContactsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Invite from contacts',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
        const SizedBox(height: 12),
        // Search bar
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search contacts...',
            prefixIcon: const Icon(Icons.search, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _searchCtrl.text.isNotEmpty
                    ? 'No contacts match "${_searchCtrl.text}"'
                    : 'No contacts found',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filtered.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (_, i) => _buildContactRow(_filtered[i]),
          ),
      ],
    );
  }

  Widget _buildContactRow(Contact contact) {
    final name = contact.displayName.isNotEmpty ? contact.displayName : 'Unknown';
    final initial = name[0].toUpperCase();

    // Deterministic color from first char
    const palette = [
      Color(0xFF1565C0),
      Color(0xFF00897B),
      Color(0xFF6D4C41),
      Color(0xFF4527A0),
      Color(0xFF00695C),
      Color(0xFFAD1457),
      Color(0xFF37474F),
    ];
    final avatarColor = palette[name.codeUnitAt(0) % palette.length];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: avatarColor,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                // Production: batch-check phone numbers against Firestore
                // users collection to show "Already on Peepl" in green.
                const Text(
                  'Not on Peepl',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => _inviteContact(contact),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1565C0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Invite', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── PERMISSION DENIED ───────────────────────────────────────────────────

  Widget _buildPermissionDeniedSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('📵', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text(
            'Contacts access denied',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Allow Peepl to access your contacts so you can invite friends directly. '
            'Enable it in your device Settings.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _tryLoadContacts,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
