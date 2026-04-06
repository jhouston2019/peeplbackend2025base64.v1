import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _displayName =>
      FirebaseAuth.instance.currentUser?.displayName ??
      FirebaseAuth.instance.currentUser?.email?.split('@').first ??
      'User';

  // ── colour helpers ───────────────────────────────────────────────────────

  static const List<List<Color>> _palettes = [
    [Color(0xFF1565C0), Color(0xFF42A5F5)],
    [Color(0xFF2E7D32), Color(0xFF66BB6A)],
    [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
    [Color(0xFF00695C), Color(0xFF26A69A)],
    [Color(0xFFBF360C), Color(0xFFEF9A9A)],
    [Color(0xFF37474F), Color(0xFF78909C)],
  ];

  List<Color> _venueGradient(String name) =>
      _palettes[name.isNotEmpty ? name.codeUnitAt(0) % _palettes.length : 0];

  // ── crowd level colour ───────────────────────────────────────────────────

  static Color _levelColor(int l) {
    if (l <= 4) return const Color(0xFF4CAF50);
    if (l <= 6) return const Color(0xFFFFA726);
    return const Color(0xFFFF5722);
  }

  // ── actions ──────────────────────────────────────────────────────────────

  Future<void> _navigateToVenue(
      BuildContext context, String locationName) async {
    final snap = await _db
        .collection('location_posts')
        .where('locationName', isEqualTo: locationName)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (!context.mounted) return;

    final venueData = snap.docs.isNotEmpty
        ? {
            ...snap.docs.first.data() as Map<String, dynamic>,
            'id': snap.docs.first.id,
          }
        : <String, dynamic>{'locationName': locationName};

    Navigator.pushNamed(context, '/venue', arguments: venueData);
  }

  Future<void> _deleteFavorite(
      BuildContext context, String docId, String locationName) async {
    if (_uid.isEmpty) return;
    try {
      await _db
          .collection('users')
          .doc(_uid)
          .collection('favorites')
          .doc(docId)
          .delete();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove: $e')),
        );
      }
    }
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            _buildBanner(context),
            _buildSectionHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: _uid.isEmpty
                    ? const Center(child: Text('Not signed in'))
                    : _buildList(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BANNER ───────────────────────────────────────────────────────────────

  Widget _buildBanner(BuildContext context) {
    final name = _displayName;
    return Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Favorites',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF00BCD4).withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: const Text(
        'Favorites',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ── LIST ─────────────────────────────────────────────────────────────────

  Widget _buildList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .doc(_uid)
          .collection('favorites')
          .orderBy('lastVisited', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('♥', style: TextStyle(fontSize: 52, color: Colors.red)),
                  SizedBox(height: 14),
                  Text(
                    'No favorites yet — tap ♥ on any venue to save it',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: Colors.grey.shade100),
          itemBuilder: (_, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final locationName =
                data['locationName'] as String? ?? 'Unknown venue';
            final lastCrowd =
                (data['lastCrowdLevel'] as num?)?.toInt() ?? 0;
            return _FavoriteRow(
              docId: doc.id,
              locationName: locationName,
              lastCrowd: lastCrowd,
              gradient: _venueGradient(locationName),
              levelColor: _levelColor(lastCrowd),
              onTap: () => _navigateToVenue(context, locationName),
              onDelete: () =>
                  _deleteFavorite(context, doc.id, locationName),
            );
          },
        );
      },
    );
  }
}

// ── favorite row ─────────────────────────────────────────────────────────────

class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({
    required this.docId,
    required this.locationName,
    required this.lastCrowd,
    required this.gradient,
    required this.levelColor,
    required this.onTap,
    required this.onDelete,
  });

  final String docId;
  final String locationName;
  final int lastCrowd;
  final List<Color> gradient;
  final Color levelColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Remove',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              // 28px gradient thumbnail
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 14),
              // Venue name + crowd level
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locationName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lastCrowd > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: levelColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Last crowd: $lastCrowd/10',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
