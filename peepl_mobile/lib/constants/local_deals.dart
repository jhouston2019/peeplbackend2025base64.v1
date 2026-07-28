/// Local merchant deal inventory for the feed banner when Firestore is empty
/// or ads lack deal-specific fields. Mirrors [backend/scripts/seed_native_ads.js].
class LocalDeals {
  LocalDeals._();

  static const List<Map<String, dynamic>> fallback = [
    {
      'id': 'local_cotto',
      'isDummy': true,
      'discount': 'Half-price wine & apps',
      'advertiser': 'Cotto — Gainesville',
      'headline': 'Cotto — Gainesville',
      'bodyText': 'Happy hour Mon–Fri 4–7pm. Half-price wine & apps.',
      'venueLat': 34.2979,
      'venueLng': -83.8241,
    },
    {
      'id': 'local_naithai',
      'isDummy': true,
      'discount': 'Free appetizer with 2 entrees',
      'advertiser': 'NaiThai Dunwoody',
      'headline': 'NaiThai Dunwoody',
      'bodyText': 'Free appetizer with 2 entrees — this week only.',
      'venueLat': 33.9462,
      'venueLng': -84.3346,
    },
    {
      'id': 'local_nearby',
      'isDummy': true,
      'discount': 'DEALS NEAR YOU',
      'advertiser': 'Local Merchants',
      'headline': '3 Deals Near You',
      'bodyText': 'Restaurants and bars near you are offering deals right now.',
    },
  ];

  /// Primary offer line for the green deal banner.
  static String discount(Map<String, dynamic> deal) {
    for (final key in [
      'discount',
      'dealHeadline',
      'bodyText',
      'body',
      'subtitle',
      'tagline',
    ]) {
      final v = deal[key] as String?;
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  /// Business / brand name for the green deal banner.
  static String advertiser(Map<String, dynamic> deal) {
    for (final key in [
      'advertiser',
      'businessName',
      'headline',
      'title',
      'brandName',
      'advertiserName',
      'venueName',
    ]) {
      final v = deal[key] as String?;
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return 'Local Merchant';
  }
}
