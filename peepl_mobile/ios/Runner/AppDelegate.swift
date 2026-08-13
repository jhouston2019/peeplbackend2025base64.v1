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
    GMSServices.provideAPIKey("AIzaSyBkJayDy4YBldg0Y5Ux7sR5Qww8am59vV8")
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
