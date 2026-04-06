import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/merchant_service.dart';
import 'merchant_step_indicator.dart';

class MerchantSetupStep3Screen extends StatefulWidget {
  const MerchantSetupStep3Screen({
    super.key,
    this.offerText = '',
    this.venueName = '',
    this.tier = 'basic',
    this.startTime,
    this.endTime,
  });

  final String offerText;
  final String venueName;
  final String tier;
  final DateTime? startTime;
  final DateTime? endTime;

  @override
  State<MerchantSetupStep3Screen> createState() =>
      _MerchantSetupStep3ScreenState();
}

class _MerchantSetupStep3ScreenState
    extends State<MerchantSetupStep3Screen> {
  static const Color _blue = Color(0xFF1565C0);

  bool _loading = false;

  // ── Computed values ───────────────────────────────────────────────────────

  DateTime get _start =>
      widget.startTime ?? DateTime.now().add(const Duration(hours: 1));

  DateTime get _end =>
      widget.endTime ?? _start.add(const Duration(hours: 2));

  double get _durationHours =>
      _end.difference(_start).inMinutes / 60.0;

  double get _totalCost =>
      MerchantService.estimateFlatRate(widget.tier, _durationHours.ceil());

  static int _priorityFor(String tier) => switch (tier) {
        'premium' => 100,
        'standard' => 60,
        _ => 30,
      };

  String _formatDt(DateTime dt) {
    final h = dt.hour > 12
        ? dt.hour - 12
        : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final m = dt.minute.toString().padLeft(2, '0');
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}  $h:$m $ampm';
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _confirmAndPay() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final adRef = await FirebaseFirestore.instance.collection('native_ads').add({
        'advertiserId': uid,
        'headline': widget.venueName,
        'subline': widget.offerText,
        'venueName': widget.venueName,
        'tier': widget.tier,
        'priority': _priorityFor(widget.tier),
        'startDate': Timestamp.fromDate(_start),
        'endDate': Timestamp.fromDate(_end),
        'isActive': false,
        'status': 'pending_payment',
        'impressions': 0,
        'clicks': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Resolve venue coordinates from location_posts.
      try {
        final venueSnap = await FirebaseFirestore.instance
            .collection('location_posts')
            .where('locationName', isEqualTo: widget.venueName)
            .limit(1)
            .get();
        if (venueSnap.docs.isNotEmpty) {
          final d = venueSnap.docs.first.data();
          await adRef.update({
            'venueLat': d['latitude'] ?? 0.0,
            'venueLng': d['longitude'] ?? 0.0,
          });
        }
      } catch (_) {}

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/merchant_account_number',
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting ad: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Review & Submit',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                color: _blue,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: merchantStepIndicator(3),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildOrderSummary(),
                      const SizedBox(height: 16),
                      _buildContextBox(),
                      const SizedBox(height: 32),
                      _buildPayButton(),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed:
                            _loading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Text('Go back'),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_loading)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Submitting your ad…',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_outlined, color: _blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _blue,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _summaryRow('Venue', widget.venueName),
          const SizedBox(height: 10),
          _summaryRow('Offer', widget.offerText),
          const SizedBox(height: 10),
          _summaryRow('Ad tier', MerchantService.tierLabel(widget.tier)),
          const SizedBox(height: 10),
          _summaryRow('Starts', _formatDt(_start)),
          const SizedBox(height: 10),
          _summaryRow('Ends', _formatDt(_end)),
          const SizedBox(height: 10),
          _summaryRow(
            'Duration',
            '${_durationHours.toStringAsFixed(1)} hrs',
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total cost',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '\$${_totalCost.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContextBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _blue.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: _blue,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your ad will appear in the Peepl feed, Discover screen, and the ${widget.venueName} venue page — shown to users checking crowd levels near you during your chosen time slot.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.blueGrey[700],
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _confirmAndPay,
        icon: const Icon(Icons.check_circle_outline),
        label: Text(
          'Confirm and Pay  \$${_totalCost.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _whiteCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
