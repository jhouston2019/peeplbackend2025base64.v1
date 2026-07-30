import 'package:flutter/material.dart';

enum CrowdTrendDirection { down, steady, up }

/// Presentation-only crowd mapping for home feed cards.
class CrowdDisplayData {
  const CrowdDisplayData({
    required this.score,
    required this.label,
    required this.color,
    required this.filledSegments,
    this.trendLabel,
    this.trendDirection,
    this.hasLiveData = true,
  });

  const CrowdDisplayData.noData()
      : score = 0,
        label = 'No live data',
        color = const Color(0xFF9E9E9E),
        filledSegments = 0,
        trendLabel = null,
        trendDirection = null,
        hasLiveData = false;

  final int score;
  final String label;
  final Color color;
  final int filledSegments;
  final String? trendLabel;
  final CrowdTrendDirection? trendDirection;
  final bool hasLiveData;

  String get scoreText => hasLiveData ? '$score/10' : '—';

  String get semanticLabel {
    if (!hasLiveData) return 'No live crowd data available';
    final trend = trendLabel != null ? ', $trendLabel' : '';
    return 'Crowd level $score out of 10, $label$trend';
  }
}

class CrowdDisplayMapper {
  CrowdDisplayMapper._();

  static CrowdDisplayData fromScore(int? rawScore, {String? trendRaw}) {
    if (rawScore == null) return const CrowdDisplayData.noData();

    final score = rawScore.clamp(0, 10);
    return CrowdDisplayData(
      score: score,
      label: _labelForScore(score),
      color: _colorForScore(score),
      filledSegments: score,
      trendLabel: _parseTrendLabel(trendRaw),
      trendDirection: _parseTrendDirection(trendRaw),
    );
  }

  /// Reads only persisted [crowdingLevel] — never falls back to AI score.
  static CrowdDisplayData fromPost(Map<String, dynamic> post) {
    final level = post['crowdingLevel'];
    if (level == null) return const CrowdDisplayData.noData();
    if (level is! num) return const CrowdDisplayData.noData();

    final trend = post['crowdTrend'] ?? post['trend'];
    return fromScore(level.round(), trendRaw: trend?.toString());
  }

  static String _labelForScore(int score) {
    switch (score) {
      case 0:
        return 'Empty';
      case 1:
        return 'Very Quiet';
      case 2:
        return 'Quiet';
      case 3:
        return 'Light Crowd';
      case 4:
      case 5:
        return 'Moderate';
      case 6:
        return 'Moderately Busy';
      case 7:
      case 8:
        return score == 7 ? 'Busy' : 'Very Busy';
      case 9:
        return 'Very Busy';
      case 10:
        return 'Packed';
      default:
        return 'Moderate';
    }
  }

  static Color _colorForScore(int score) {
    if (score <= 2) return const Color(0xFF34C759);
    if (score == 3) return const Color(0xFF8BC34A);
    if (score <= 5) return const Color(0xFFFFC107);
    if (score <= 8) return const Color(0xFFFF9500);
    return const Color(0xFFFF3B30);
  }

  static String? _parseTrendLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower.contains('emptier') || lower.contains('clearing')) {
      return 'Getting emptier';
    }
    if (lower.contains('quieter')) return 'Getting quieter';
    if (lower.contains('steady') || lower.contains('holding')) {
      return 'Holding steady';
    }
    if (lower.contains('filling fast') || lower.contains('fill fast')) {
      return 'Filling fast';
    }
    if (lower.contains('arrive early')) return 'Arrive early';
    if (lower.contains('busier') || lower.contains('getting busy')) {
      return 'Getting busier';
    }
    return null;
  }

  static CrowdTrendDirection? _parseTrendDirection(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower.contains('↓') ||
        lower.contains('emptier') ||
        lower.contains('clearing') ||
        lower.contains('quieter')) {
      return CrowdTrendDirection.down;
    }
    if (lower.contains('↑') ||
        lower.contains('busier') ||
        lower.contains('filling') ||
        lower.contains('arrive early')) {
      return CrowdTrendDirection.up;
    }
    if (lower.contains('→') ||
        lower.contains('steady') ||
        lower.contains('holding')) {
      return CrowdTrendDirection.steady;
    }
    return null;
  }
}
