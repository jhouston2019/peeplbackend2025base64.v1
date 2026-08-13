import UIKit
import Flutter
import GoogleMaps
import FirebaseCore
import UserNotifications
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate {

  private let nativeGeofenceHandler = NativeGeofenceHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    FirebaseApp.configure()
    GMSServices.provideAPIKey("AIzaSyBkJayDy4YBldg0Y5Ux7sR5Qww8am59vV8")
    print("[NativeGeofence] AppDelegate: handler initialized")
    GeneratedPluginRegistrant.register(with: self)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    application.registerForRemoteNotifications()

    let locationManager = CLLocationManager()
    if locationManager.authorizationStatus == .notDetermined {
      locationManager.requestAlwaysAuthorization()
    }

    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    setupGeofenceChannel()
    return didFinish
  }

  private func setupGeofenceChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      print("[NativeGeofence] AppDelegate: FlutterViewController not ready — channel NOT registered")
      return
    }

    let geofenceChannel = FlutterMethodChannel(
      name: "com.peepl.geofence/native",
      binaryMessenger: controller.binaryMessenger
    )

    geofenceChannel.setMethodCallHandler { [weak self] call, result in
      guard let handler = self?.nativeGeofenceHandler else {
        result(
          FlutterError(
            code: "HANDLER_UNAVAILABLE",
            message: "Native geofence handler is not available",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case "registerRegion":
        guard let args = call.arguments as? [String: Any],
              let venueId = args["venueId"] as? String,
              let venueName = args["venueName"] as? String,
              let latitude = args["latitude"] as? Double,
              let longitude = args["longitude"] as? Double,
              let radius = args["radius"] as? Double else {
          result(
            FlutterError(
              code: "INVALID_ARGS",
              message: "Missing or invalid registerRegion arguments",
              details: nil
            )
          )
          return
        }

        handler.registerRegion(
          venueId: venueId,
          venueName: venueName,
          latitude: latitude,
          longitude: longitude,
          radius: radius
        )
        result(true)

      case "clearRegions":
        handler.clearAllRegions()
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
    print("[NativeGeofence] AppDelegate: MethodChannel registered")
  }
}
