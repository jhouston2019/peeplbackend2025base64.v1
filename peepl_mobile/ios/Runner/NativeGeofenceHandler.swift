import Foundation
import CoreLocation
import UserNotifications

/// Detects venue arrivals using on-device location + geocoding, then shows a
/// local notification immediately. No Firebase, no network, no Cloud Functions.
class NativeGeofenceHandler: NSObject, CLLocationManagerDelegate {

    static let shared = NativeGeofenceHandler()

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastProcessedLocation: CLLocation?

    private let debounceMeters: CLLocationDistance = 40
    private let venueCooldownSeconds: TimeInterval = 4 * 60 * 60
    private let lastVenueKey = "peepl_last_walk_in_venue"
    private let lastVenueTimeKey = "peepl_last_walk_in_time"

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 25
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func startMonitoring() {
        print("[NativeGeofence] startMonitoring")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[NativeGeofence] notification permission error: \(error)")
            } else {
                print("[NativeGeofence] notification permission granted=\(granted)")
            }
        }

        locationManager.requestAlwaysAuthorization()
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startMonitoringVisits()
        startContinuousLocationIfAuthorized()
    }

    func stopMonitoring() {
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.stopMonitoringVisits()
        locationManager.stopUpdatingLocation()
    }

    private func startContinuousLocationIfAuthorized() {
        let status = locationManager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            print("[NativeGeofence] location not authorized (status=\(status.rawValue))")
            return
        }
        if status == .authorizedAlways {
            locationManager.allowsBackgroundLocationUpdates = true
        }
        locationManager.startUpdatingLocation()
        print("[NativeGeofence] location updates started")
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("[NativeGeofence] authorization changed: \(status.rawValue)")
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            startContinuousLocationIfAuthorized()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        checkForVenueEntry(at: location)
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        guard visit.departureDate == Date.distantFuture else { return }
        let location = CLLocation(
            latitude: visit.coordinate.latitude,
            longitude: visit.coordinate.longitude
        )
        checkForVenueEntry(at: location, bypassDebounce: true)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[NativeGeofence] location error: \(error)")
    }

    // MARK: - Venue detection

    private func checkForVenueEntry(at location: CLLocation, bypassDebounce: Bool = false) {
        if !bypassDebounce,
           let last = lastProcessedLocation,
           location.distance(from: last) < debounceMeters {
            return
        }
        lastProcessedLocation = location

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }

            if let error = error {
                print("[NativeGeofence] geocode failed: \(error)")
                return
            }

            guard let placemark = placemarks?.first,
                  let venueName = self.venueName(from: placemark),
                  !venueName.isEmpty else {
                print("[NativeGeofence] geocode returned no usable label")
                return
            }

            let venueId = venueName.lowercased()
            if self.isOnCooldown(venueId: venueId) {
                print("[NativeGeofence] cooldown active for \(venueName)")
                return
            }

            self.markPrompted(venueId: venueId)
            self.showWalkInNotification(venueName: venueName, venueId: venueId)
        }
    }

    private func venueName(from placemark: CLPlacemark) -> String? {
        if let poi = placemark.areasOfInterest?.first, !poi.isEmpty {
            return poi
        }

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

    private func isOnCooldown(venueId: String) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: lastVenueKey) == venueId else { return false }
        let lastTime = defaults.double(forKey: lastVenueTimeKey)
        guard lastTime > 0 else { return false }
        return Date().timeIntervalSince1970 - lastTime < venueCooldownSeconds
    }

    private func markPrompted(venueId: String) {
        let defaults = UserDefaults.standard
        defaults.set(venueId, forKey: lastVenueKey)
        defaults.set(Date().timeIntervalSince1970, forKey: lastVenueTimeKey)
    }

    private func showWalkInNotification(venueName: String, venueId: String) {
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
                print("[NativeGeofence] notification failed: \(error)")
            } else {
                print("[NativeGeofence] notification delivered for \(venueName)")
            }
        }
    }
}
