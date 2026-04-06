import 'dart:async';

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

  late final Timer _ticker;
  int _streamKey = 0;

  @override
  void initState() {
    super.initState();
    // Drive countdown refreshes.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _countdown(dynamic ts) {
    if (ts == null) return '';
    final dt = ts is Timestamp ? ts.toDate() : null;
    if (dt == null) return '';
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'Ended';
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours.remainder(24)}h';
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    }
    if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ${diff.inSeconds.remainder(60)}s';
    }
    return '${diff.inSeconds}s';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        onPressed: () =>
            Navigator.pushNamed(context, '/merchant_setup_step1'),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(context),
            _buildStrip(context),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
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
              'Merchant Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            tooltip: 'Performance',
            onPressed: () =>
                Navigator.pushNamed(context, '/merchant_activity'),
          ),
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined,
                color: Colors.white),
            tooltip: 'Account',
            onPressed: () =>
                Navigator.pushNamed(context, '/merchant_account_info'),
          ),
        ],
      ),
    );
  }

  Widget _buildStrip(BuildContext context) {
    return Container(
      color: const Color(0xFF0D47A1),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: const Text(
        'Merchant Dashboard',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_uid.isEmpty) {
      return const Center(child: Text('Not signed in.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('native_ads')
          .where('advertiserId', isEqualTo: _uid)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];
        final ads = docs
            .map((d) => <String, dynamic>{'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList();

        final totalImpressions = ads.fold<int>(
          0,
          (s, a) => s + ((a['impressions'] as num?)?.toInt() ?? 0),
        );
        final totalClicks = ads.fold<int>(
          0,
          (s, a) => s + ((a['clicks'] as num?)?.toInt() ?? 0),
        );
        final ctr = totalImpressions > 0
            ? (totalClicks / totalImpressions) * 100
            : 0.0;

        final activeAds =
            ads.where((a) => a['isActive'] == true).toList();
        final scheduledAds = ads
            .where((a) =>
                a['isActive'] != true && a['status'] == 'approved')
            .toList();
        final pendingAds =
            ads.where((a) => a['status'] == 'pending_payment').toList();

        return RefreshIndicator(
          onRefresh: () async => setState(() => _streamKey++),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Metrics row
              Row(
                children: [
                  _MetricCard(
                    label: 'Impressions',
                    value: totalImpressions.toString(),
                  ),
                  const SizedBox(width: 8),
                  _MetricCard(
                    label: 'Clicks',
                    value: totalClicks.toString(),
                  ),
                  const SizedBox(width: 8),
                  _MetricCard(
                    label: 'CTR',
                    value: '${ctr.toStringAsFixed(1)}%',
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Pending ads
              if (pendingAds.isNotEmpty) ...[
                _sectionHeader('⏳  PENDING PAYMENT'),
                ...pendingAds.map(
                  (ad) => _AdCard(
                    ad: ad,
                    badgeLabel: 'PENDING',
                    badgeColor: Colors.orange,
                    footer: 'Awaiting payment confirmation',
                    onEdit: null,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Active ads
              _sectionHeader('🟢  ACTIVE ADS'),
              if (activeAds.isEmpty)
                _emptyCard(
                    'No active ads right now.\nTap + to launch one.')
              else
                ...activeAds.map(
                  (ad) => _AdCard(
                    ad: ad,
                    badgeLabel: 'LIVE',
                    badgeColor: Colors.red,
                    footer:
                        'Ends in ${_countdown(ad['endDate'])}',
                    onEdit: () => Navigator.pushNamed(
                        context, '/merchant_setup_step1',
                        arguments: ad),
                  ),
                ),

              const SizedBox(height: 22),

              // Scheduled ads
              _sectionHeader('📅  SCHEDULED ADS'),
              if (scheduledAds.isEmpty)
                _emptyCard('No scheduled ads.')
              else
                ...scheduledAds.map(
                  (ad) => _AdCard(
                    ad: ad,
                    badgeLabel: 'SCHEDULED',
                    badgeColor: Colors.teal,
                    footer:
                        'Starts in ${_countdown(ad['startDate'])}',
                    onEdit: () => Navigator.pushNamed(
                        context, '/merchant_setup_step1',
                        arguments: ad),
                  ),
                ),

              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey[600],
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[500], fontSize: 13),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

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
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdCard extends StatelessWidget {
  const _AdCard({
    required this.ad,
    required this.badgeLabel,
    required this.badgeColor,
    required this.footer,
    required this.onEdit,
  });

  final Map<String, dynamic> ad;
  final String badgeLabel;
  final Color badgeColor;
  final String footer;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final venueName = (ad['headline'] as String?) ?? 'Venue';
    final offerText = (ad['subline'] as String?) ?? '';
    final impressions = (ad['impressions'] as num?)?.toInt() ?? 0;
    final clicks = (ad['clicks'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            children: [
              _Badge(label: badgeLabel, color: badgeColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  footer,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ),
              if (onEdit != null)
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 32),
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      color: Color(0xFF1565C0),
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            venueName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (offerText.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              offerText,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _statChip('👁 $impressions impressions'),
              const SizedBox(width: 8),
              _statChip('👆 $clicks clicks'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
