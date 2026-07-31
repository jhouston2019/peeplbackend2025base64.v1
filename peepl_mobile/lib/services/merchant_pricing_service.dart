import 'merchant_service.dart';

/// Merchant Rate Card — single source of truth for advertising pricing.
///
/// All UI pricing displays and campaign cost estimates must go through this
/// service so rate card updates propagate automatically.
class MerchantPricingService {
  MerchantPricingService._();

  // ── Base hourly slot rates (USD) ───────────────────────────────────────────

  static const standardWeekdayHourly = 12.0;
  static const standardWeekendHourly = 18.0;
  static const peakPremiumHourly = 29.99;
  static const eventBoostHourly = 39.99;
  static const pioneerLaunchHourly = 9.99;

  /// Legacy subscription tiers (monthly) — preserved for existing campaign flow.
  static const subscriptionTiers = {
    'standard': 99.0,
    'prime': 299.0,
    'premium': 299.0,
  };

  /// Radius multipliers keyed by miles.
  static final radiusMultipliers = <double, double>{
    0.5: 0.75,
    1.0: 1.0,
    1.5: 1.35,
    2.0: 1.75,
  };

  static const radiusOptions = [0.5, 1.0, 1.5, 2.0];

  /// Package duration discounts.
  static const weeklyPackageDiscount = 0.90;
  static const monthlyPackageDiscount = 0.80;
  static const quarterlyPackageDiscount = 0.70;

  /// Demand-based slot multipliers.
  static const demandMultipliers = {
    SlotDemand.available: 1.0,
    SlotDemand.filling: 1.15,
    SlotDemand.limited: 1.35,
    SlotDemand.highDemand: 1.5,
  };

  static const taxRate = 0.0; // Applied at checkout when enabled server-side.

  // ── Slot type resolution ─────────────────────────────────────────────────────

  static SlotRateType resolveSlotType(DateTime slot) {
    final hour = slot.hour;
    final isWeekend =
        slot.weekday == DateTime.saturday || slot.weekday == DateTime.sunday;

    if (_isPioneerLaunchWindow(slot)) return SlotRateType.pioneerLaunch;
    if (_isEventBoostWindow(slot)) return SlotRateType.eventBoost;
    if (_isPeakWindow(hour, isWeekend)) return SlotRateType.peakPremium;
    if (isWeekend) return SlotRateType.standardWeekend;
    return SlotRateType.standardWeekday;
  }

  static bool _isPioneerLaunchWindow(DateTime slot) {
    // Early-adopter discount: weekday mornings before noon.
    return slot.weekday >= DateTime.monday &&
        slot.weekday <= DateTime.friday &&
        slot.hour < 12;
  }

  static bool _isEventBoostWindow(DateTime slot) {
    // Friday/Saturday prime nightlife.
    return (slot.weekday == DateTime.friday || slot.weekday == DateTime.saturday) &&
        slot.hour >= 21;
  }

  static bool _isPeakWindow(int hour, bool isWeekend) {
    if (isWeekend) return hour >= 18 && hour <= 23;
    return hour >= 17 && hour <= 21;
  }

  static double baseHourlyRate(SlotRateType type) => switch (type) {
        SlotRateType.standardWeekday => standardWeekdayHourly,
        SlotRateType.standardWeekend => standardWeekendHourly,
        SlotRateType.peakPremium => peakPremiumHourly,
        SlotRateType.eventBoost => eventBoostHourly,
        SlotRateType.pioneerLaunch => pioneerLaunchHourly,
      };

  static String slotTypeLabel(SlotRateType type) => switch (type) {
        SlotRateType.standardWeekday => 'Standard Weekday',
        SlotRateType.standardWeekend => 'Standard Weekend',
        SlotRateType.peakPremium => 'Peak Premium',
        SlotRateType.eventBoost => 'Event Boost',
        SlotRateType.pioneerLaunch => 'Pioneer Launch',
      };

  // ── Dynamic pricing ──────────────────────────────────────────────────────────

  static double hourlyRateForSlot({
    required DateTime slot,
    required double radiusMiles,
    SlotDemand demand = SlotDemand.available,
  }) {
    final type = resolveSlotType(slot);
    final base = baseHourlyRate(type);
    final radiusMult = radiusMultiplier(radiusMiles);
    final demandMult = demandMultiplier(demand);
    return base * radiusMult * demandMult;
  }

  static double radiusMultiplier(double miles) =>
      radiusMultipliers[miles] ?? 1.0;

  static double demandMultiplier(SlotDemand demand) =>
      demandMultipliers[demand] ?? 1.0;

  static int estimatedAudience(double radiusMiles) {
    final base = 1200;
    return (base * radiusMultiplier(radiusMiles)).round();
  }

  static int estimatedReach(double radiusMiles, int hours) {
    return (estimatedAudience(radiusMiles) * hours * 0.35).round();
  }

  static CampaignQuote quoteHourlySlots({
    required List<DateTime> slots,
    required double radiusMiles,
    Map<DateTime, SlotDemand>? demandBySlot,
    PackageDuration package = PackageDuration.none,
  }) {
    var subtotal = 0.0;
    final lineItems = <QuoteLineItem>[];

    for (final slot in slots) {
      final demand = demandBySlot?[slot] ?? SlotDemand.available;
      if (demand == SlotDemand.soldOut) continue;
      final rate = hourlyRateForSlot(
        slot: slot,
        radiusMiles: radiusMiles,
        demand: demand,
      );
      subtotal += rate;
      lineItems.add(
        QuoteLineItem(
          label: _formatSlot(slot),
          hourlyRate: rate,
          slotType: resolveSlotType(slot),
          demand: demand,
        ),
      );
    }

    final discountRate = packageDiscountRate(package);
    final discount = subtotal * (1 - discountRate);
    final afterDiscount = subtotal - discount;
    final tax = afterDiscount * taxRate;
    final total = afterDiscount + tax;

    return CampaignQuote(
      lineItems: lineItems,
      hours: lineItems.length,
      radiusMiles: radiusMiles,
      subtotal: subtotal,
      packageDiscount: discount,
      packageLabel: packageLabel(package),
      tax: tax,
      total: total,
      estimatedReach: estimatedReach(radiusMiles, lineItems.length),
      estimatedAudience: estimatedAudience(radiusMiles),
    );
  }

  static CampaignQuote quoteSubscription({
    required String tier,
    required int months,
  }) {
    final monthly = subscriptionTiers[tier.toLowerCase()] ??
        subscriptionTiers['standard']!;
    final subtotal = monthly * months;
    PackageDuration package;
    if (months >= 3) {
      package = PackageDuration.quarterly;
    } else if (months >= 1 && months < 3) {
      package = PackageDuration.monthly;
    } else {
      package = PackageDuration.none;
    }
    final discountRate = packageDiscountRate(package);
    final discount = subtotal * (1 - discountRate);
    final afterDiscount = subtotal - discount;
    final tax = afterDiscount * taxRate;

    return CampaignQuote(
      lineItems: [],
      hours: 0,
      radiusMiles: 1.0,
      subtotal: subtotal,
      packageDiscount: discount,
      packageLabel: packageLabel(package),
      tax: tax,
      total: afterDiscount + tax,
      estimatedReach: 0,
      estimatedAudience: 0,
      subscriptionTier: tier,
      subscriptionMonths: months,
      isSubscription: true,
    );
  }

  /// Bridges legacy [MerchantService] flat-rate tiers for step-3 flow.
  static double legacyFlatRateTotal(String tier, int durationHours) =>
      MerchantService.estimateFlatRate(tier, durationHours);

  static double packageDiscountRate(PackageDuration package) => switch (package) {
        PackageDuration.weekly => weeklyPackageDiscount,
        PackageDuration.monthly => monthlyPackageDiscount,
        PackageDuration.quarterly => quarterlyPackageDiscount,
        PackageDuration.none => 1.0,
      };

  static String packageLabel(PackageDuration package) => switch (package) {
        PackageDuration.weekly => 'Weekly package',
        PackageDuration.monthly => 'Monthly package',
        PackageDuration.quarterly => 'Quarterly package',
        PackageDuration.none => 'No package',
      };

  static String formatCurrency(double amount) =>
      '\$${amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2)}';

  static String _formatSlot(DateTime slot) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final day = days[slot.weekday - 1];
    final hour = slot.hour % 12 == 0 ? 12 : slot.hour % 12;
    final period = slot.hour >= 12 ? 'PM' : 'AM';
    return '$day $hour$period';
  }

  /// Simulated demand for calendar display — replace with live inventory API.
  static SlotDemand demandForSlot(DateTime slot) {
    final hash = slot.day + slot.hour + slot.weekday;
    if (hash % 11 == 0) return SlotDemand.soldOut;
    if (hash % 7 == 0) return SlotDemand.highDemand;
    if (hash % 5 == 0) return SlotDemand.limited;
    if (hash % 3 == 0) return SlotDemand.filling;
    return SlotDemand.available;
  }
}

enum SlotRateType {
  standardWeekday,
  standardWeekend,
  peakPremium,
  eventBoost,
  pioneerLaunch,
}

enum SlotDemand {
  available,
  filling,
  limited,
  highDemand,
  soldOut,
}

enum PackageDuration { none, weekly, monthly, quarterly }

class QuoteLineItem {
  const QuoteLineItem({
    required this.label,
    required this.hourlyRate,
    required this.slotType,
    required this.demand,
  });

  final String label;
  final double hourlyRate;
  final SlotRateType slotType;
  final SlotDemand demand;
}

class CampaignQuote {
  const CampaignQuote({
    required this.lineItems,
    required this.hours,
    required this.radiusMiles,
    required this.subtotal,
    required this.packageDiscount,
    required this.packageLabel,
    required this.tax,
    required this.total,
    required this.estimatedReach,
    required this.estimatedAudience,
    this.subscriptionTier,
    this.subscriptionMonths,
    this.isSubscription = false,
  });

  final List<QuoteLineItem> lineItems;
  final int hours;
  final double radiusMiles;
  final double subtotal;
  final double packageDiscount;
  final String packageLabel;
  final double tax;
  final double total;
  final int estimatedReach;
  final int estimatedAudience;
  final String? subscriptionTier;
  final int? subscriptionMonths;
  final bool isSubscription;

  double get packageDiscountAmount => packageDiscount;
  double get afterDiscount => subtotal - packageDiscount;
}
