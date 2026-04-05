import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/constants.dart';

/// Client for the Peepl merchant billing API.
///
/// All monetary values returned from the server are in **US cents** to avoid
/// floating-point rounding. Convert to dollars before displaying: `amountCents / 100`.
class MerchantService {
  MerchantService._();

  static const String _base = API_BASE_URL;

  // ── Payment intent ─────────────────────────────────────────────────────────

  /// Creates a Stripe PaymentIntent on the backend and returns the
  /// [clientSecret] needed to present the payment sheet in Flutter.
  ///
  /// Throws a [MerchantServiceException] when the server returns an error or
  /// the network call fails.
  static Future<PaymentIntentResult> createPaymentIntent({
    required String adId,
    required String merchantId,
    required int durationHours,
    required String tier,
    String billingModel = 'flat_rate',
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$_base/merchant/create-payment-intent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'adId': adId,
          'merchantId': merchantId,
          'durationHours': durationHours,
          'tier': tier,
          'billing_model': billingModel,
        }),
      );

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200) {
        throw MerchantServiceException(
          data['error']?.toString() ?? 'Unknown server error',
        );
      }

      return PaymentIntentResult(
        clientSecret: data['clientSecret'] as String,
        amountCents: data['amountCents'] as int,
      );
    } on MerchantServiceException {
      rethrow;
    } catch (e) {
      debugPrint('MerchantService.createPaymentIntent error: $e');
      throw MerchantServiceException('Network error — please check your connection.');
    }
  }

  // ── Billing history ────────────────────────────────────────────────────────

  /// Returns the 50 most recent payment records for [merchantId].
  static Future<List<Map<String, dynamic>>> getBillingHistory(
    String merchantId,
  ) async {
    try {
      final resp = await http.get(
        Uri.parse('$_base/merchant/billing-history/$merchantId'),
      );
      if (resp.statusCode != 200) {
        throw MerchantServiceException('Failed to load billing history');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(
        (data['payments'] as List).map((p) => Map<String, dynamic>.from(p as Map)),
      );
    } catch (e) {
      debugPrint('MerchantService.getBillingHistory error: $e');
      return [];
    }
  }

  // ── Local helpers ──────────────────────────────────────────────────────────

  /// Flat hourly rates in USD — mirrors the backend constants.
  /// Used for display-only price previews before the server is called.
  static const Map<String, double> flatRateHourly = {
    'basic': 9.99,
    'standard': 19.99,
    'premium': 39.99,
  };

  /// Human-readable tier label.
  static String tierLabel(String tier) => switch (tier) {
        'premium' => 'Premium',
        'standard' => 'Standard',
        _ => 'Basic',
      };

  /// Calculates the flat-rate total for display purposes only.
  static double estimateFlatRate(String tier, int durationHours) {
    return (flatRateHourly[tier] ?? 9.99) * durationHours;
  }
}

// ── Value objects ──────────────────────────────────────────────────────────────

class PaymentIntentResult {
  final String clientSecret;
  final int amountCents;

  const PaymentIntentResult({
    required this.clientSecret,
    required this.amountCents,
  });

  double get amountDollars => amountCents / 100;
}

class MerchantServiceException implements Exception {
  final String message;
  const MerchantServiceException(this.message);

  @override
  String toString() => 'MerchantServiceException: $message';
}
