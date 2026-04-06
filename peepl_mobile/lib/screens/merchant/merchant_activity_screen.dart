import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MerchantActivityScreen extends StatefulWidget {
  const MerchantActivityScreen({super.key});

  @override
  State<MerchantActivityScreen> createState() =>
      _MerchantActivityScreenState();
}

class _MerchantActivityScreenState extends State<MerchantActivityScreen> {
  static const Color _blue = Color(0xFF1565C0);

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Holds fully-loaded data after _load() resolves.
  _PerformanceData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // 1. Fetch all of this merchant's ads.
      final adsSnap = await FirebaseFirestore.instance
          .collection('native_ads')
          .where('advertiserId', isEqualTo: _uid)
          .get();

      final ads = adsSnap.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList();

      if (ads.isEmpty) {
        if (mounted) {
          setState(() {
            _data = const _PerformanceData(
              totalImpressions: 0,
              totalClicks: 0,
              totalCost: 0,
              slots: [],
            );
            _loading = false;
          });
        }
        return;
      }

      final adIds = ads.map((a) => a['id'] as String).toList();

      // 2. Fetch ad events in chunks of 10 (Firestore whereIn limit).
      final allEventDocs = <QueryDocumentSnapshot>[];
      for (var i = 0; i < adIds.length; i += 10) {
        final chunk = adIds.skip(i).take(10).toList();
        final snap = await FirebaseFirestore.instance
            .collection('ad_events')
            .where('adId', whereIn: chunk)
            .orderBy('timestamp', descending: false)
            .get();
        allEventDocs.addAll(snap.docs);
      }

      // 3. Aggregate totals from ad docs and compute cost from tier × duration.
      int totalImpressions = 0;
      int totalClicks = 0;
      double totalCost = 0;
      for (final ad in ads) {
        totalImpressions += (ad['impressions'] as num?)?.toInt() ?? 0;
        totalClicks += (ad['clicks'] as num?)?.toInt() ?? 0;
        // Compute cost: tier hourly rate × duration in hours.
        final tier = (ad['tier'] as String? ?? '').toLowerCase();
        final double ratePerHour = tier.contains('premium')
            ? 39.99
            : tier.contains('standard')
                ? 19.99
                : 9.99;
        final start = ad['startDate'] is Timestamp
            ? (ad['startDate'] as Timestamp).toDate()
            : null;
        final end = ad['endDate'] is Timestamp
            ? (ad['endDate'] as Timestamp).toDate()
            : null;
        if (start != null && end != null) {
          final hours = end.difference(start).inMinutes / 60.0;
          totalCost += ratePerHour * hours;
        }
      }

      // 4. Group events by hour bucket.
      final Map<String, _SlotData> buckets = {};
      for (final doc in allEventDocs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final ts = data['timestamp'];
        if (ts == null) continue;
        final dt = ts is Timestamp ? ts.toDate() : null;
        if (dt == null) continue;
        final key = _hourKey(dt);
        final slot = buckets.putIfAbsent(key, () => _SlotData(timeLabel: key));
        if (data['event'] == 'impression') slot.impressions++;
        if (data['event'] == 'click') slot.clicks++;
      }

      final slots = buckets.values.toList()
        ..sort((a, b) => a.timeLabel.compareTo(b.timeLabel));

      if (mounted) {
        setState(() {
          _data = _PerformanceData(
            totalImpressions: totalImpressions,
            totalClicks: totalClicks,
            totalCost: totalCost,
            slots: slots,
          );
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load performance data';
        });
      }
      debugPrint('MerchantActivity._load error: $e');
    }
  }

  static String _hourKey(DateTime dt) {
    final h = dt.hour > 12
        ? dt.hour - 12
        : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.month}/${dt.day}  $h:00 $ampm';
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
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!,
                                  style:
                                      const TextStyle(color: Colors.black54)),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _load,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _buildBody(context),
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
              'Ad Performance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
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
        'Ad Performance',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final d = _data;
    if (d == null) {
      return const Center(child: Text('No data available.'));
    }

    final ctr = d.totalImpressions > 0
        ? (d.totalClicks / d.totalImpressions) * 100
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Metrics row
        Row(
          children: [
            _MetricCard(label: 'Impressions', value: d.totalImpressions.toString()),
            const SizedBox(width: 8),
            _MetricCard(label: 'Clicks', value: d.totalClicks.toString()),
            const SizedBox(width: 8),
            _MetricCard(label: 'CTR', value: '${ctr.toStringAsFixed(1)}%'),
            const SizedBox(width: 8),
            _MetricCard(
              label: 'Spend',
              value: d.totalCost > 0
                  ? '\$${d.totalCost.toStringAsFixed(2)}'
                  : '—',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // BY TIME SLOT table
        _sectionLabel('BY TIME SLOT'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: d.slots.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No event data yet.\nImpressions and clicks will appear here once your ad runs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black38, fontSize: 13),
                  ),
                )
              : Column(
                  children: [
                    _tableHeader(),
                    ...d.slots.asMap().entries.map((e) {
                      final idx = e.key;
                      final slot = e.value;
                      final slotCtr = slot.impressions > 0
                          ? (slot.clicks / slot.impressions) * 100
                          : 0.0;
                      return _tableRow(
                        slot.timeLabel,
                        slot.impressions.toString(),
                        slot.clicks.toString(),
                        '${slotCtr.toStringAsFixed(1)}%',
                        isEven: idx.isEven,
                      );
                    }),
                  ],
                ),
        ),

        const SizedBox(height: 32),

        SizedBox(
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
            onPressed: () =>
                Navigator.pushNamed(context, '/merchant_setup_step1'),
            child: const Text(
              'Create New Ad →',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Time Slot',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
                letterSpacing: 0.8,
              ),
            ),
          ),
          _headerCell('Impr.'),
          _headerCell('Clicks'),
          _headerCell('CTR'),
        ],
      ),
    );
  }

  Widget _headerCell(String text) {
    return SizedBox(
      width: 60,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey[600],
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _tableRow(
    String slot,
    String impressions,
    String clicks,
    String ctr, {
    required bool isEven,
  }) {
    return Container(
      color: isEven ? Colors.white : Colors.grey[50],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              slot,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          _dataCell(impressions),
          _dataCell(clicks),
          _dataCell(ctr, bold: true),
        ],
      ),
    );
  }

  Widget _dataCell(String text, {bool bold = false}) {
    return SizedBox(
      width: 60,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          color: bold ? _blue : Colors.black87,
        ),
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
}

// ── Data models ───────────────────────────────────────────────────────────────

class _SlotData {
  _SlotData({required this.timeLabel});

  final String timeLabel;
  int impressions = 0;
  int clicks = 0;
}

class _PerformanceData {
  const _PerformanceData({
    required this.totalImpressions,
    required this.totalClicks,
    required this.totalCost,
    required this.slots,
  });

  final int totalImpressions;
  final int totalClicks;
  final double totalCost;
  final List<_SlotData> slots;
}

// ── Metric card (local) ───────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
