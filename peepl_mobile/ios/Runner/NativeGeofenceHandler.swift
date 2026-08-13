import Foundation
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

class NativeGeofenceHandler: NSObject, CLLocationManagerDelegate {

    static let shared = NativeGeofenceHandler()
    private let locationManager = CLLocationManager()
    private let placesApiKey = "AIzaSyBkJayDy4YBldg0Y5Ux7sR5Qww8am59vV8"
    private var lastProcessedLocation: CLLocation?

    /// Places search radius (meters).
    private let placesSearchRadiusMeters = 150
    /// User must be within this distance of the place center to count as "walked in".
    private let maxVenueDistanceMeters: CLLocationDistance = 50
    /// Ignore location checks closer than this to the last processed point.
    private let debounceMeters: CLLocationDistance = 30

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 40
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = true
    }

    func startMonitoring() {
        print("[NativeGeofence] startMonitoring called")
        locationManager.requestAlwaysAuthorization()
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startMonitoringVisits()
        startContinuousLocationIfAuthorized()
        print("[NativeGeofence] visit + significant location monitoring started")
    }

    func stopMonitoring() {
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.stopMonitoringVisits()
        locationManager.stopUpdatingLocation()
    }

    private func startContinuousLocationIfAuthorized() {
        let status = locationManager.authorizationStatus
        guard status == .authorizedAlways else {
            print("[NativeGeofence] continuous location skipped — need Always (current: \(status.rawValue))")
            return
        }
        locationManager.startUpdatingLocation()
        print("[NativeGeofence] continuous location updates started")
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("[NativeGeofence] authorization changed: \(status.rawValue)")
        if status == .authorizedAlways {
            startContinuousLocationIfAuthorized()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        print("[NativeGeofence] location update: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        checkForVenueEntry(at: location)
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        guard visit.departureDate == Date.distantFuture else {
            print("[NativeGeofence] visit departure ignored")
            return
        }
        let location = CLLocation(
            latitude: visit.coordinate.latitude,
            longitude: visit.coordinate.longitude
        )
        print("[NativeGeofence] visit arrival at \(location.coordinate.latitude), \(location.coordinate.longitude)")
        checkForVenueEntry(at: location, bypassDebounce: true)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[NativeGeofence] location error: \(error)")
    }

    // MARK: - Venue Detection

    private func checkForVenueEntry(at location: CLLocation, bypassDebounce: Bool = false) {
        if !bypassDebounce,
           let last = lastProcessedLocation,
           location.distance(from: last) < debounceMeters {
            print("[NativeGeofence] debounced — too close to last check")
            return
        }
        lastProcessedLocation = location

        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude

        guard let url = URL(
            string: "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(lat),\(lng)&radius=\(placesSearchRadiusMeters)&type=establishment&key=\(placesApiKey)"
        ) else { return }

        print("[NativeGeofence] querying Places at \(lat),\(lng)")

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String else {
                print("[NativeGeofence] Places request failed: \(error?.localizedDescription ?? "unknown")")
                return
            }

            print("[NativeGeofence] Places status: \(status)")

            guard status == "OK",
                  let results = json["results"] as? [[String: Any]],
                  let match = self.closestVenue(in: results, near: location) else {
                print("[NativeGeofence] no venue within \(self.maxVenueDistanceMeters)m")
                return
            }

            print("[NativeGeofence] venue detected: \(match.name) (\(match.id))")
            self.recordVenueEntry(
                venueId: match.id,
                venueName: match.name,
                latitude: lat,
                longitude: lng
            )
        }.resume()
    }

    private struct VenueMatch {
        let id: String
        let name: String
    }

    private func closestVenue(
        in results: [[String: Any]],
        near location: CLLocation
    ) -> VenueMatch? {
        var best: (match: VenueMatch, distance: CLLocationDistance)?

        for result in results {
            guard let name = result["name"] as? String,
                  !name.isEmpty,
                  let placeId = result["place_id"] as? String,
                  let geometry = result["geometry"] as? [String: Any],
                  let loc = geometry["location"] as? [String: Any],
                  let placeLat = loc["lat"] as? Double,
                  let placeLng = loc["lng"] as? Double else {
                continue
            }

            let placeLocation = CLLocation(latitude: placeLat, longitude: placeLng)
            let distance = location.distance(from: placeLocation)
            guard distance <= maxVenueDistanceMeters else { continue }

            if best == nil || distance < best!.distance {
                best = (VenueMatch(id: placeId, name: name), distance)
            }
        }

        return best?.match
    }

    /// Writes venue_entry_events — Cloud Function onVenueEntryEvent sends the FCM push.
    private func recordVenueEntry(
        venueId: String,
        venueName: String,
        latitude: Double,
        longitude: Double
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[NativeGeofence] no authenticated user — skipping venue entry")
            return
        }

        print("[NativeGeofence] writing venue_entry_events for \(venueName)")

        Firestore.firestore()
            .collection("venue_entry_events")
            .addDocument(data: [
                "userId": userId,
                "venueName": venueName,
                "venueId": venueId,
                "latitude": latitude,
                "longitude": longitude,
                "timestamp": FieldValue.serverTimestamp(),
                "notificationSent": false,
            ]) { error in
                if let error = error {
                    print("[NativeGeofence] Firestore write failed: \(error)")
                } else {
                    print("[NativeGeofence] venue_entry_events written — FCM push queued")
                }
            }
    }
}
