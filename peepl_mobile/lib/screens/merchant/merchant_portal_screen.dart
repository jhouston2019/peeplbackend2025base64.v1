import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/merchant_pricing_service.dart';
import '../../widgets/merchant/merchant_animated_metric.dart';
import '../../widgets/merchant/merchant_calendar.dart';
import '../../widgets/merchant/merchant_campaign_card.dart';
import '../../widgets/merchant/merchant_dashboard_header.dart';
import '../../widgets/merchant/merchant_dashboard_shell.dart';
import '../../widgets/merchant/merchant_live_status_card.dart';
import '../../widgets/merchant/merchant_metric_card.dart';
import '../../widgets/merchant/merchant_notification_card.dart';
import '../../widgets/merchant/merchant_billing_card.dart';
import '../../widgets/merchant/merchant_profile_card.dart';
import '../../widgets/merchant/merchant_empty_state.dart';
import '../../widgets/merchant/merchant_skeleton.dart';
import '../../widgets/merchant/peepl_merchant_tokens.dart';

class MerchantPortalScreen extends StatefulWidget {
  const MerchantPortalScreen({super.key});

  @override
  State<MerchantPortalScreen> createState() => _MerchantPortalScreenState();
}

class _MerchantPortalScreenState extends State<MerchantPortalScreen> {
  MerchantShellSection _section = MerchantShellSection.dashboard;
  final Set<DateTime> _calendarSlots = {};

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }
  }

  Future<void> _pauseAd(String adId) async {
    try {
      await FirebaseFirestore.instance
          .collection('native_ads')
          .doc(adId)
          .update({'isActive': false});
      if (mounted) {
        _showMessage('Campaign paused.');
      }
    } catch (_) {
      if (mounted) _showMessage('Could not pause campaign. Try again.');
    }
  }

  Future<void> _resumeAd(String adId) async {
    try {
      await FirebaseFirestore.instance
          .collection('native_ads')
          .doc(adId)
          .update({'isActive': true});
      if (mounted) _showMessage('Campaign resumed.');
    } catch (_) {
      if (mounted) _showMessage('Could not resume campaign. Try again.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: PeeplMerchantTokens.cardElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onSectionChanged(MerchantShellSection section) {
    setState(() => _section = section);
  }

  void _openCreate() =>
      Navigator.pushNamed(context, '/merchant_setup_step2');

  void _openAnalytics() =>
      Navigator.pushNamed(context, '/merchant_activity');

  static String _accountStatus(Map<String, dynamic>? data) {
    if (data == null) return 'Pending';
    if (data['isSuspended'] == true || data['status'] == 'suspended') {
      return 'Suspended';
    }
    if (data['isActive'] == true) return 'Active';
    return 'Pending';
  }

  static Color _accountStatusColor(String status) => switch (status) {
        'Active' => PeeplMerchantTokens.success,
        'Suspended' => PeeplMerchantTokens.danger,
        _ => PeeplMerchantTokens.warning,
      };

  static String _tierLabel(String? tier) {
    final value = (tier ?? 'standard').toLowerCase();
    if (value.contains('prime')) return 'Prime';
    if (value.contains('premium')) return 'Premium';
    if (value.contains('standard')) return 'Standard';
    return tier ?? 'Standard';
  }

  static bool _isAdActive(Map<String, dynamic> ad) {
    if (ad['isActive'] != true) return false;
    final endDate = ad['endDate'];
    if (endDate is Timestamp && endDate.toDate().isBefore(DateTime.now())) {
      return false;
    }
    return true;
  }

  static String? _timeRemaining(Map<String, dynamic> ad) {
    final endDate = ad['endDate'];
    if (endDate is! Timestamp) return null;
    final diff = endDate.toDate().difference(DateTime.now());
    if (diff.isNegative) return null;
    if (diff.inDays > 0) return '${diff.inDays}d left';
    if (diff.inHours > 0) return '${diff.inHours}h left';
    return '${diff.inMinutes}m left';
  }

  static double _estimateSpend(Map<String, dynamic> ad) {
    final tier = (ad['tier'] as String? ?? 'standard').toLowerCase();
    final monthly = MerchantPricingService.subscriptionTiers[tier] ??
        MerchantPricingService.subscriptionTiers['standard']!;
    final start = ad['startDate'] is Timestamp
        ? (ad['startDate'] as Timestamp).toDate()
        : null;
    final end = ad['endDate'] is Timestamp
        ? (ad['endDate'] as Timestamp).toDate()
        : null;
    if (start != null && end != null && end.isAfter(start)) {
      final months = (end.difference(start).inDays / 30).ceil().clamp(1, 24);
      return monthly * months;
    }
    return monthly;
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return const Scaffold(
        backgroundColor: PeeplMerchantTokens.background,
        body: Center(
          child: Text(
            'Not signed in.',
            style: TextStyle(color: PeeplMerchantTokens.textSecondary),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('merchants').doc(_uid).snapshots(),
      builder: (context, merchantSnap) {
        final merchantData = merchantSnap.data?.data() as Map<String, dynamic>?;
        final businessName =
            (merchantData?['businessName'] as String?) ?? 'Your Business';
        final logoUrl = merchantData?['logoUrl'] as String?;
        final accountStatus = _accountStatus(merchantData);
        final tier = _tierLabel(merchantData?['tier'] as String?);

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('native_ads')
              .where('advertiserId', isEqualTo: _uid)
              .snapshots(),
          builder: (context, adsSnap) {
            if (merchantSnap.connectionState == ConnectionState.waiting ||
                adsSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: PeeplMerchantTokens.background,
                body: MerchantDashboardSkeleton(),
              );
            }

            final ads = _sortedAds(adsSnap.data?.docs ?? []);
            final metrics = _computeMetrics(ads);

            return MerchantDashboardShell(
              currentSection: _section,
              onSectionChanged: _onSectionChanged,
              onCreatePressed: _openCreate,
              onAnalyticsPressed: _openAnalytics,
              header: _section == MerchantShellSection.dashboard
                  ? MerchantDashboardHeader(
                      businessName: businessName,
                      logoUrl: logoUrl,
                      merchantId: _uid,
                      isVerified: accountStatus == 'Active',
                      subscriptionLabel: '$tier Plan',
                      onBack: () => Navigator.pop(context),
                      onSettings: () => setState(
                        () => _section = MerchantShellSection.account,
                      ),
                    )
                  : _CompactHeader(
                      title: _sectionTitle(_section),
                      onBack: () => setState(
                        () => _section = MerchantShellSection.dashboard,
                      ),
                    ),
              body: _buildSectionBody(
                section: _section,
                ads: ads,
                metrics: metrics,
                businessName: businessName,
              ),
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _sortedAds(List<QueryDocumentSnapshot> docs) {
    return docs
        .map(
          (d) => <String, dynamic>{
            'id': d.id,
            ...d.data() as Map<String, dynamic>,
          },
        )
        .toList()
      ..sort((a, b) {
        final aEnd = a['endDate'] is Timestamp
            ? (a['endDate'] as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bEnd = b['endDate'] is Timestamp
            ? (b['endDate'] as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        return bEnd.compareTo(aEnd);
      });
  }

  _DashboardMetrics _computeMetrics(List<Map<String, dynamic>> ads) {
    final totalImpressions = ads.fold<int>(
      0,
      (t, ad) => t + ((ad['impressions'] as num?)?.toInt() ?? 0),
    );
    final totalClicks = ads.fold<int>(
      0,
      (t, ad) => t + ((ad['clicks'] as num?)?.toInt() ?? 0),
    );
    final ctr = totalImpressions > 0
        ? (totalClicks / totalImpressions) * 100
        : 0.0;
    final activeCount = ads.where(_isAdActive).length;
    final activeAds = ads.where(_isAdActive).toList();
    final spendToday = activeAds.fold<double>(
      0,
      (t, ad) => t + _estimateSpend(ad) / 30,
    );
    final totalViews = ads.fold<int>(
      0,
      (t, ad) => t + ((ad['impressions'] as num?)?.toInt() ?? 0),
    );
    final reachEstimate = activeAds.isNotEmpty
        ? MerchantPricingService.estimatedAudience(
            _radiusMilesFromAd(activeAds.first),
          )
        : 0;
    final radius = activeAds.isNotEmpty
        ? ((activeAds.first['targetLocation'] as String?) ?? '1.0 mi')
        : '1.0 mi';

    return _DashboardMetrics(
      reach: reachEstimate,
      totalViews: totalViews,
      campaignsRunning: activeCount,
      clicks: totalClicks,
      ctr: ctr,
      spendToday: spendToday,
      radius: radius,
    );
  }

  static double _radiusMilesFromAd(Map<String, dynamic> ad) {
    final raw = ad['targetLocation'] as String? ?? '1.0';
    final match = RegExp(r'([\d.]+)').firstMatch(raw);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 1.0;
    }
    return 1.0;
  }

  static String? _formatAdDateRange(Map<String, dynamic> ad) {
    final start = ad['startDate'] is Timestamp
        ? (ad['startDate'] as Timestamp).toDate()
        : null;
    final end = ad['endDate'] is Timestamp
        ? (ad['endDate'] as Timestamp).toDate()
        : null;
    if (start == null) return null;
    String fmt(DateTime d) => '${d.month}/${d.day}/${d.year}';
    if (end == null) return fmt(start);
    return '${fmt(start)} – ${fmt(end)}';
  }

  static String? _formatLiveTimeRange(Map<String, dynamic> ad) {
    final start = ad['startDate'] is Timestamp
        ? (ad['startDate'] as Timestamp).toDate()
        : null;
    final end = ad['endDate'] is Timestamp
        ? (ad['endDate'] as Timestamp).toDate()
        : null;
    if (start == null || end == null) return null;
    String t(DateTime d) {
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final p = d.hour >= 12 ? 'PM' : 'AM';
      return '$h:00 $p';
    }
    return '${t(start)}–${t(end)}';
  }

  String _sectionTitle(MerchantShellSection section) => switch (section) {
        MerchantShellSection.dashboard => 'Dashboard',
        MerchantShellSection.campaigns => 'Campaigns',
        MerchantShellSection.calendar => 'Calendar',
        MerchantShellSection.account => 'Account',
      };

  Widget _buildSectionBody({
    required MerchantShellSection section,
    required List<Map<String, dynamic>> ads,
    required _DashboardMetrics metrics,
    required String businessName,
  }) {
    Map<String, dynamic>? activeLive;
    for (final ad in ads) {
      if (_isAdActive(ad)) {
        activeLive = ad;
        break;
      }
    }

    return switch (section) {
      MerchantShellSection.dashboard => _DashboardView(
          metrics: metrics,
          ads: ads,
          liveAd: activeLive,
          onCreate: _openCreate,
          onAnalytics: _openAnalytics,
          onBilling: () =>
              Navigator.pushNamed(context, '/merchant_account_number'),
          onCalendar: () => setState(() => _section = MerchantShellSection.calendar),
          onSeeAllCampaigns: () =>
              setState(() => _section = MerchantShellSection.campaigns),
          onViewCampaign: () =>
              setState(() => _section = MerchantShellSection.campaigns),
          onPause: _pauseAd,
        ),
      MerchantShellSection.campaigns => _CampaignsView(
          ads: ads,
          onEdit: _openCreate,
          onPause: _pauseAd,
          onResume: _resumeAd,
          onDuplicate: _openCreate,
          onAnalytics: _openAnalytics,
        ),
      MerchantShellSection.calendar => _CalendarView(
          selectedSlots: _calendarSlots,
          onSlotsChanged: (s) => setState(() => _calendarSlots
            ..clear()
            ..addAll(s)),
        ),
      MerchantShellSection.account => _AccountView(
          ads: ads,
          onProfile: () =>
              Navigator.pushNamed(context, '/merchant_account_info'),
          onBilling: () =>
              Navigator.pushNamed(context, '/merchant_account_number'),
          onRateCalculator: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MerchantRateCalculatorScreen(),
            ),
          ),
          onSignOut: _signOut,
        ),
    };
  }
}

class _DashboardMetrics {
  const _DashboardMetrics({
    required this.reach,
    required this.totalViews,
    required this.campaignsRunning,
    required this.clicks,
    required this.ctr,
    required this.spendToday,
    required this.radius,
  });

  final int reach;
  final int totalViews;
  final int campaignsRunning;
  final int clicks;
  final double ctr;
  final double spendToday;
  final String radius;
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(8, top + 8, 16, 16),
      decoration: PeeplMerchantTokens.heroGradient(),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: PeeplMerchantTokens.textPrimary),
              onPressed: onBack,
            ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: PeeplMerchantTokens.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({
    required this.metrics,
    required this.ads,
    this.liveAd,
    required this.onCreate,
    required this.onAnalytics,
    required this.onBilling,
    required this.onCalendar,
    required this.onSeeAllCampaigns,
    required this.onViewCampaign,
    required this.onPause,
  });

  final _DashboardMetrics metrics;
  final List<Map<String, dynamic>> ads;
  final Map<String, dynamic>? liveAd;
  final VoidCallback onCreate;
  final VoidCallback onAnalytics;
  final VoidCallback onBilling;
  final VoidCallback onCalendar;
  final VoidCallback onSeeAllCampaigns;
  final VoidCallback onViewCampaign;
  final Future<void> Function(String) onPause;

  @override
  Widget build(BuildContext context) {
    final live = liveAd;
    final isLive = live != null;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              MerchantLiveStatusCard(
                isLive: isLive,
                campaignTitle: (live?['headline'] as String?) ??
                    (live?['subline'] as String?),
                timeRange: live != null
                    ? _MerchantPortalScreenState._formatLiveTimeRange(live)
                    : null,
                timeRemaining: live != null
                    ? _MerchantPortalScreenState._timeRemaining(live)
                    : null,
                onPause: isLive ? () => onPause(live!['id'] as String) : null,
                onViewDetails: isLive ? onViewCampaign : null,
                onCreate: onCreate,
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            delegate: SliverChildListDelegate([
              MerchantAnimatedMetric(
                label: "Today's Spend",
                numericValue: metrics.spendToday,
                icon: Icons.payments_outlined,
              ),
              MerchantAnimatedMetric(
                label: "Today's Reach",
                numericValue: metrics.reach,
                icon: Icons.visibility_outlined,
                delay: const Duration(milliseconds: 80),
              ),
              MerchantAnimatedMetric(
                label: 'Views',
                numericValue: metrics.totalViews.toDouble(),
                icon: Icons.remove_red_eye_outlined,
                delay: const Duration(milliseconds: 120),
              ),
              MerchantAnimatedMetric(
                label: 'Clicks',
                numericValue: metrics.clicks,
                icon: Icons.touch_app_outlined,
                delay: const Duration(milliseconds: 160),
              ),
              MerchantAnimatedMetric(
                label: 'CTR',
                numericValue: metrics.ctr,
                displayValue: merchantFormatPercent(metrics.ctr),
                icon: Icons.percent_rounded,
                delay: const Duration(milliseconds: 200),
              ),
              MerchantAnimatedMetric(
                label: 'Current Radius',
                displayValue: metrics.radius,
                icon: Icons.radar_rounded,
                delay: const Duration(milliseconds: 240),
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const MerchantSectionHeader(title: 'Quick Actions'),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    MerchantQuickAction(
                      icon: Icons.add_rounded,
                      label: 'New Campaign',
                      gradient: true,
                      onTap: onCreate,
                    ),
                    const SizedBox(width: 10),
                    MerchantQuickAction(
                      icon: Icons.calendar_month_rounded,
                      label: 'Calendar',
                      onTap: onCalendar,
                    ),
                    const SizedBox(width: 10),
                    MerchantQuickAction(
                      icon: Icons.receipt_long_rounded,
                      label: 'Billing',
                      onTap: onBilling,
                    ),
                    const SizedBox(width: 10),
                    MerchantQuickAction(
                      icon: Icons.local_offer_outlined,
                      label: 'Promotions',
                      onTap: onCreate,
                    ),
                    const SizedBox(width: 10),
                    MerchantQuickAction(
                      icon: Icons.insights_rounded,
                      label: 'Analytics',
                      onTap: onAnalytics,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              MerchantSectionHeader(
                title: 'Recent Campaigns',
                actionLabel: ads.length > 3 ? 'See all' : null,
                onAction: ads.length > 3 ? onSeeAllCampaigns : null,
              ),
              const SizedBox(height: 12),
              if (ads.isEmpty)
                MerchantEmptyState(
                  variant: MerchantEmptyStateVariant.noCampaigns,
                  actionLabel: 'Create Campaign',
                  onAction: onCreate,
                )
              else
                ...ads.take(3).map(
                      (ad) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildRecentCard(ad, onPause, onCreate),
                      ),
                    ),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  static Widget _buildRecentCard(
    Map<String, dynamic> ad,
    Future<void> Function(String) onPause,
    VoidCallback onDuplicate,
  ) {
    final adId = ad['id'] as String;
    final headline = (ad['headline'] as String?) ??
        (ad['subline'] as String?) ??
        'Untitled Campaign';
    final impressions = (ad['impressions'] as num?)?.toInt() ?? 0;
    final clicks = (ad['clicks'] as num?)?.toInt() ?? 0;
    final ctr = impressions > 0 ? (clicks / impressions) * 100 : 0.0;
    final isLive = _MerchantPortalScreenState._isAdActive(ad);
    final spend = _MerchantPortalScreenState._estimateSpend(ad);

    return MerchantCampaignCard(
      compact: true,
      title: headline,
      imageUrl: ad['imageUrl'] as String?,
      dateLabel: _MerchantPortalScreenState._formatAdDateRange(ad),
      isLive: isLive,
      spend: merchantFormatCurrency(spend),
      views: impressions,
      clicks: clicks,
      ctr: ctr,
      onDuplicate: onDuplicate,
      onPause: isLive ? () => onPause(adId) : null,
    );
  }
}

class _CampaignsView extends StatelessWidget {
  const _CampaignsView({
    required this.ads,
    required this.onEdit,
    required this.onPause,
    required this.onResume,
    required this.onDuplicate,
    required this.onAnalytics,
  });

  final List<Map<String, dynamic>> ads;
  final VoidCallback onEdit;
  final Future<void> Function(String) onPause;
  final Future<void> Function(String) onResume;
  final VoidCallback onDuplicate;
  final VoidCallback onAnalytics;

  @override
  Widget build(BuildContext context) {
    if (ads.isEmpty) {
      return MerchantEmptyState(
        variant: MerchantEmptyStateVariant.noCampaigns,
        actionLabel: 'Create Campaign',
        onAction: onEdit,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: ads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final ad = ads[i];
        final adId = ad['id'] as String;
        final headline = (ad['headline'] as String?) ?? 'Untitled Campaign';
        final impressions = (ad['impressions'] as num?)?.toInt() ?? 0;
        final clicks = (ad['clicks'] as num?)?.toInt() ?? 0;
        final ctr = impressions > 0 ? (clicks / impressions) * 100 : 0.0;
        final isLive = _MerchantPortalScreenState._isAdActive(ad);
        final spend = _MerchantPortalScreenState._estimateSpend(ad);

        return MerchantCampaignCard(
          title: headline,
          imageUrl: ad['imageUrl'] as String?,
          dateLabel: _MerchantPortalScreenState._formatAdDateRange(ad),
          isLive: isLive,
          timeRemaining: _MerchantPortalScreenState._timeRemaining(ad),
          spend: merchantFormatCurrency(spend),
          views: impressions,
          clicks: clicks,
          ctr: ctr,
          costPerView: impressions > 0
              ? merchantFormatCurrency(spend / impressions)
              : '—',
          radius: (ad['targetLocation'] as String?) ?? '1.0 mi',
          onPause: isLive ? () => onPause(adId) : null,
          onResume: !isLive ? () => onResume(adId) : null,
          onEdit: onEdit,
          onDuplicate: onDuplicate,
          onDetails: onAnalytics,
        );
      },
    );
  }
}

class _CalendarView extends StatelessWidget {
  const _CalendarView({
    required this.selectedSlots,
    required this.onSlotsChanged,
  });

  final Set<DateTime> selectedSlots;
  final ValueChanged<Set<DateTime>> onSlotsChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Reserve premium time slots with live pricing and availability.',
          style: TextStyle(
            color: PeeplMerchantTokens.textSecondary.withValues(alpha: 0.95),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        MerchantCalendar(
          selectedSlots: selectedSlots,
          onSlotsChanged: onSlotsChanged,
        ),
      ],
    );
  }
}

class _AccountView extends StatelessWidget {
  const _AccountView({
    required this.ads,
    required this.onProfile,
    required this.onBilling,
    required this.onRateCalculator,
    required this.onSignOut,
  });

  final List<Map<String, dynamic>> ads;
  final VoidCallback onProfile;
  final VoidCallback onBilling;
  final VoidCallback onRateCalculator;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final notifications = _buildNotifications(ads);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (notifications.isEmpty) ...[
          MerchantEmptyState(
            variant: MerchantEmptyStateVariant.noNotifications,
          ),
          const SizedBox(height: 24),
        ] else ...[
          const MerchantSectionHeader(title: 'Notifications'),
          const SizedBox(height: 12),
          ...notifications,
          const SizedBox(height: 24),
        ],
        MerchantProfileCard(
          title: 'Merchant Profile',
          subtitle: 'Business info, verification & hours',
          leading: const Icon(Icons.storefront_rounded,
              color: PeeplMerchantTokens.accentBlue),
          onTap: onProfile,
        ),
        const SizedBox(height: 12),
        MerchantBillingCard(
          title: 'Billing',
          subtitle: 'Cards, invoices, credits & subscription',
          icon: Icons.receipt_long_rounded,
          onTap: onBilling,
        ),
        const SizedBox(height: 12),
        MerchantProfileCard(
          title: 'Rate Calculator',
          subtitle: 'Preview pricing before you purchase',
          leading: const Icon(Icons.calculate_outlined,
              color: PeeplMerchantTokens.accentBlue),
          onTap: onRateCalculator,
        ),
        const SizedBox(height: 12),
        MerchantProfileCard(
          title: 'Support',
          subtitle: 'support@peepl.app',
          leading: const Icon(Icons.headset_mic_rounded,
              color: PeeplMerchantTokens.accentBlue),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out'),
            style: TextButton.styleFrom(
              foregroundColor: PeeplMerchantTokens.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  static List<Widget> _buildNotifications(List<Map<String, dynamic>> ads) {
    final cards = <Widget>[];

    for (final ad in ads.take(6)) {
      final headline = (ad['headline'] as String?) ??
          (ad['subline'] as String?) ??
          'Campaign';
      final isLive = _MerchantPortalScreenState._isAdActive(ad);
      final endDate = ad['endDate'];
      final isExpired =
          endDate is Timestamp && endDate.toDate().isBefore(DateTime.now());

      if (isLive) {
        cards.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MerchantNotificationCard(
              type: MerchantNotificationType.campaignStarting,
              title: 'Campaign Started',
              message: headline,
              timestamp: _MerchantPortalScreenState._formatAdDateRange(ad),
            ),
          ),
        );
      } else if (isExpired) {
        cards.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MerchantNotificationCard(
              type: MerchantNotificationType.campaignCompleted,
              title: 'Campaign Completed',
              message: headline,
              timestamp: _MerchantPortalScreenState._formatAdDateRange(ad),
            ),
          ),
        );
      } else if (ad['isActive'] == false) {
        cards.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MerchantNotificationCard(
              type: MerchantNotificationType.campaignPaused,
              title: 'Campaign Paused',
              message: headline,
            ),
          ),
        );
      }
    }

    return cards.take(4).toList();
  }
}
