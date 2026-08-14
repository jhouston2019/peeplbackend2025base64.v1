import Foundation
import CoreLocation
import MapKit
import UserNotifications

/// Detects venue arrivals after the user has stayed ~2 minutes on-site at low
/// speed, then resolves the nearest place label (any business/POI, or a generic
/// fallback when no name exists).
class NativeGeofenceHandler: NSObject, CLLocationManagerDelegate {

    static let shared = NativeGeofenceHandler()

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private var lastProcessedLocation: CLLocation?
    private var candidate: VenueCandidate?

    private let debounceMeters: CLLocationDistance = 30
    /// User must remain within this radius of the dwell anchor.
    private let candidateRadiusMeters: CLLocationDistance = 60
    /// Must stay on-site this long before prompting.
    private let dwellRequiredSeconds: TimeInterval = 120
    /// Ignore updates while moving faster than ~7 mph.
    private let maxSpeedMetersPerSecond: CLLocationSpeed = 3.0
    /// Closest POI must be within this distance to count as "inside" the venue.
    private let maxPoiDistanceMeters: CLLocationDistance = 80
    private let venueCooldownSeconds: TimeInterval = 4 * 60 * 60
    private let lastVenueKey = "peepl_last_walk_in_venue"
    private let lastVenueTimeKey = "peepl_last_walk_in_time"

    private struct VenueCandidate {
        let anchor: CLLocation
        let firstSeen: Date
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 30
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
        candidate = nil
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
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            startContinuousLocationIfAuthorized()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        evaluateDwell(at: location)
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        guard visit.departureDate == Date.distantFuture else { return }
        let location = CLLocation(
            latitude: visit.coordinate.latitude,
            longitude: visit.coordinate.longitude
        )
        evaluateDwell(at: location, bypassDebounce: true)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[NativeGeofence] location error: \(error)")
    }

    // MARK: - Dwell detection

    private func evaluateDwell(at location: CLLocation, bypassDebounce: Bool = false) {
        if !bypassDebounce,
           let last = lastProcessedLocation,
           location.distance(from: last) < debounceMeters {
            return
        }
        lastProcessedLocation = location

        if isMovingTooFast(location) {
            if candidate != nil {
                print("[NativeGeofence] clearing dwell — user is moving")
            }
            candidate = nil
            return
        }

        if let current = candidate {
            if location.distance(from: current.anchor) > candidateRadiusMeters {
                print("[NativeGeofence] clearing dwell — left anchor area")
                candidate = VenueCandidate(anchor: location, firstSeen: Date())
                return
            }

            let elapsed = Date().timeIntervalSince(current.firstSeen)
            if elapsed < dwellRequiredSeconds {
                print("[NativeGeofence] dwelling \(Int(elapsed))s / \(Int(dwellRequiredSeconds))s")
                return
            }

            candidate = nil
            resolveVenueLabel(near: location) { [weak self] venueName, venueId in
                guard let self = self else { return }
                if self.isOnCooldown(venueId: venueId) {
                    print("[NativeGeofence] cooldown active for \(venueName)")
                    return
                }
                self.markPrompted(venueId: venueId)
                self.showWalkInNotification(venueName: venueName, venueId: venueId)
            }
            return
        }

        candidate = VenueCandidate(anchor: location, firstSeen: Date())
        print("[NativeGeofence] started dwell anchor at \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }

    private func isMovingTooFast(_ location: CLLocation) -> Bool {
        guard location.speed >= 0 else { return false }
        return location.speed > maxSpeedMetersPerSecond
    }

    /// Resolves the best available place label — any POI/business first, generic fallback OK.
    private func resolveVenueLabel(
        near location: CLLocation,
        completion: @escaping (String, String) -> Void
    ) {
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            let placemark = placemarks?.first

            if let poi = placemark?.areasOfInterest?.first, !poi.isEmpty {
                let venueId = "poi:\(poi.lowercased().replacingOccurrences(of: " ", with: "_"))"
                completion(poi, venueId)
                return
            }

            self.searchMapKitPOI(near: location) { poiName, poiId in
                if let poiName = poiName, let poiId = poiId {
                    completion(poiName, poiId)
                    return
                }

                if let placemark = placemark,
                   let named = self.namedPlace(from: placemark) {
                    let venueId = "place:\(named.lowercased().replacingOccurrences(of: " ", with: "_"))"
                    completion(named, venueId)
                    return
                }

                let venueId = self.coordinateVenueId(for: location)
                completion("this location", venueId)
            }
        }
    }

    private func namedPlace(from placemark: CLPlacemark) -> String? {
        if let name = placemark.name, !name.isEmpty, name != placemark.thoroughfare {
            return name
        }
        if let subLocality = placemark.subLocality, !subLocality.isEmpty {
            return subLocality
        }
        if let locality = placemark.locality, !locality.isEmpty {
            return locality
        }
        return nil
    }

    private func coordinateVenueId(for location: CLLocation) -> String {
        let lat = (location.coordinate.latitude * 1000).rounded() / 1000
        let lng = (location.coordinate.longitude * 1000).rounded() / 1000
        return "coord:\(lat),\(lng)"
    }

    private func searchMapKitPOI(
        near location: CLLocation,
        completion: @escaping (String?, String?) -> Void
    ) {
        let request = MKLocalSearch.Request()
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 200,
            longitudinalMeters: 200
        )
        request.resultTypes = .pointOfInterest
        // Any business or mapped POI — not limited to food/nightlife categories.
        request.pointOfInterestFilter = MKPointOfInterestFilter.includingAll

        MKLocalSearch(request: request).start { response, error in
            if let error = error {
                print("[NativeGeofence] MKLocalSearch failed: \(error)")
                completion(nil, nil)
                return
            }

            guard let items = response?.mapItems, !items.isEmpty else {
                completion(nil, nil)
                return
            }

            var best: (name: String, id: String, distance: CLLocationDistance)?

            for item in items {
                guard let name = item.name, !name.isEmpty else { continue }
                let itemLocation = CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
                let distance = location.distance(from: itemLocation)
                guard distance <= self.maxPoiDistanceMeters else { continue }

                let venueId: String
                if #available(iOS 16.0, *), let raw = item.identifier?.rawValue {
                    venueId = raw
                } else {
                    venueId = "mk:\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
                }

                if best == nil || distance < best!.distance {
                    best = (name, venueId, distance)
                }
            }

            if let best = best {
                completion(best.name, best.id)
            } else {
                completion(nil, nil)
            }
        }
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
        if venueName == "this location" {
            content.body = "How is it right now?"
        } else {
            content.body = "How's \(venueName) right now?"
        }
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
