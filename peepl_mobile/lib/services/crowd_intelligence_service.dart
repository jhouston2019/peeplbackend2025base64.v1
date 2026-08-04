import 'package:cloud_firestore/cloud_firestore.dart';

import 'debug_log_service.dart';

class CrowdIntelligenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Called on every successful post submission.
  /// Writes to venue_intelligence/{venueKey} and appends to crowd_history.
  /// Never throws — runs fire-and-forget after post succeeds.
  Future<void> recordPostIntelligence({
    required String postId,
    required String locationName,
    required double latitude,
    required double longitude,
    required int crowdScore,
    required String userId,
    int? aiEstimatedScore,
    bool? aiValidationPassed,
    double? aiValidationConfidence,
    String? aiDescription,
  }) async {
    try {
      final venueKey = _venueKey(latitude, longitude);
      final now = FieldValue.serverTimestamp();
      final hour = DateTime.now().hour;
      final weekday = DateTime.now().weekday; // 1=Mon, 7=Sun

      await _firestore
          .collection('venue_intelligence')
          .doc(venueKey)
          .collection('crowd_history')
          .add({
        'postId': postId,
        'locationName': locationName,
        'latitude': latitude,
        'longitude': longitude,
        'crowdScore': crowdScore,
        'aiEstimatedScore': aiEstimatedScore,
        'aiValidationPassed': aiValidationPassed,
        'aiValidationConfidence': aiValidationConfidence,
        'aiDescription': aiDescription,
        'userId': userId,
        'hour': hour,
        'weekday': weekday,
        'timestamp': now,
      });

      final venueRef =
          _firestore.collection('venue_intelligence').doc(venueKey);

      await _firestore.runTransaction((transaction) async {
        final venueDoc = await transaction.get(venueRef);

        if (venueDoc.exists) {
          final data = venueDoc.data()!;
          final totalReports = (data['totalReports'] as int? ?? 0) + 1;
          final currentAvg = data['averageCrowdScore'] as double? ?? 0.0;
          final newAvg =
              ((currentAvg * (totalReports - 1)) + crowdScore) / totalReports;

          final hourlyData =
              Map<String, dynamic>.from(data['hourlyAggregates'] ?? {});
          final hourKey = hour.toString();
          final hourEntry = Map<String, dynamic>.from(
              hourlyData[hourKey] ?? {'sum': 0, 'count': 0});
          hourEntry['sum'] = (hourEntry['sum'] as int) + crowdScore;
          hourEntry['count'] = (hourEntry['count'] as int) + 1;
          hourlyData[hourKey] = hourEntry;

          final weeklyData =
              Map<String, dynamic>.from(data['weekdayAggregates'] ?? {});
          final weekKey = weekday.toString();
          final weekEntry = Map<String, dynamic>.from(
              weeklyData[weekKey] ?? {'sum': 0, 'count': 0});
          weekEntry['sum'] = (weekEntry['sum'] as int) + crowdScore;
          weekEntry['count'] = (weekEntry['count'] as int) + 1;
          weeklyData[weekKey] = weekEntry;

          transaction.update(venueRef, {
            'locationName': locationName,
            'latitude': latitude,
            'longitude': longitude,
            'totalReports': totalReports,
            'averageCrowdScore': newAvg,
            'lastCrowdScore': crowdScore,
            'lastUpdated': now,
            'hourlyAggregates': hourlyData,
            'weekdayAggregates': weeklyData,
          });
        } else {
          transaction.set(venueRef, {
            'locationName': locationName,
            'latitude': latitude,
            'longitude': longitude,
            'totalReports': 1,
            'averageCrowdScore': crowdScore.toDouble(),
            'lastCrowdScore': crowdScore,
            'lastUpdated': now,
            'hourlyAggregates': {
              hour.toString(): {'sum': crowdScore, 'count': 1}
            },
            'weekdayAggregates': {
              weekday.toString(): {'sum': crowdScore, 'count': 1}
            },
          });
        }
      });

      await DebugLogService.log(
          'CROWD_INTEL', 'recorded intelligence for $venueKey');
    } catch (e) {
      await DebugLogService.log(
          'CROWD_INTEL', 'recordPostIntelligence error',
          data: {'error': e.toString()});
    }
  }

  /// Returns predicted crowd score for a venue at current hour/weekday.
  /// Returns null if insufficient data (fewer than 5 reports).
  Future<double?> getPredictedCrowdScore(
      double latitude, double longitude) async {
    try {
      final venueKey = _venueKey(latitude, longitude);
      final doc = await _firestore
          .collection('venue_intelligence')
          .doc(venueKey)
          .get();

      if (!doc.exists) return null;
      final data = doc.data()!;
      final totalReports = data['totalReports'] as int? ?? 0;
      if (totalReports < 5) return null;

      final hour = DateTime.now().hour;
      final weekday = DateTime.now().weekday;

      final hourlyData =
          Map<String, dynamic>.from(data['hourlyAggregates'] ?? {});
      final weeklyData =
          Map<String, dynamic>.from(data['weekdayAggregates'] ?? {});

      double? hourlyAvg;
      double? weeklyAvg;

      final hourEntry = hourlyData[hour.toString()];
      if (hourEntry != null) {
        final sum = hourEntry['sum'] as int;
        final count = hourEntry['count'] as int;
        if (count > 0) hourlyAvg = sum / count;
      }

      final weekEntry = weeklyData[weekday.toString()];
      if (weekEntry != null) {
        final sum = weekEntry['sum'] as int;
        final count = weekEntry['count'] as int;
        if (count > 0) weeklyAvg = sum / count;
      }

      if (hourlyAvg != null && weeklyAvg != null) {
        return (hourlyAvg * 0.7) + (weeklyAvg * 0.3);
      }
      return hourlyAvg ?? weeklyAvg ?? data['averageCrowdScore'] as double?;
    } catch (e) {
      await DebugLogService.log(
          'CROWD_INTEL', 'getPredictedCrowdScore error',
          data: {'error': e.toString()});
      return null;
    }
  }

  /// Returns true if the incoming crowd score is anomalous vs venue baseline.
  /// Anomaly threshold: score deviates more than 3 points from hourly average.
  Future<bool> isAnomalous(
      double latitude, double longitude, int crowdScore) async {
    try {
      final predicted = await getPredictedCrowdScore(latitude, longitude);
      if (predicted == null) return false;
      return (crowdScore - predicted).abs() > 3.0;
    } catch (e) {
      await DebugLogService.log('CROWD_INTEL', 'isAnomalous error',
          data: {'error': e.toString()});
      return false;
    }
  }

  String _venueKey(double latitude, double longitude) {
    final lat = (latitude * 1000).round() / 1000;
    final lng = (longitude * 1000).round() / 1000;
    return '${lat}_$lng';
  }
}
