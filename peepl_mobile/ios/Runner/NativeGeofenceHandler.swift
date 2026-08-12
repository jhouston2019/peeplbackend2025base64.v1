import CoreLocation
import FirebaseAuth
import FirebaseFirestore
import UIKit
import UserNotifications

final class NativeGeofenceHandler: NSObject, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  private static let regionIdentifierSeparator = "|||"
  private static let venueEntryEventsCollection = "venue_entry_events"
  private static let maxMonitoredRegions = 20

  override init() {
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false
  }

  func registerRegion(
    venueId: String,
    venueName: String,
    latitude: Double,
    longitude: Double,
    radius: Double
  ) {
    guard !venueId.isEmpty, !venueName.isEmpty else { return }

    if locationManager.monitoredRegions.count >= Self.maxMonitoredRegions {
      evictFarthestRegion()
    }

    let identifier = "\(venueId)\(Self.regionIdentifierSeparator)\(venueName)"
    let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    let region = CLCircularRegion(center: center, radius: radius, identifier: identifier)
    region.notifyOnEntry = true
    region.notifyOnExit = false
    locationManager.startMonitoring(for: region)
    print("[NativeGeofence] registerRegion: \(venueId) \(venueName) at \(latitude),\(longitude) radius:\(radius)")
    print("[NativeGeofence] monitored regions count: \(locationManager.monitoredRegions.count)")
  }

  func clearAllRegions() {
    for region in locationManager.monitoredRegions {
      locationManager.stopMonitoring(for: region)
    }
  }

  private func evictFarthestRegion() {
    let circularRegions = locationManager.monitoredRegions.compactMap { $0 as? CLCircularRegion }
    guard !circularRegions.isEmpty else { return }

    guard let currentLocation = locationManager.location else {
      locationManager.stopMonitoring(for: circularRegions[0])
      return
    }

    var farthestRegion: CLCircularRegion?
    var maxDistance: CLLocationDistance = -1

    for region in circularRegions {
      let regionLocation = CLLocation(
        latitude: region.center.latitude,
        longitude: region.center.longitude
      )
      let distance = currentLocation.distance(from: regionLocation)
      if distance > maxDistance {
        maxDistance = distance
        farthestRegion = region
      }
    }

    if let farthestRegion {
      locationManager.stopMonitoring(for: farthestRegion)
    }
  }

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    print("[NativeGeofence] didEnterRegion: \(region.identifier)")

    guard UIApplication.shared.applicationState != .active else { return }

    guard let circularRegion = region as? CLCircularRegion else { return }

    let parts = region.identifier.components(separatedBy: Self.regionIdentifierSeparator)
    guard parts.count >= 2 else { return }

    let venueId = parts[0]
    let venueName = parts.dropFirst().joined(separator: Self.regionIdentifierSeparator)
    print("[NativeGeofence] parsed venueId: \(venueId) venueName: \(venueName)")
    guard !venueId.isEmpty, !venueName.isEmpty else { return }

    guard let user = Auth.auth().currentUser else { return }
    let userId = user.uid
    print("[NativeGeofence] userId: \(userId)")

    let latitude = circularRegion.center.latitude
    let longitude = circularRegion.center.longitude

    Firestore.firestore()
      .collection(Self.venueEntryEventsCollection)
      .addDocument(data: [
        "userId": userId,
        "venueName": venueName,
        "venueId": venueId,
        "latitude": latitude,
        "longitude": longitude,
        "timestamp": FieldValue.serverTimestamp(),
        "notificationSent": false,
      ])
    print("[NativeGeofence] venue_entry_events write attempted")

    showLocalFallbackNotification(venueName: venueName)
  }

  private func showLocalFallbackNotification(venueName: String) {
    let content = UNMutableNotificationContent()
    content.title = "You just walked in 👀"
    content.body = "How's \(venueName) right now?"

    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )

    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
  }
}
