/// Firestore: [maleFemaleRatio] and [adultKidRatio] are 0–100 (male % / adult %).
class PostCrowdFormat {
  PostCrowdFormat._();

  static String? maleFemaleLine(dynamic stored) {
    final m = _pct(stored);
    if (m == null) return null;
    return 'M/F: $m/${100 - m}';
  }

  static String? adultKidLine(dynamic stored) {
    final a = _pct(stored);
    if (a == null) return null;
    return 'A/K: $a/${100 - a}';
  }

  /// Compact "X/Y" for detail chips (label added separately).
  static String? maleFemaleShort(dynamic stored) {
    final m = _pct(stored);
    if (m == null) return null;
    return '$m/${100 - m}';
  }

  static String? adultKidShort(dynamic stored) {
    final a = _pct(stored);
    if (a == null) return null;
    return '$a/${100 - a}';
  }

  static int? _pct(dynamic v) {
    if (v == null) return null;
    final n = v is num ? v.toInt() : int.tryParse('$v');
    if (n == null) return null;
    return n.clamp(0, 100);
  }
}
