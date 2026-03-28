// File generated/configured manually for the crowd-checker-7bd94 Firebase project.
// Do not edit the Android/iOS keys here; they are sourced from
// google-services.json and GoogleService-Info.plist respectively.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for '
          '${defaultTargetPlatform.name}. '
          'You can reconfigure this by running the FlutterFire CLI again.',
        );
    }
  }

  // Web — provided by user (Firebase Console → Project settings → Web app)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD1cbXZCQS_Bcu7kmJOcHlUZm4TxLKucJA',
    authDomain: 'crowd-checker-7bd94.firebaseapp.com',
    projectId: 'crowd-checker-7bd94',
    storageBucket: 'crowd-checker-7bd94.firebasestorage.app',
    messagingSenderId: '651814138260',
    appId: '1:651814138260:web:ee88fe618dd5d409f8df81',
    measurementId: 'G-S4LXRKYS6N',
  );

  // Android — sourced from android/app/google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAQwa6QNCaphJs6zKK06hsWkDnjq1l5Ifc',
    appId: '1:651814138260:android:2b604d859bf4e721f8df81',
    messagingSenderId: '651814138260',
    projectId: 'crowd-checker-7bd94',
    storageBucket: 'crowd-checker-7bd94.firebasestorage.app',
  );

  // iOS — sourced from ios/Runner/GoogleService-Info.plist
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBkJayDy4YBldg0Y5Ux7sR5Qww8am59vV8',
    appId: '1:651814138260:ios:bafa8ebc396a86edf8df81',
    messagingSenderId: '651814138260',
    projectId: 'crowd-checker-7bd94',
    storageBucket: 'crowd-checker-7bd94.firebasestorage.app',
    iosBundleId: 'com.peepl.app',
  );

  // macOS — uses the same keys as iOS for this project
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBkJayDy4YBldg0Y5Ux7sR5Qww8am59vV8',
    appId: '1:651814138260:ios:bafa8ebc396a86edf8df81',
    messagingSenderId: '651814138260',
    projectId: 'crowd-checker-7bd94',
    storageBucket: 'crowd-checker-7bd94.firebasestorage.app',
    iosBundleId: 'com.peepl.app',
  );
}
