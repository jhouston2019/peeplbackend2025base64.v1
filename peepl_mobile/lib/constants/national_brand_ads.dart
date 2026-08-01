/// Demo national-brand inventory for native ad slots when Firestore is empty
/// or on web preview. Each entry includes bundled imagery under [assets/ads/].
class NationalBrandAds {
  NationalBrandAds._();

  static const List<Map<String, dynamic>> all = [
    {
      'type': 'ad',
      'isDummy': true,
      'id': 'brand_cocacola',
      'advertiser': 'Coca-Cola',
      'brandName': 'Coca-Cola',
      'headline': 'Coca-Cola',
      'tagline': 'Taste the feeling',
      'subline': 'Ice-cold refreshment',
      'cta': 'Learn More',
      'ctaText': 'Learn More',
      'imageAsset': 'assets/ads/cocacola.png',
      'accentColor': 0xFFE41E2B,
      'initial': 'C',
    },
    {
      'type': 'ad',
      'isDummy': true,
      'id': 'brand_progressive',
      'advertiser': 'Progressive',
      'brandName': 'Progressive',
      'headline': 'Progressive',
      'tagline': 'Save on auto insurance',
      'subline': 'Bundle and save today',
      'cta': 'Get Quote',
      'ctaText': 'Get Quote',
      'imageAsset': 'assets/ads/progressive.png',
      'accentColor': 0xFF0077B3,
      'initial': 'P',
    },
    {
      'type': 'ad',
      'isDummy': true,
      'id': 'brand_chanel',
      'advertiser': 'Chanel',
      'brandName': 'Chanel',
      'headline': 'Chanel',
      'tagline': 'The essence of elegance',
      'subline': 'Discover the collection',
      'cta': 'Shop Now',
      'ctaText': 'Shop Now',
      'imageAsset': 'assets/ads/chanel.png',
      'accentColor': 0xFF111111,
      'initial': 'C',
    },
    {
      'type': 'ad',
      'isDummy': true,
      'id': 'brand_stella',
      'advertiser': 'Stella Artois',
      'brandName': 'Stella Artois',
      'headline': 'Stella Artois',
      'tagline': 'Reassuringly expensive',
      'subline': 'Premium Belgian lager',
      'cta': 'Learn More',
      'ctaText': 'Learn More',
      'imageAsset': 'assets/ads/stella_artois.png',
      'accentColor': 0xFFD4AF37,
      'initial': 'S',
    },
    {
      'type': 'ad',
      'isDummy': true,
      'id': 'brand_bleu_de_chanel',
      'advertiser': 'Bleu de Chanel',
      'brandName': 'Chanel',
      'headline': 'Bleu de Chanel',
      'tagline': 'She Said Yeah',
      'subline': 'The Rolling Stones',
      'cta': 'Shop Now',
      'ctaText': 'Shop Now',
      'imageAsset': 'assets/ads/bleu_de_chanel.png',
      'accentColor': 0xFF1A3A5C,
      'initial': 'B',
    },
  ];

  /// Bundled image path or remote URL for an ad map.
  static String imageSource(Map<String, dynamic> ad) {
    final asset = ad['imageAsset'] as String?;
    if (asset != null && asset.isNotEmpty) return asset;
    return (ad['imageUrl'] as String?) ?? '';
  }

  /// Primary label for [AdCard] and feed cards.
  static String headline(Map<String, dynamic> ad) {
    return (ad['headline'] as String?) ??
        (ad['advertiser'] as String?) ??
        (ad['brandName'] as String?) ??
        (ad['advertiserName'] as String?) ??
        '';
  }

  /// Secondary copy for [AdCard] and feed cards.
  static String subline(Map<String, dynamic> ad) {
    return (ad['subline'] as String?) ??
        (ad['tagline'] as String?) ??
        (ad['bodyText'] as String?) ??
        '';
  }
}
