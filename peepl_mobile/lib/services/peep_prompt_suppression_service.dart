import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_config_service.dart';

/// Result of evaluating whether a venue-entry peep prompt should be suppressed.
class PeepPromptSuppressionResult {
  const PeepPromptSuppressionResult({
    required this.suppress,
    this.reason,
  });

  final bool suppress;
  final String? reason;
}

/// SharedPreferences-backed suppression for venue-entry peep prompts.
/// Thresholds are sourced from [RemoteConfigService], never hardcoded.
class PeepPromptSuppressionService {
  PeepPromptSuppressionService._();
  static final PeepPromptSuppressionService instance =
      PeepPromptSuppressionService._();

  static const _dailyCountKey = 'prompt_daily_count';
  static const _dailyDateKey = 'prompt_daily_date';

  String _lastSentKey(String venueId) => 'prompt_last_sent_$venueId';
  String _dismissedKey(String venueId) => 'prompt_dismissed_$venueId';

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<PeepPromptSuppressionResult> check(String venueId) async {
    final rc = RemoteConfigService.instance;
    if (!rc.venueEntryPromptsEnabled) {
      return const PeepPromptSuppressionResult(
        suppress: true,
        reason: 'feature_flag',
      );
    }

    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('[PeepPromptSuppression] SharedPreferences error: $e');
      return const PeepPromptSuppressionResult(
        suppress: true,
        reason: 'prefs_error',
      );
    }
    final lastMs = prefs.getInt(_lastSentKey(venueId));

    if (lastMs != null) {
      final elapsedMs = DateTime.now().millisecondsSinceEpoch - lastMs;
      final jitterMs = rc.geofenceJitterWindowSeconds * 1000;
      if (elapsedMs < jitterMs) {
        return const PeepPromptSuppressionResult(
          suppress: true,
          reason: 'jitter',
        );
      }

      final cooldownMs = rc.venueEntryCooldownMinutes * 60 * 1000;
      if (elapsedMs < cooldownMs) {
        return const PeepPromptSuppressionResult(
          suppress: true,
          reason: 'cooldown',
        );
      }
    }

    final today = _todayDateString();
    final storedDate = prefs.getString(_dailyDateKey);
    var dailyCount = prefs.getInt(_dailyCountKey) ?? 0;
    if (storedDate != today) {
      dailyCount = 0;
    }

    if (dailyCount >= rc.dailyPromptCap) {
      return const PeepPromptSuppressionResult(
        suppress: true,
        reason: 'daily_cap',
      );
    }

    return const PeepPromptSuppressionResult(suppress: false);
  }

  Future<bool> shouldSuppress(String venueId) async {
    final result = await check(venueId);
    return result.suppress;
  }

  /// Returns true when a walk-in prompt may be shown for [venueId].
  Future<bool> shouldShowPrompt(String venueId) async {
    return !(await shouldSuppress(venueId));
  }

  Future<void> recordPromptSent(String venueId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_lastSentKey(venueId), nowMs);

      final today = _todayDateString();
      final storedDate = prefs.getString(_dailyDateKey);
      var dailyCount = prefs.getInt(_dailyCountKey) ?? 0;
      if (storedDate != today) {
        dailyCount = 0;
      }
      dailyCount += 1;
      await prefs.setString(_dailyDateKey, today);
      await prefs.setInt(_dailyCountKey, dailyCount);
    } catch (e) {
      debugPrint('[PeepPromptSuppression] recordPromptSent error: $e');
    }
  }

  /// Alias for [recordPromptSent] — call after a walk-in prompt is delivered.
  Future<void> recordPromptShown(String venueId) =>
      recordPromptSent(venueId);

  Future<void> recordPromptDismissed(String venueId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey(venueId), true);
  }
}
