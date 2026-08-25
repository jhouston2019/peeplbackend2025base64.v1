import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Process-wide SearchNearby budget. Survives app restarts for the local day.
/// Matches the GCP quota of 500 SearchNearby calls per day.
class PlacesApiGuard {
  PlacesApiGuard._();

  static const dailyCap = 500;
  static const _prefPrefix = 'places_nearby_count_';

  static int _count = 0;
  static String _dayKey = '';
  static Future<void>? _loadFuture;
  static SharedPreferences? _prefs;

  static String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  static Future<void> _ensureLoaded() {
    return _loadFuture ??= () async {
      try {
        _prefs = await SharedPreferences.getInstance();
        _dayKey = _todayKey();
        _count = _prefs?.getInt('$_prefPrefix$_dayKey') ?? 0;
      } catch (e) {
        debugPrint('[PlacesApiGuard] prefs load failed: $e');
        _dayKey = _todayKey();
        _count = 0;
      }
    }();
  }

  static Future<bool> allowRequest({required String reason}) async {
    await _ensureLoaded();
    final today = _todayKey();
    if (today != _dayKey) {
      _dayKey = today;
      _count = 0;
    }
    if (_count >= dailyCap) {
      debugPrint('[PlacesApiGuard] blocked $reason ($_count/$dailyCap)');
      return false;
    }
    _count += 1;
    try {
      await _prefs?.setInt('$_prefPrefix$_dayKey', _count);
    } catch (_) {}
    debugPrint('[PlacesApiGuard] $reason $_count/$dailyCap');
    return true;
  }
}
