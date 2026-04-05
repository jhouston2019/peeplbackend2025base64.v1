import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../services/merchant_service.dart';
import 'merchant_portal_screen.dart';

/// Ad booking review and payment screen (Step 3 of the merchant setup flow).
///
/// Receives all ad details via constructor so it can be pushed via
/// [MaterialPageRoute] from the time-slot selection screen (Step 2):
///
/// ```dart
/// Navigator.push(context, MaterialPageRoute(builder: (_) =>
///   MerchantSetupStep3Screen(
///     adId: draft.id,
///     merchantId: currentUser.uid,
///     headline: draft.headline,
///     tier: draft.tier,
///     durationHours: selectedHours,
///   ),
/// ));
/// ```
class MerchantSetupStep3Screen extends StatefulWidget {
  final String adId;
  final String merchantId;
  final String headline;
  final String tier;
  final int durationHours;
  final String billingModel;

  const MerchantSetupStep3Screen({
    super.key,
    required this.adId,
    required this.merchantId,
    required this.headline,
    required this.tier,
    required this.durationHours,
    this.billingModel = 'flat_rate',
  });

  @override
  State<MerchantSetupStep3Screen> createState() =>
      _MerchantSetupStep3ScreenState();
}

class _MerchantSetupStep3ScreenState extends State<MerchantSetupStep3Screen> {
  bool _isProcessing = false;

  static const Color _blue = Color(0xFF1565C0);
  static const Color _green = Color(0xFF2E7D32);

  double get _estimatedTotal =>
      MerchantService.estimateFlatRate(widget.tier, widget.durationHours);

  String get _tierLabel => MerchantService.tierLabel(widget.tier);

  Future<void> _confirmAndPay() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // 1. Create PaymentIntent on the backend.
      final result = await MerchantService.createPaymentIntent(
        adId: widget.adId,
        merchantId: widget.merchantId,
        durationHours: widget.durationHours,
        tier: widget.tier,
        billingModel: widget.billingModel,
      );

      // 2. Initialise the Stripe payment sheet with the returned client secret.
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: result.clientSecret,
          merchantDisplayName: 'Peepl Ads',
          style: ThemeMode.light,
        ),
      );

      // 3. Present the payment sheet to the user.
      await Stripe.instance.presentPaymentSheet();

      // 4. Payment succeeded — navigate to the merchant portal.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your ad is scheduled!'),
            backgroundColor: _green,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const MerchantPortalScreen(),
          ),
          (route) => route.isFirst,
        );
      }
    } on MerchantServiceException catch (e) {
      _showError(e.message);
    } on StripeException catch (e) {
      // User cancelled the sheet — don't show an error, just stay on screen.
      if (e.error.code != FailureCode.Canceled) {
        _showError(e.error.localizedMessage ?? 'Payment failed. Please try again.');
      }
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: const Text(
          'Review & Pay',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStepIndicator(),
                const SizedBox(height: 24),
                _buildAdSummaryCard(),
                const SizedBox(height: 16),
                _buildPricingCard(),
                const SizedBox(height: 16),
                _buildSecurityNote(),
                const SizedBox(height: 32),
                _buildPayButton(),
                const SizedBox(height: 16),
                _buildCancelButton(),
                const SizedBox(height: 32),
              ],
            ),
          ),
          if (_isProcessing) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(3, (i) {
        final active = i == 2;
        final done = i < 2;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: done || active ? _blue : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < 2) const SizedBox(width: 4),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildAdSummaryCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_outlined, color: _blue, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Ad Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _blue,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _SummaryRow(label: 'Headline', value: widget.headline),
          const SizedBox(height: 10),
          Row(
            children: [
              _SummaryRow(label: 'Tier', value: ''),
              _TierBadge(tier: widget.tier),
            ],
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Duration',
            value: '${widget.durationHours} hour${widget.durationHours == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Billing',
            value: widget.billingModel == 'cpm' ? 'CPM (post-run)' : 'Flat rate (upfront)',
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard() {
    final hourlyRate = MerchantService.flatRateHourly[widget.tier] ?? 9.99;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, color: _blue, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Pricing',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _blue,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _PriceRow(
            label: '$_tierLabel rate',
            value: '\$${hourlyRate.toStringAsFixed(2)}/hr',
          ),
          const SizedBox(height: 8),
          _PriceRow(
            label: '× ${widget.durationHours} hour${widget.durationHours == 1 ? '' : 's'}',
            value: '',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          _PriceRow(
            label: 'Total',
            value: '\$${_estimatedTotal.toStringAsFixed(2)}',
            bold: true,
            large: true,
          ),
          if (widget.billingModel == 'cpm') ...[
            const SizedBox(height: 8),
            Text(
              'CPM campaigns are billed against actual impressions after the run ends.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Row(
      children: [
        Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Payments are processed securely by Stripe. Peepl never stores your card details.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }

  Widget _buildPayButton() {
    return FilledButton.icon(
      onPressed: _isProcessing ? null : _confirmAndPay,
      icon: const Icon(Icons.payment),
      label: Text(
        'Confirm and Pay \$${_estimatedTotal.toStringAsFixed(2)}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCancelButton() {
    return OutlinedButton(
      onPressed: _isProcessing ? null : () => Navigator.pop(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey.shade700,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: const Text('Go back'),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Processing payment…',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small helper widgets ───────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      );
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool large;
  const _PriceRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: large ? 16 : 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
              color: bold ? Colors.black87 : Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: large ? 22 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
              color: bold ? const Color(0xFF1565C0) : Colors.black87,
            ),
          ),
        ],
      );
}

class _TierBadge extends StatelessWidget {
  final String tier;
  const _TierBadge({required this.tier});

  Color get _color => switch (tier) {
        'premium' => const Color(0xFFB8860B),
        'standard' => const Color(0xFF1565C0),
        _ => const Color(0xFF546E7A),
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color.withValues(alpha: 0.4)),
        ),
        child: Text(
          MerchantService.tierLabel(tier).toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _color,
            letterSpacing: 0.8,
          ),
        ),
      );
}
