import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FollowListScreen extends StatefulWidget {
  const FollowListScreen({
    super.key,
    required this.userId,
    required this.mode,
  });

  /// The user whose followers/following we are viewing.
  final String userId;

  /// 'followers' or 'following'.
  final String mode;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final _db = FirebaseFirestore.instance;

  // Per-user caches to avoid redundant Firestore reads.
  final Map<String, String> _usernameCache = {};
  final Map<String, bool> _statusCache = {};

  // ── helpers ──────────────────────────────────────────────────────────────

  Future<String> _username(String uid) async {
    if (_usernameCache.containsKey(uid)) return _usernameCache[uid]!;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final name = (doc.data()?['username'] as String?) ??
          (doc.data()?['displayName'] as String?) ??
          'Unknown';
      return _usernameCache[uid] = name;
    } catch (_) {
      return _usernameCache[uid] = 'Unknown';
    }
  }

  /// In FOLLOWERS mode: does currentUser follow [otherUid]? → show "Following" chip.
  /// In FOLLOWING mode: does [otherUid] follow currentUser? → show "Follows You" label.
  Future<bool> _checkStatus(String otherUid) async {
    if (_statusCache.containsKey(otherUid)) return _statusCache[otherUid]!;
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return _statusCache[otherUid] = false;
    try {
      final DocumentSnapshot doc;
      if (widget.mode == 'followers') {
        // Does me follow otherUid?
        doc = await _db
            .collection('users')
            .doc(me.uid)
            .collection('following')
            .doc(otherUid)
            .get();
      } else {
        // Does otherUid follow me?
        doc = await _db
            .collection('users')
            .doc(me.uid)
            .collection('followers')
            .doc(otherUid)
            .get();
      }
      return _statusCache[otherUid] = doc.exists;
    } catch (_) {
      return _statusCache[otherUid] = false;
    }
  }

  static Color _avatarColor(String name) {
    const palette = [
      Color(0xFF1565C0),
      Color(0xFF388E3C),
      Color(0xFFBF360C),
      Color(0xFF6A1B9A),
      Color(0xFF00695C),
      Color(0xFF558B2F),
      Color(0xFF283593),
    ];
    if (name.isEmpty) return palette[0];
    return palette[name.codeUnitAt(0) % palette.length];
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isFollowers = widget.mode == 'followers';
    final title = isFollowers ? 'Followers' : 'Following';

    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            // ── blue header ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 20, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon:
                        const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // ── cyan section header ─────────────────────────────────────
            Container(
              width: double.infinity,
              color: const Color(0xFF00BCD4).withValues(alpha: 0.18),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
              child: Text(
                isFollowers ? 'People who follow this user' : 'People this user follows',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // ── list body ───────────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: _buildList(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .doc(widget.userId)
          .collection(widget.mode) // 'followers' or 'following'
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() {}),
              child: const Text('Failed to load — tap to retry'),
            ),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.mode == 'followers' ? '👤' : '🔍',
                  style: const TextStyle(fontSize: 40),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.mode == 'followers'
                      ? 'No followers yet'
                      : 'Not following anyone yet',
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: Colors.grey.shade100),
          itemBuilder: (_, i) => _UserRow(
            uid: docs[i].id,
            mode: widget.mode,
            fetchUsername: _username,
            checkStatus: _checkStatus,
            avatarColor: _avatarColor,
          ),
        );
      },
    );
  }
}

// ── user row ─────────────────────────────────────────────────────────────────

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.uid,
    required this.mode,
    required this.fetchUsername,
    required this.checkStatus,
    required this.avatarColor,
  });

  final String uid;
  final String mode;
  final Future<String> Function(String) fetchUsername;
  final Future<bool> Function(String) checkStatus;
  final Color Function(String) avatarColor;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([fetchUsername(uid), checkStatus(uid)]),
      builder: (context, snap) {
        final loading = !snap.hasData;
        final username = snap.data?[0] as String? ?? '';
        final hasStatus = snap.data?[1] as bool? ?? false;

        final initial =
            username.isNotEmpty ? username[0].toUpperCase() : '?';
        final color = avatarColor(username);

        Widget? chip;
        if (!loading) {
          if (mode == 'followers' && hasStatus) {
            chip = _Chip(label: 'Following', filled: true);
          } else if (mode == 'following' && hasStatus) {
            chip = _Chip(label: 'Follows You', filled: false);
          }
        }

        return InkWell(
          onTap: () => Navigator.pushNamed(
            context,
            '/user_profile',
            arguments: uid,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: loading
                      ? Colors.grey.shade300
                      : color,
                  child: loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                      : Text(
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
                  child: Text(
                    loading ? '...' : username,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (chip != null) chip,
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    color: Colors.grey, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── chip helper ──────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.filled});

  final String label;
  final bool filled; // true = blue filled, false = grey text

  @override
  Widget build(BuildContext context) {
    if (!filled) {
      return Text(
        label,
        style:
            const TextStyle(fontSize: 12, color: Colors.grey),
      );
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
