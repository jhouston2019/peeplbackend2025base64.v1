import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class AdmobService {
  static const String _nativeAdUnitId = 'ca-app-pub-3424798179321670/2698199537';
  static const String _testNativeAdUnitId = 'ca-native-demo-app-pub-3940256099942544/3986624511';

  static String get nativeAdUnitId {
    // Use test ID until AdMob app review is complete
    return _testNativeAdUnitId;
  }

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }
}
