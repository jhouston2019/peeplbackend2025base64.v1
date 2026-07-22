import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MerchantPortalScreen extends StatefulWidget {
  const MerchantPortalScreen({super.key});

  @override
  State<MerchantPortalScreen> createState() => _MerchantPortalScreenState();
}

class _MerchantPortalScreenState extends State<MerchantPortalScreen> {
  static const Color _blue = Color(0xFF1565C0);

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad paused.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not pause ad. Try again.')),
        );
      }
    }
  }

  static String _accountStatus(Map<String, dynamic>? data) {
    if (data == null) return 'Pending';
    if (data['isSuspended'] == true || data['status'] == 'suspended') {
      return 'Suspended';
    }
    if (data['isActive'] == true) return 'Active';
    return 'Pending';
  }

  static Color _accountStatusColor(String status) => switch (status) {
        'Active' => const Color(0xFF2E7D32),
        'Suspended' => const Color(0xFFC62828),
        _ => const Color(0xFFF57C00),
      };

  static String _adStatus(Map<String, dynamic> ad) {
    final endDate = ad['endDate'];
    if (endDate is Timestamp && endDate.toDate().isBefore(DateTime.now())) {
      return 'Expired';
    }
    if (ad['isActive'] == true) return 'Active';
    return 'Pending Review';
  }

  static Color _adStatusColor(String status) => switch (status) {
        'Active' => const Color(0xFF2E7D32),
        'Expired' => Colors.grey.shade600,
        _ => const Color(0xFFF57C00),
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

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: const Center(child: Text('Not signed in.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('merchants')
              .doc(_uid)
              .snapshots(),
          builder: (context, merchantSnap) {
            final merchantData =
                merchantSnap.data?.data() as Map<String, dynamic>?;
            final businessName =
                (merchantData?['businessName'] as String?) ?? 'Your Business';
            final logoUrl = merchantData?['logoUrl'] as String?;
            final accountStatus = _accountStatus(merchantData);

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('native_ads')
                  .where('advertiserId', isEqualTo: _uid)
                  .snapshots(),
              builder: (context, adsSnap) {
                if (merchantSnap.connectionState == ConnectionState.waiting ||
                    adsSnap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _blue),
                  );
                }

                final ads = (adsSnap.data?.docs ?? [])
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

                final totalImpressions = ads.fold<int>(
                  0,
                  (total, ad) =>
                      total + ((ad['impressions'] as num?)?.toInt() ?? 0),
                );
                final totalClicks = ads.fold<int>(
                  0,
                  (total, ad) =>
                      total + ((ad['clicks'] as num?)?.toInt() ?? 0),
                );
                final ctr = totalImpressions > 0
                    ? (totalClicks / totalImpressions) * 100
                    : 0.0;
                final activeAdsCount =
                    ads.where(_isAdActive).length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(
                      businessName: businessName,
                      logoUrl: logoUrl,
                      accountStatus: accountStatus,
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildStatsRow(
                            totalImpressions: totalImpressions,
                            totalClicks: totalClicks,
                            ctr: ctr,
                            activeAdsCount: activeAdsCount,
                          ),
                          const SizedBox(height: 24),
                          _sectionHeader('Active Ads'),
                          if (ads.isEmpty)
                            _emptyCard(
                              'No ads yet.\nCreate your first campaign to get started.',
                            )
                          else
                            ...ads.map(
                              (ad) => _AdListTile(
                                ad: ad,
                                onEdit: () => Navigator.pushNamed(
                                  context,
                                  '/merchant_setup_step2',
                                ),
                                onPause: () =>
                                    _pauseAd(ad['id'] as String),
                              ),
                            ),
                          const SizedBox(height: 24),
                          _actionButton(
                            label: 'Create New Ad',
                            icon: Icons.add_circle_outline,
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/merchant_setup_step2',
                            ),
                          ),
                          const SizedBox(height: 10),
                          _actionButton(
                            label: 'View Analytics',
                            icon: Icons.bar_chart_outlined,
                            outlined: true,
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/merchant_activity',
                            ),
                          ),
                          const SizedBox(height: 10),
                          _actionButton(
                            label: 'Account Settings',
                            icon: Icons.settings_outlined,
                            outlined: true,
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/merchant_account_info',
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: TextButton.icon(
                              onPressed: _signOut,
                              icon: Icon(
                                Icons.logout,
                                size: 18,
                                color: Colors.grey.shade700,
                              ),
                              label: Text(
                                'Sign Out',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader({
    required String businessName,
    required String? logoUrl,
    required String accountStatus,
  }) {
    final statusColor = _accountStatusColor(accountStatus);

    return Container(
      color: _blue,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child: logoUrl != null && logoUrl.isNotEmpty
                  ? Image.network(
                      logoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _logoPlaceholder(),
                    )
                  : _logoPlaceholder(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    accountStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoPlaceholder() {
    return ColoredBox(
      color: Colors.white.withValues(alpha: 0.2),
      child: const Icon(Icons.store, color: Colors.white, size: 28),
    );
  }

  Widget _buildStatsRow({
    required int totalImpressions,
    required int totalClicks,
    required double ctr,
    required int activeAdsCount,
  }) {
    return Column(
      children: [
        Row(
          children: [
            _MetricCard(
              label: 'Total Impressions',
              value: _formatCount(totalImpressions),
            ),
            const SizedBox(width: 10),
            _MetricCard(
              label: 'Total Clicks',
              value: _formatCount(totalClicks),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _MetricCard(
              label: 'CTR',
              value: '${ctr.toStringAsFixed(1)}%',
            ),
            const SizedBox(width: 10),
            _MetricCard(
              label: 'Active Ads',
              value: activeAdsCount.toString(),
            ),
          ],
        ),
      ],
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

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool outlined = false,
  }) {
    if (outlined) {
      return SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: _blue),
          label: Text(
            label,
            style: const TextStyle(
              color: _blue,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _blue),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdListTile extends StatelessWidget {
  const _AdListTile({
    required this.ad,
    required this.onEdit,
    required this.onPause,
  });

  final Map<String, dynamic> ad;
  final VoidCallback onEdit;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final headline = (ad['headline'] as String?) ??
        (ad['subline'] as String?) ??
        'Untitled Ad';
    final imageUrl = ad['imageUrl'] as String? ?? '';
    final impressions = (ad['impressions'] as num?)?.toInt() ?? 0;
    final clicks = (ad['clicks'] as num?)?.toInt() ?? 0;
    final tier = _MerchantPortalScreenState._tierLabel(ad['tier'] as String?);
    final status = _MerchantPortalScreenState._adStatus(ad);
    final statusColor = _MerchantPortalScreenState._adStatusColor(status);
    final canPause = status == 'Active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            headline,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tier,
                            style: const TextStyle(
                              color: Color(0xFF1565C0),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _statChip('$impressions impressions'),
                        const SizedBox(width: 8),
                        _statChip('$clicks clicks'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onEdit,
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (canPause) ...[
                const SizedBox(width: 4),
                TextButton(
                  onPressed: onPause,
                  child: Text(
                    'Pause',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return ColoredBox(
      color: Colors.grey.shade200,
      child: Icon(Icons.campaign_outlined, color: Colors.grey.shade500),
    );
  }

  Widget _statChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
      ),
    );
  }
}
