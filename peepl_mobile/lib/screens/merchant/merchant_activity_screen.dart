import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MerchantActivityScreen extends StatefulWidget {
  const MerchantActivityScreen({super.key});

  @override
  State<MerchantActivityScreen> createState() => _MerchantActivityScreenState();
}

class _MerchantActivityScreenState extends State<MerchantActivityScreen> {
  static const Color _blue = Color(0xFF1565C0);
  static const Color _orange = Color(0xFFFF9800);

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  int _rangeDays = 7;
  _AnalyticsData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_uid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Not signed in.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final rangeStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: _rangeDays - 1));

      final adsSnap = await FirebaseFirestore.instance
          .collection('native_ads')
          .where('advertiserId', isEqualTo: _uid)
          .get();

      final ads = adsSnap.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList();

      final dailyBuckets = <DateTime, _DailyBucket>{};
      final locationTotals = <String, int>{};
      var hasDailyAnalytics = false;

      for (var i = 0; i < _rangeDays; i++) {
        final day = DateTime(rangeStart.year, rangeStart.month, rangeStart.day + i);
        dailyBuckets[day] = _DailyBucket(date: day);
      }

      final adBreakdowns = <_AdBreakdown>[];

      for (final ad in ads) {
        final adId = ad['id'] as String;
        var adImpressions = 0;
        var adClicks = 0;
        var usedDaily = false;

        try {
          final dailySnap = await FirebaseFirestore.instance
              .collection('ad_analytics')
              .doc(adId)
              .collection('daily')
              .get();

          if (dailySnap.docs.isNotEmpty) {
            for (final doc in dailySnap.docs) {
              final data = doc.data();
              final day = _parseDailyDate(doc.id, data);
              if (day == null) continue;
              final dayKey = DateTime(day.year, day.month, day.day);
              if (dayKey.isBefore(rangeStart) || dayKey.isAfter(now)) continue;

              hasDailyAnalytics = true;
              usedDaily = true;
              final impressions =
                  (data['impressions'] as num?)?.toInt() ?? 0;
              final clicks = (data['clicks'] as num?)?.toInt() ?? 0;

              adImpressions += impressions;
              adClicks += clicks;

              final bucket = dailyBuckets.putIfAbsent(
                dayKey,
                () => _DailyBucket(date: dayKey),
              );
              bucket.impressions += impressions;
              bucket.clicks += clicks;

              _aggregateLocations(data, locationTotals);
            }
          }
        } catch (_) {
          // Subcollection may not exist yet — fall back below.
        }

        if (!usedDaily) {
          adImpressions = (ad['impressions'] as num?)?.toInt() ?? 0;
          adClicks = (ad['clicks'] as num?)?.toInt() ?? 0;

          final targetLocation = ad['targetLocation'] as String?;
          if (targetLocation != null && targetLocation.trim().isNotEmpty) {
            locationTotals[targetLocation.trim()] =
                (locationTotals[targetLocation.trim()] ?? 0) + adImpressions;
          }
        }

        adBreakdowns.add(
          _AdBreakdown(
            id: adId,
            headline: (ad['headline'] as String?) ?? 'Untitled Ad',
            imageUrl: ad['imageUrl'] as String?,
            impressions: adImpressions,
            clicks: adClicks,
            status: _adStatus(ad),
            tier: ad['tier'] as String?,
          ),
        );
      }

      var totalImpressions =
          adBreakdowns.fold<int>(0, (total, ad) => total + ad.impressions);
      var totalClicks =
          adBreakdowns.fold<int>(0, (total, ad) => total + ad.clicks);

      if (!hasDailyAnalytics && (totalImpressions > 0 || totalClicks > 0)) {
        final impPerDay = totalImpressions / _rangeDays;
        final clkPerDay = totalClicks / _rangeDays;
        for (final bucket in dailyBuckets.values) {
          bucket.impressions = impPerDay.round();
          bucket.clicks = clkPerDay.round();
        }
      }

      final dailySeries = dailyBuckets.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      final totalSpend = ads.fold<double>(
        0,
        (total, ad) => total + _estimateAdSpend(ad),
      );

      final topLocations = locationTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (mounted) {
        setState(() {
          _data = _AnalyticsData(
            totalImpressions: totalImpressions,
            totalClicks: totalClicks,
            totalSpend: totalSpend,
            dailySeries: dailySeries,
            adBreakdowns: adBreakdowns,
            topLocations: topLocations.take(5).toList(),
            hasDailyAnalytics: hasDailyAnalytics,
          );
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('MerchantActivity._load error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load analytics data.';
        });
      }
    }
  }

  static DateTime? _parseDailyDate(String docId, Map<String, dynamic> data) {
    final ts = data['date'];
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return DateTime(dt.year, dt.month, dt.day);
    }
    try {
      final parts = docId.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
    } catch (_) {}
    return null;
  }

  static void _aggregateLocations(
    Map<String, dynamic> data,
    Map<String, int> totals,
  ) {
    final candidates = [
      data['locations'],
      data['locationBreakdown'],
      data['locationImpressions'],
    ];

    for (final value in candidates) {
      if (value is Map) {
        value.forEach((key, amount) {
          final name = key.toString().trim();
          if (name.isEmpty) return;
          totals[name] =
              (totals[name] ?? 0) + ((amount as num?)?.toInt() ?? 0);
        });
        return;
      }
    }

    final list = data['topLocations'];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          final name = (item['name'] as String?) ??
              (item['location'] as String?) ??
              '';
          if (name.isEmpty) continue;
          totals[name] = (totals[name] ?? 0) +
              ((item['impressions'] as num?)?.toInt() ?? 0);
        }
      }
    }
  }

  static double _estimateAdSpend(Map<String, dynamic> ad) {
    final tier = (ad['tier'] as String? ?? 'standard').toLowerCase();
    final monthlyRate = tier.contains('prime')
        ? 299.0
        : tier.contains('premium')
            ? 299.0
            : 99.0;

    final start = ad['startDate'] is Timestamp
        ? (ad['startDate'] as Timestamp).toDate()
        : null;
    final end = ad['endDate'] is Timestamp
        ? (ad['endDate'] as Timestamp).toDate()
        : null;

    if (start != null && end != null && end.isAfter(start)) {
      final months = (end.difference(start).inDays / 30).ceil().clamp(1, 24);
      return monthlyRate * months;
    }
    return monthlyRate;
  }

  static String _adStatus(Map<String, dynamic> ad) {
    final endDate = ad['endDate'];
    if (endDate is Timestamp && endDate.toDate().isBefore(DateTime.now())) {
      return 'Expired';
    }
    if (ad['isActive'] == true) return 'Active';
    return 'Pending Review';
  }

  static Color _statusColor(String status) => switch (status) {
        'Active' => const Color(0xFF2E7D32),
        'Expired' => Colors.grey,
        _ => const Color(0xFFF57C00),
      };

  void _export() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(),
            _buildDateRangeSelector(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _blue),
                    )
                  : _error != null
                      ? _buildError()
                      : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: _blue,
      padding: const EdgeInsets.fromLTRB(4, 12, 8, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Ad Analytics',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            tooltip: 'Export',
            onPressed: _export,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          _rangeChip(7, 'Last 7 Days'),
          const SizedBox(width: 8),
          _rangeChip(30, 'Last 30 Days'),
          const SizedBox(width: 8),
          _rangeChip(90, 'Last 90 Days'),
        ],
      ),
    );
  }

  Widget _rangeChip(int days, String label) {
    final selected = _rangeDays == days;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_rangeDays == days) return;
          setState(() => _rangeDays = days);
          _load();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _blue : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? _blue : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final data = _data;
    if (data == null) {
      return const Center(child: Text('No analytics data available.'));
    }

    final ctr = data.totalImpressions > 0
        ? (data.totalClicks / data.totalImpressions) * 100
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _MetricCard(
              label: 'Total Impressions',
              value: _formatCount(data.totalImpressions),
            ),
            const SizedBox(width: 8),
            _MetricCard(
              label: 'Total Clicks',
              value: _formatCount(data.totalClicks),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _MetricCard(
              label: 'CTR',
              value: '${ctr.toStringAsFixed(1)}%',
            ),
            const SizedBox(width: 8),
            _MetricCard(
              label: 'Total Spend',
              value: '\$${data.totalSpend.toStringAsFixed(0)}',
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionTitle('Daily Performance'),
        if (!data.hasDailyAnalytics)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(
              'Using aggregate totals — daily breakdown will appear once analytics sync.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        const SizedBox(height: 8),
        _buildLineChart(data),
        const SizedBox(height: 8),
        _buildChartLegend(),
        const SizedBox(height: 24),
        _sectionTitle('Per-Ad Breakdown'),
        const SizedBox(height: 8),
        _buildAdTable(data.adBreakdowns),
        const SizedBox(height: 24),
        _sectionTitle('Top Performing Locations'),
        const SizedBox(height: 8),
        _buildTopLocations(data.topLocations),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLineChart(_AnalyticsData data) {
    final series = data.dailySeries;
    if (series.isEmpty) {
      return _emptyPanel('No performance data for this period.');
    }

    final impressionSpots = <FlSpot>[];
    final clickSpots = <FlSpot>[];
    var maxY = 1.0;

    for (var i = 0; i < series.length; i++) {
      final point = series[i];
      impressionSpots.add(FlSpot(i.toDouble(), point.impressions.toDouble()));
      clickSpots.add(FlSpot(i.toDouble(), point.clicks.toDouble()));
      maxY = [
        maxY,
        point.impressions.toDouble(),
        point.clicks.toDouble(),
      ].reduce((a, b) => a > b ? a : b);
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
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
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (series.length - 1).toDouble(),
          minY: 0,
          maxY: maxY <= 0 ? 1 : maxY * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY <= 5 ? 1 : (maxY / 4).ceilToDouble(),
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: series.length <= 7
                    ? 1
                    : (series.length / 5).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= series.length) {
                    return const SizedBox.shrink();
                  }
                  final date = series[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${date.month}/${date.day}',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: impressionSpots,
              isCurved: true,
              color: _blue,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: _blue.withValues(alpha: 0.08),
              ),
            ),
            LineChartBarData(
              spots: clickSpots,
              isCurved: true,
              color: _orange,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(_blue, 'Impressions'),
        const SizedBox(width: 20),
        _legendDot(_orange, 'Clicks'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildAdTable(List<_AdBreakdown> ads) {
    if (ads.isEmpty) {
      return _emptyPanel('No ads found for this account.');
    }

    return Container(
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
          _tableHeaderRow(),
          ...ads.asMap().entries.map(
                (entry) => _adTableRow(entry.value, entry.key.isEven),
              ),
        ],
      ),
    );
  }

  Widget _tableHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 44),
          const Expanded(
            flex: 3,
            child: Text(
              'Ad',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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
      width: 48,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _adTableRow(_AdBreakdown ad, bool isEven) {
    final ctr = ad.impressions > 0
        ? (ad.clicks / ad.impressions) * 100
        : 0.0;
    final statusColor = _statusColor(ad.status);

    return Container(
      color: isEven ? Colors.white : Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 36,
              height: 36,
              child: ad.imageUrl != null && ad.imageUrl!.isNotEmpty
                  ? Image.network(
                      ad.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _thumbPlaceholder(),
                    )
                  : _thumbPlaceholder(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ad.headline,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ad.status,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _dataCell(ad.impressions.toString()),
          _dataCell(ad.clicks.toString()),
          _dataCell('${ctr.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return ColoredBox(
      color: Colors.grey.shade200,
      child: Icon(Icons.campaign_outlined,
          size: 18, color: Colors.grey.shade500),
    );
  }

  Widget _dataCell(String text) {
    return SizedBox(
      width: 48,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildTopLocations(List<MapEntry<String, int>> locations) {
    if (locations.isEmpty) {
      return _emptyPanel(
        'Location data will appear once users view your ads.',
      );
    }

    final maxValue = locations.first.value.toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
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
        children: locations.map((entry) {
          final fraction =
              maxValue > 0 ? entry.value / maxValue : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.value} impressions',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    color: _blue,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyPanel(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  static String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }
}

class _DailyBucket {
  _DailyBucket({required this.date});

  final DateTime date;
  int impressions = 0;
  int clicks = 0;
}

class _AdBreakdown {
  const _AdBreakdown({
    required this.id,
    required this.headline,
    required this.imageUrl,
    required this.impressions,
    required this.clicks,
    required this.status,
    required this.tier,
  });

  final String id;
  final String headline;
  final String? imageUrl;
  final int impressions;
  final int clicks;
  final String status;
  final String? tier;
}

class _AnalyticsData {
  const _AnalyticsData({
    required this.totalImpressions,
    required this.totalClicks,
    required this.totalSpend,
    required this.dailySeries,
    required this.adBreakdowns,
    required this.topLocations,
    required this.hasDailyAnalytics,
  });

  final int totalImpressions;
  final int totalClicks;
  final double totalSpend;
  final List<_DailyBucket> dailySeries;
  final List<_AdBreakdown> adBreakdowns;
  final List<MapEntry<String, int>> topLocations;
  final bool hasDailyAnalytics;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
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
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
