import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local campaign templates — no backend changes required.
class MerchantCampaignTemplate {
  const MerchantCampaignTemplate({
    required this.id,
    required this.name,
    this.campaignType,
    this.headline = '',
    this.bodyText = '',
    this.ctaText = 'Get Deal',
    this.ctaUrl = '',
    this.tier = 'standard',
    this.duration = '1',
    this.radiusMiles = 1.0,
    this.targetLocation = '',
    this.imagePath,
  });

  final String id;
  final String name;
  final String? campaignType;
  final String headline;
  final String bodyText;
  final String ctaText;
  final String ctaUrl;
  final String tier;
  final String duration;
  final double radiusMiles;
  final String targetLocation;
  final String? imagePath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'campaignType': campaignType,
        'headline': headline,
        'bodyText': bodyText,
        'ctaText': ctaText,
        'ctaUrl': ctaUrl,
        'tier': tier,
        'duration': duration,
        'radiusMiles': radiusMiles,
        'targetLocation': targetLocation,
        'imagePath': imagePath,
      };

  factory MerchantCampaignTemplate.fromJson(Map<String, dynamic> json) {
    return MerchantCampaignTemplate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Template',
      campaignType: json['campaignType'] as String?,
      headline: json['headline'] as String? ?? '',
      bodyText: json['bodyText'] as String? ?? '',
      ctaText: json['ctaText'] as String? ?? 'Get Deal',
      ctaUrl: json['ctaUrl'] as String? ?? '',
      tier: json['tier'] as String? ?? 'standard',
      duration: json['duration'] as String? ?? '1',
      radiusMiles: (json['radiusMiles'] as num?)?.toDouble() ?? 1.0,
      targetLocation: json['targetLocation'] as String? ?? '',
      imagePath: json['imagePath'] as String?,
    );
  }
}

class MerchantTemplateService {
  MerchantTemplateService._();

  static const _storageKey = 'merchant_campaign_templates_v1';

  static const builtInTemplates = [
    MerchantCampaignTemplate(
      id: 'builtin_happy_hour',
      name: 'Friday Happy Hour',
      campaignType: 'Happy Hour',
      headline: 'Happy Hour',
      bodyText: '2-for-1 drinks every Friday 5–7 PM. Show this Peepl offer to redeem.',
      ctaText: 'Get Deal',
    ),
    MerchantCampaignTemplate(
      id: 'builtin_live_music',
      name: 'Saturday Live Music',
      campaignType: 'Live Music',
      headline: 'Live Music Tonight',
      bodyText: 'Live band this Saturday — reserve your table and enjoy the show.',
      ctaText: 'Visit Us',
    ),
    MerchantCampaignTemplate(
      id: 'builtin_taco_tuesday',
      name: 'Taco Tuesday',
      campaignType: 'Lunch Special',
      headline: 'Taco Tuesday',
      bodyText: '\$2 tacos all day Tuesday. Dine in or take out.',
      ctaText: 'Order Now',
    ),
    MerchantCampaignTemplate(
      id: 'builtin_sunday_brunch',
      name: 'Sunday Brunch',
      campaignType: 'Weekend Special',
      headline: 'Sunday Brunch',
      bodyText: 'Bottomless mimosas and brunch favorites every Sunday.',
      ctaText: 'Get Deal',
    ),
    MerchantCampaignTemplate(
      id: 'builtin_ladies_night',
      name: 'Ladies Night',
      campaignType: 'Ladies Night',
      headline: 'Ladies Night',
      bodyText: 'Special pricing for ladies every Thursday night.',
      ctaText: 'Visit Us',
    ),
  ];

  static Future<List<MerchantCampaignTemplate>> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    return raw
        .map((s) {
          try {
            return MerchantCampaignTemplate.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<MerchantCampaignTemplate>()
        .toList();
  }

  static Future<void> saveTemplate(MerchantCampaignTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSaved();
    final next = [
      template,
      ...existing.where((t) => t.id != template.id),
    ].take(12).toList();
    await prefs.setStringList(
      _storageKey,
      next.map((t) => jsonEncode(t.toJson())).toList(),
    );
  }

  static Future<void> deleteTemplate(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSaved();
    await prefs.setStringList(
      _storageKey,
      existing
          .where((t) => t.id != id)
          .map((t) => jsonEncode(t.toJson()))
          .toList(),
    );
  }
}
