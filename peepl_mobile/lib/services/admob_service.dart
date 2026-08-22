import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdmobService {
  static const String _nativeAdUnitId =
      'ca-app-pub-3424798179321670/2698199537';
  static const String _testNativeAdUnitId =
      'ca-native-demo-app-pub-3940256099942544/3986624511';

  static String get nativeAdUnitId => _testNativeAdUnitId;

  static Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: [
            '33BE2250B43518CCDA7DE426D04EE231',
          ],
        ),
      );
    } catch (e) {
      debugPrint('[AdmobService] initialize error: $e');
    }
  }
}
