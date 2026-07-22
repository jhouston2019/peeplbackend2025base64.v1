import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MerchantAccountNumberScreen extends StatefulWidget {
  const MerchantAccountNumberScreen({super.key});

  @override
  State<MerchantAccountNumberScreen> createState() =>
      _MerchantAccountNumberScreenState();
}

class _MerchantAccountNumberScreenState
    extends State<MerchantAccountNumberScreen> {
  static const Color _blue = Color(0xFF1565C0);

  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _tier;
  bool _loadingMerchant = true;
  bool _submittingWaitlist = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadMerchantPlan();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMerchantPlan() async {
    if (_uid.isEmpty) {
      if (mounted) setState(() => _loadingMerchant = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('merchants')
          .doc(_uid)
          .get();
      if (mounted) {
        setState(() {
          _tier = doc.data()?['tier'] as String?;
          _loadingMerchant = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMerchant = false);
    }
  }

  String get _tierLabel {
    final value = (_tier ?? 'standard').toLowerCase();
    if (value.contains('prime')) return 'Prime';
    if (value.contains('premium')) return 'Premium';
    return 'Standard';
  }

  int get _monthlyCost {
    final value = (_tier ?? 'standard').toLowerCase();
    if (value.contains('prime') || value.contains('premium')) return 299;
    return 99;
  }

  void _showStripeComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Stripe integration coming soon — we\'ll notify you when payments are ready!',
        ),
      ),
    );
  }

  Future<void> _submitWaitlist() async {
    if (_uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate() || _submittingWaitlist) return;

    setState(() => _submittingWaitlist = true);
    try {
      await FirebaseFirestore.instance
          .collection('merchant_waitlist')
          .doc(_uid)
          .set({
        'email': _emailCtrl.text.trim(),
        'submittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You\'re on the list — we\'ll notify you when payments are ready!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save email. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingWaitlist = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: const Text(
          'Payment & Billing',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loadingMerchant
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBetaBanner(),
                  const SizedBox(height: 24),
                  const Text(
                    'Payment & Billing Setup',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Securely connect your payment method to run ads on Peepl',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildCurrentPlanSection(),
                  const SizedBox(height: 24),
                  _buildPaymentMethodSection(),
                  const SizedBox(height: 24),
                  _buildBillingHistorySection(),
                ],
              ),
            ),
    );
  }

  Widget _buildBetaBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.celebration_outlined, color: Colors.white, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Currently in Beta — ads are free during beta period',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanSection() {
    return _sectionCard(
      title: 'Current Plan',
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.workspace_premium, color: _blue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tierLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$$_monthlyCost/month',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Beta — Free',
              style: TextStyle(
                color: Color(0xFF2E7D32),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return _sectionCard(
      title: 'Payment Method',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF635BFF), Color(0xFF7A73FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'stripe',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Stripe payments coming soon',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Secure card payments powered by Stripe will be available shortly.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _showStripeComingSoon,
              icon: const Icon(Icons.add_card),
              label: const Text('Add Payment Method'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Notify me when payments are ready',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'your@email.com',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return 'Enter your email';
                      if (!text.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submittingWaitlist ? null : _submitWaitlist,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: _submittingWaitlist
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildBillingHistorySection() {
    if (_uid.isEmpty) {
      return _sectionCard(
        title: 'Billing History',
        child: _emptyBillingState(),
      );
    }

    return _sectionCard(
      title: 'Billing History',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('billing')
            .doc(_uid)
            .collection('invoices')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: _blue),
              ),
            );
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _emptyBillingState();
          }

          return Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final amount = (data['amount'] as num?)?.toDouble() ?? 0;
              final status = (data['status'] as String?) ?? 'pending';
              final createdAt = data['createdAt'];
              String dateLabel = '';
              if (createdAt is Timestamp) {
                final dt = createdAt.toDate();
                dateLabel = '${dt.month}/${dt.day}/${dt.year}';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateLabel.isEmpty ? 'Invoice' : dateLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\$${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _blue,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _emptyBillingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No billing history yet',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
