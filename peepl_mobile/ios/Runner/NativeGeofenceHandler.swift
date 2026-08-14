import Foundation
import CoreLocation
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

class NativeGeofenceHandler: NSObject, CLLocationManagerDelegate {

    static let shared = NativeGeofenceHandler()

    private let locationManager = CLLocationManager()
    private let placesApiKey = "AIzaSyBkJayDy4YBldg0Y5Ux7sR5Qww8am59vV8"
    private let geocoder = CLGeocoder()
    private var lastProcessedLocation: CLLocation?
    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    private var pendingVenueEntry: (venueId: String, venueName: String, latitude: Double, longitude: Double)?
    private var notificationsAuthorized = false

    /// Places search radius (meters).
    private let placesSearchRadiusMeters = 200
    /// User must be within this distance of the place center to count as "walked in".
    private let maxVenueDistanceMeters: CLLocationDistance = 150
    /// Ignore location checks closer than this to the last processed point.
    private let debounceMeters: CLLocationDistance = 30

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 25
        locationManager.pausesLocationUpdatesAutomatically = false

        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self, user != nil, let pending = self.pendingVenueEntry else { return }
            self.pendingVenueEntry = nil
            print("[NativeGeofence] auth restored — flushing pending venue entry")
            self.recordVenueEntry(
                venueId: pending.venueId,
                venueName: pending.venueName,
                latitude: pending.latitude,
                longitude: pending.longitude
            )
        }
    }

    deinit {
        if let handle = authListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func startMonitoring() {
        print("[NativeGeofence] startMonitoring called")
        requestNotificationAuthorization()
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

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            self.notificationsAuthorized = granted
            if let error = error {
                print("[NativeGeofence] notification permission error: \(error)")
            } else {
                print("[NativeGeofence] notification permission granted=\(granted)")
            }
        }
    }

    private func startContinuousLocationIfAuthorized() {
        let status = locationManager.authorizationStatus
        guard status == .authorizedAlways else {
            print("[NativeGeofence] continuous location skipped — need Always (current: \(status.rawValue))")
            return
        }
        locationManager.allowsBackgroundLocationUpdates = true
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

        // Apple reverse geocoding works without Google API keys — try first.
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }

            if let placemark = placemarks?.first {
                if let poi = placemark.areasOfInterest?.first, !poi.isEmpty {
                    print("[NativeGeofence] CLGeocoder POI: \(poi)")
                    let venueId = "poi:\(poi.lowercased().replacingOccurrences(of: " ", with: "_"))"
                    self.recordVenueEntry(
                        venueId: venueId,
                        venueName: poi,
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                    return
                }

                if let formatted = self.formattedAddress(from: placemark), !formatted.isEmpty {
                    print("[NativeGeofence] CLGeocoder address: \(formatted)")
                    let venueId = "geocode:\(formatted.lowercased().replacingOccurrences(of: " ", with: "_"))"
                    self.recordVenueEntry(
                        venueId: venueId,
                        venueName: formatted,
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                    return
                }
            }

            if let error = error {
                print("[NativeGeofence] CLGeocoder failed: \(error)")
            } else {
                print("[NativeGeofence] CLGeocoder returned no usable placemark")
            }

            self.checkForVenueEntryViaPlaces(at: location)
        }
    }

    private func formattedAddress(from placemark: CLPlacemark) -> String? {
        if let name = placemark.name, !name.isEmpty, name != placemark.thoroughfare {
            return name
        }

        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
        if !street.isEmpty {
            if let city = placemark.locality, !city.isEmpty {
                if let region = placemark.administrativeArea, !region.isEmpty {
                    return "\(street), \(city), \(region)"
                }
                return "\(street), \(city)"
            }
            return street
        }

        let parts = [placemark.subLocality, placemark.locality, placemark.administrativeArea]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private func checkForVenueEntryViaPlaces(at location: CLLocation) {
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

            print("[NativeGeofence] Places status: \(status) body: \(String(data: data, encoding: .utf8) ?? "")")

            if status == "OK",
               let results = json["results"] as? [[String: Any]],
               let match = self.closestVenue(in: results, near: location) {
                print("[NativeGeofence] venue detected: \(match.name) (\(match.id))")
                self.recordVenueEntry(
                    venueId: match.id,
                    venueName: match.name,
                    latitude: lat,
                    longitude: lng
                )
                return
            }

            if status == "OK",
               let results = json["results"] as? [[String: Any]],
               let first = results.first,
               let name = first["name"] as? String,
               let placeId = first["place_id"] as? String,
               !name.isEmpty {
                print("[NativeGeofence] using first Places result: \(name)")
                self.recordVenueEntry(
                    venueId: placeId,
                    venueName: name,
                    latitude: lat,
                    longitude: lng
                )
            } else {
                print("[NativeGeofence] no venue found for location")
            }
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

    /// Writes venue_entry_events and shows an immediate local notification.
    /// Cloud Function onVenueEntryEvent also sends FCM when deployed.
    private func recordVenueEntry(
        venueId: String,
        venueName: String,
        latitude: Double,
        longitude: Double
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[NativeGeofence] no authenticated user yet — queueing venue entry")
            pendingVenueEntry = (venueId, venueName, latitude, longitude)
            return
        }

        print("[NativeGeofence] writing venue_entry_events for \(venueName) (user \(userId))")

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
                    print("[NativeGeofence] venue_entry_events written")
                    self.showWalkInNotification(venueName: venueName, venueId: venueId)
                }
            }
    }

    private func showWalkInNotification(venueName: String, venueId: String) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized ||
                    settings.authorizationStatus == .provisional ||
                    settings.authorizationStatus == .ephemeral else {
                print("[NativeGeofence] notifications not authorized (status=\(settings.authorizationStatus.rawValue))")
                return
            }

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
                    print("[NativeGeofence] local walk-in notification delivered")
                }
            }
        }
    }
}
