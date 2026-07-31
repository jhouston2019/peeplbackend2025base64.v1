import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/peepl_app_tokens.dart';

import '../../services/merchant_pricing_service.dart';
import '../../widgets/merchant/merchant_empty_state.dart';
import '../../widgets/merchant/merchant_campaign_card.dart';
import '../../widgets/merchant/merchant_glass_text_field.dart';
import '../../widgets/merchant/merchant_analytics_chart.dart';
import '../../widgets/merchant/merchant_metric_card.dart';
import '../../widgets/merchant/merchant_screen_scaffold.dart';
import '../../widgets/merchant/peepl_merchant_tokens.dart';

class MerchantActivityScreen extends StatefulWidget {
  const MerchantActivityScreen({super.key});

  @override
  State<MerchantActivityScreen> createState() => _MerchantActivityScreenState();
}

class _MerchantActivityScreenState extends State<MerchantActivityScreen> {
  static const Color _chartOrange = Color(0xFFFF9F43);

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

  static double _estimateAdSpend(Map<String, dynamic> ad) =>
      MerchantPricingService.estimateAdSpend(ad);

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
    return MerchantScreenScaffold(
      title: 'Analytics',
      onBack: () => Navigator.pop(context),
      padding: EdgeInsets.zero,
      actions: [
        IconButton(
          icon: const Icon(Icons.file_download_outlined,
              color: PeeplMerchantTokens.textPrimary),
          tooltip: 'Export CSV',
          onPressed: _export,
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded,
              color: PeeplMerchantTokens.textPrimary),
          onPressed: _load,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _buildDateRangeSelector(),
          ),
          Expanded(
            child: _loading
                ? const MerchantLoadingView()
                : _error != null
                    ? _buildError()
                    : _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: PeeplMerchantTokens.glassDecoration(radius: 14),
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
            color: selected
                ? PeeplMerchantTokens.accentBlue
                : PeeplMerchantTokens.glassFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? PeeplMerchantTokens.accentBlue
                  : PeeplMerchantTokens.glassBorder,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected
                  ? PeeplMerchantTokens.textPrimary
                  : PeeplMerchantTokens.textSecondary,
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
          Text(_error!,
              style: const TextStyle(color: PeeplMerchantTokens.textSecondary)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _load,
            child: const Text('Retry'),
          ),
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
    final campaignCount = data.adBreakdowns.length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            MerchantMetricCard(
              label: 'Spend',
              value: merchantFormatCurrency(data.totalSpend),
              animate: false,
            ),
            const SizedBox(width: 12),
            MerchantMetricCard(
              label: 'Reach',
              value: merchantFormatCount(data.totalImpressions),
              animate: false,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            MerchantMetricCard(
              label: 'Views',
              value: merchantFormatCount(data.totalImpressions),
              animate: false,
            ),
            const SizedBox(width: 12),
            MerchantMetricCard(
              label: 'Clicks',
              value: merchantFormatCount(data.totalClicks),
              animate: false,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            MerchantMetricCard(
              label: 'CTR',
              value: merchantFormatPercent(ctr),
              animate: false,
            ),
            const SizedBox(width: 12),
            MerchantMetricCard(
              label: 'Campaigns',
              value: campaignCount.toString(),
              animate: false,
            ),
          ],
        ),
        const SizedBox(height: 24),
        MerchantAnalyticsChart(
          title: 'Daily Performance',
          labels: data.dailySeries
              .map((d) => '${d.date.month}/${d.date.day}')
              .toList(),
          values: data.dailySeries
              .map((d) => d.impressions.toDouble())
              .toList(),
          secondaryValues:
              data.dailySeries.map((d) => d.clicks.toDouble()).toList(),
          primaryLabel: 'Impressions',
          secondaryLabel: 'Clicks',
          secondaryColor: _chartOrange,
        ),
        if (!data.hasDailyAnalytics)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Using aggregate totals — daily breakdown will appear once analytics sync.',
              style: TextStyle(
                fontSize: 12,
                color: PeeplMerchantTokens.textMuted.withValues(alpha: 0.9),
              ),
            ),
          ),
        const SizedBox(height: 24),
        MerchantHeatmapChart(
          title: 'Engagement Heatmap',
          data: _buildHeatmapData(data),
        ),
        const SizedBox(height: 24),
        _sectionTitle('Top Campaigns'),
        const SizedBox(height: 12),
        _buildTopCampaigns(data.adBreakdowns),
        const SizedBox(height: 24),
        _sectionTitle('Recent Activity'),
        const SizedBox(height: 12),
        _buildRecentActivity(data.adBreakdowns),
        const SizedBox(height: 24),
        _sectionTitle('Best Performing Promotions'),
        const SizedBox(height: 12),
        _buildBestPromotions(data.adBreakdowns),
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

  Widget _buildTopCampaigns(List<_AdBreakdown> ads) {
    if (ads.isEmpty) {
      return _emptyPanel('No campaigns to rank yet.');
    }

    final sorted = [...ads]..sort((a, b) => b.impressions.compareTo(a.impressions));

    return Column(
      children: sorted.take(3).map((ad) {
        final ctr = ad.impressions > 0 ? (ad.clicks / ad.impressions) * 100 : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: MerchantCampaignCard(
            compact: true,
            title: ad.headline,
            imageUrl: ad.imageUrl,
            isLive: ad.status == 'Active',
            views: ad.impressions,
            clicks: ad.clicks,
            ctr: ctr,
            spend: '—',
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentActivity(List<_AdBreakdown> ads) {
    if (ads.isEmpty) {
      return _emptyPanel('Activity will appear once campaigns run.');
    }

    return Column(
      children: ads.take(5).map((ad) {
        final message = switch (ad.status) {
          'Active' => 'Campaign running',
          'Expired' => 'Campaign ended',
          _ => 'Campaign pending review',
        };
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: PeeplMerchantTokens.cardDecoration(),
          child: Row(
            children: [
              Icon(
                ad.status == 'Active'
                    ? Icons.play_circle_outline_rounded
                    : ad.status == 'Expired'
                        ? Icons.flag_outlined
                        : Icons.schedule_rounded,
                color: PeeplMerchantTokens.accentBlue,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: const TextStyle(
                        color: PeeplMerchantTokens.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ad.headline,
                      style: const TextStyle(
                        color: PeeplMerchantTokens.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                merchantFormatCount(ad.impressions),
                style: const TextStyle(
                  color: PeeplMerchantTokens.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBestPromotions(List<_AdBreakdown> ads) {
    if (ads.isEmpty) {
      return _emptyPanel('Promotion performance appears after impressions.');
    }

    final withImpressions = ads.where((ad) => ad.impressions > 0).toList()
      ..sort((a, b) {
        final aCtr = a.clicks / a.impressions;
        final bCtr = b.clicks / b.impressions;
        return bCtr.compareTo(aCtr);
      });

    if (withImpressions.isEmpty) {
      return _emptyPanel('Not enough engagement data yet.');
    }

    return Column(
      children: withImpressions.take(3).map((ad) {
        final ctr = (ad.clicks / ad.impressions) * 100;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: PeeplMerchantTokens.cardDecoration(),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  ad.headline,
                  style: const TextStyle(
                    color: PeeplMerchantTokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    merchantFormatPercent(ctr),
                    style: const TextStyle(
                      color: PeeplMerchantTokens.accentBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${merchantFormatCount(ad.clicks)} clicks',
                    style: const TextStyle(
                      color: PeeplMerchantTokens.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAdTable(List<_AdBreakdown> ads) {
    if (ads.isEmpty) {
      return _emptyPanel('No ads found for this account.');
    }

    return Container(
      decoration: PeeplMerchantTokens.cardDecoration(),
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
        color: PeeplMerchantTokens.glassFill,
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
          color: PeeplAppTokens.textSecondary,
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
      color: isEven ? Colors.white : PeeplAppTokens.card,
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
      color: PeeplAppTokens.cardElevated,
      child: Icon(Icons.campaign_outlined,
          size: 18, color: PeeplAppTokens.card0),
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
        color: PeeplAppTokens.textPrimary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: PeeplAppTokens.textPrimary.withValues(alpha: 0.06),
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
                        color: PeeplAppTokens.textSecondary,
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
                    backgroundColor: PeeplMerchantTokens.cardElevated,
                    color: PeeplMerchantTokens.accentBlue,
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
    return MerchantEmptyState(
      variant: MerchantEmptyStateVariant.noAnalytics,
    );
  }

  List<List<double>> _buildHeatmapData(_AnalyticsData data) {
    if (data.dailySeries.isEmpty) {
      return List.generate(4, (_) => List.filled(7, 0.2));
    }
    final maxImp = data.dailySeries
        .map((d) => d.impressions)
        .fold<int>(1, (a, b) => a > b ? a : b);
    return [
      for (final bucket in data.dailySeries.take(4))
        [bucket.impressions / maxImp, bucket.clicks / maxImp, 0.5, 0.3],
    ];
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: PeeplMerchantTokens.textPrimary,
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
