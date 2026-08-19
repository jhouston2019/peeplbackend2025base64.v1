import UIKit
import Flutter
import GoogleMaps
import FirebaseCore
import UserNotifications
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    FirebaseApp.configure()
    GMSServices.provideAPIKey("AIzaSyAROeS73A4uhjNjZx_mMbqUnW99M0rv31o")
    NativeGeofenceHandler.shared.startMonitoring()
    print("[NativeGeofence] AppDelegate: significant location monitoring started")
    GeneratedPluginRegistrant.register(with: self)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
