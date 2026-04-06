import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── model ─────────────────────────────────────────────────────────────────────

class _PioneerEntry {
  final String locationName;
  final String userId;
  final String username;
  final dynamic timestamp; // Firestore Timestamp
  final int peepCount;

  const _PioneerEntry({
    required this.locationName,
    required this.userId,
    required this.username,
    required this.timestamp,
    this.peepCount = 0,
  });
}

// ── screen ───────────────────────────────────────────────────────────────────

class PioneersScreen extends StatefulWidget {
  const PioneersScreen({super.key});

  @override
  State<PioneersScreen> createState() => _PioneersScreenState();
}

class _PioneersScreenState extends State<PioneersScreen> {
  final _db = FirebaseFirestore.instance;
  late Future<List<_PioneerEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // ── data ───────────────────────────────────────────────────────────────────

  Future<List<_PioneerEntry>> _load() async {
    // All pioneer docs ordered earliest first so we get the true first pioneer
    // per venue naturally.
    final snap = await _db
        .collection('pioneers')
        .orderBy('timestamp')
        .get();

    // Group by locationName — first doc per venue wins.
    final Map<String, Map<String, dynamic>> first = {};
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final venue = (data['locationName'] as String?)?.trim() ?? '';
      if (venue.isEmpty || first.containsKey(venue)) continue;
      first[venue] = {...data, 'id': doc.id};
    }

    if (first.isEmpty) return [];

    // Batch-fetch usernames for unique pioneer userIds.
    final uniqueUids = first.values
        .map((d) => d['userId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final Map<String, String> usernameMap = {};
    if (uniqueUids.isNotEmpty) {
      final userDocs = await Future.wait(
        uniqueUids.map((id) => _db.collection('users').doc(id).get()),
      );
      for (final doc in userDocs) {
        if (!doc.exists) continue;
        final d = doc.data() as Map<String, dynamic>;
        usernameMap[doc.id] = (d['username'] as String?) ??
            (d['displayName'] as String?) ??
            'Unknown';
      }
    }

    // Batch-fetch peep counts for all venues in parallel.
    final venues = first.keys.toList();
    final countResults = await Future.wait(
      venues.map(
        (venue) => _db
            .collection('location_posts')
            .where('locationName', isEqualTo: venue)
            .count()
            .get(),
      ),
    );

    return List.generate(venues.length, (i) {
      final venue = venues[i];
      final data = first[venue]!;
      final uid = data['userId'] as String? ?? '';
      return _PioneerEntry(
        locationName: venue,
        userId: uid,
        username: usernameMap[uid] ?? 'Unknown',
        timestamp: data['timestamp'],
        peepCount: countResults[i].count ?? 0,
      );
    });
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  // ── navigation ─────────────────────────────────────────────────────────────

  Future<void> _openVenue(BuildContext context, String locationName) async {
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

  // ── colour helpers ─────────────────────────────────────────────────────────

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

  static String _formatDate(dynamic ts) {
    if (ts == null) return '';
    final dt = ts is Timestamp ? ts.toDate() : null;
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
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
                child: FutureBuilder<List<_PioneerEntry>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load: ${snap.error}',
                          style:
                              TextStyle(color: Colors.grey[500]),
                        ),
                      );
                    }
                    final entries = snap.data ?? [];
                    if (entries.isEmpty) return _buildEmpty();
                    return _buildList(context, entries);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Text(
            '🏅 Pioneers',
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

  Widget _buildSectionHeader() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF00BCD4).withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: const Text(
        'First to Peep each venue',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ── EMPTY STATE ────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏅', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text(
              'No Pioneers yet — be the first!',
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── LIST ───────────────────────────────────────────────────────────────────

  Widget _buildList(BuildContext context, List<_PioneerEntry> entries) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: entries.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey.shade100),
        itemBuilder: (_, i) =>
            _PioneerRow(
              entry: entries[i],
              gradient: _venueGradient(entries[i].locationName),
              dateLabel: _formatDate(entries[i].timestamp),
              onTap: () =>
                  _openVenue(context, entries[i].locationName),
            ),
      ),
    );
  }
}

// ── pioneer row ───────────────────────────────────────────────────────────────

class _PioneerRow extends StatelessWidget {
  const _PioneerRow({
    required this.entry,
    required this.gradient,
    required this.dateLabel,
    required this.onTap,
  });

  final _PioneerEntry entry;
  final List<Color> gradient;
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            // Venue gradient thumbnail
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('🏅', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),

            // Venue name + pioneer info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.locationName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'First: ${entry.username}'
                    '${dateLabel.isNotEmpty ? ' · $dateLabel' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Peep count
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.peepCount}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1565C0),
                  ),
                ),
                Text(
                  'peep${entry.peepCount == 1 ? '' : 's'}',
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}
