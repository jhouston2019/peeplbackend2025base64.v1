import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Firebase Remote Config wrapper for growth / geofence feature flags.
/// Fails silently and falls back to hardcoded defaults.
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  static const _defaults = <String, dynamic>{
    'venue_entry_prompts_enabled': true,
    'venue_entry_cooldown_minutes': 240,
    'daily_prompt_cap': 3,
    'geofence_jitter_window_seconds': 30,
    'post_peep_share_prompt_enabled': true,
    'debug_logging_enabled': false,
    'public_social_sharing_enabled': false,
  };

  FirebaseRemoteConfig? _remoteConfig;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: kDebugMode
              ? Duration.zero
              : const Duration(hours: 1),
        ),
      );

      await _remoteConfig!.setDefaults(_defaults);
      await _remoteConfig!.fetchAndActivate();
    } catch (e) {
      debugPrint('[RemoteConfigService] init failed (using defaults): $e');
    } finally {
      _initialized = true;
    }
  }

  FirebaseRemoteConfig get _rc => _remoteConfig ?? FirebaseRemoteConfig.instance;

  bool get venueEntryPromptsEnabled =>
      _rc.getBool('venue_entry_prompts_enabled');

  int get venueEntryCooldownMinutes =>
      _rc.getInt('venue_entry_cooldown_minutes');

  int get dailyPromptCap => _rc.getInt('daily_prompt_cap');

  int get geofenceJitterWindowSeconds =>
      _rc.getInt('geofence_jitter_window_seconds');

  bool get postPeepSharePromptEnabled =>
      _rc.getBool('post_peep_share_prompt_enabled');

  bool get debugLoggingEnabled => _rc.getBool('debug_logging_enabled');

  bool get publicSocialSharingEnabled =>
      _rc.getBool('public_social_sharing_enabled');

  Future<void> fetchAndActivate() async {
    try {
      await _rc.fetchAndActivate();
    } catch (e) {
      debugPrint('[RemoteConfigService] fetch failed: $e');
    }
  }
}
