import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

class NativeGeofenceHandler: NSObject, CLLocationManagerDelegate {

    static let shared = NativeGeofenceHandler()
    private let locationManager = CLLocationManager()
    private let placesApiKey = "AIzaSyBkJayDy4YBldg0Y5Ux7sR5Qww8am59vV8"
    private var lastProcessedLocation: CLLocation?
    private var lastVenueEntryTime: [String: Date] = [:]
    private let cooldownMinutes: Double = 240

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func startMonitoring() {
        print("[NativeGeofence] startMonitoring called")
        locationManager.requestAlwaysAuthorization()
        locationManager.startMonitoringSignificantLocationChanges()
        print("[NativeGeofence] significant location monitoring started")
    }

    func stopMonitoring() {
        locationManager.stopMonitoringSignificantLocationChanges()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        print("[NativeGeofence] location update: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        checkForVenueEntry(at: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[NativeGeofence] location error: \(error)")
    }

    // MARK: - Venue Detection

    private func checkForVenueEntry(at location: CLLocation) {
        // Debounce — ignore if we just processed a nearby location
        if let last = lastProcessedLocation,
           location.distance(from: last) < 50 {
            print("[NativeGeofence] debounced — too close to last check")
            return
        }
        lastProcessedLocation = location

        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude

        guard let url = URL(string: "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(lat),\(lng)&radius=50&type=establishment&key=\(placesApiKey)") else { return }

        print("[NativeGeofence] querying Places at \(lat),\(lng)")

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String else {
                print("[NativeGeofence] Places request failed: \(error?.localizedDescription ?? "unknown")")
                return
            }

            print("[NativeGeofence] Places status: \(status)")

            guard status == "OK",
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let venueName = first["name"] as? String,
                  let placeId = first["place_id"] as? String else {
                print("[NativeGeofence] no venue found at location")
                return
            }

            print("[NativeGeofence] venue detected: \(venueName) (\(placeId))")
            self.handleVenueEntry(venueId: placeId, venueName: venueName, latitude: lat, longitude: lng)
        }.resume()
    }

    private func handleVenueEntry(venueId: String, venueName: String, latitude: Double, longitude: Double) {
        // Check cooldown
        if let lastEntry = lastVenueEntryTime[venueId],
           Date().timeIntervalSince(lastEntry) < cooldownMinutes * 60 {
            print("[NativeGeofence] cooldown active for \(venueName)")
            return
        }

        guard let userId = Auth.auth().currentUser?.uid else {
            print("[NativeGeofence] no authenticated user")
            return
        }

        lastVenueEntryTime[venueId] = Date()

        print("[NativeGeofence] writing venue_entry_events for \(venueName)")

        let db = Firestore.firestore()
        db.collection("venue_entry_events").addDocument(data: [
            "userId": userId,
            "venueName": venueName,
            "venueId": venueId,
            "latitude": latitude,
            "longitude": longitude,
            "timestamp": FieldValue.serverTimestamp(),
            "notificationSent": false
        ]) { error in
            if let error = error {
                print("[NativeGeofence] Firestore write failed: \(error)")
            } else {
                print("[NativeGeofence] venue_entry_events written successfully")
            }
        }

        // Show local fallback notification
        let content = UNMutableNotificationContent()
        content.title = "You just walked in 👀"
        content.body = "How's \(venueName) right now?"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "venue_entry_\(venueId)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NativeGeofence] local notification failed: \(error)")
            } else {
                print("[NativeGeofence] local notification scheduled")
            }
        }
    }
}
