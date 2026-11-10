import Foundation
import MapKit

// Beyond the course: resolve published venue addresses with Apple Maps, then
// compare straight-line distances from the user's chosen address or ZIP center.
// No device-location permission is requested by this helper.
@MainActor
enum EventDistance {
    static func kilometers(event: Hackathon, latitude: Double?, longitude: Double?) -> Double? {
        guard event.format != "Online", let latitude, let longitude,
              let eventLatitude = event.latitude, let eventLongitude = event.longitude else {
            return nil
        }
        return kilometers(latitude: latitude, longitude: longitude,
                          destinationLatitude: eventLatitude, destinationLongitude: eventLongitude)
    }

    static func nearestFirst(_ events: [Hackathon], latitude: Double?, longitude: Double?) -> [Hackathon] {
        return events.sorted { first, second in
            let firstDistance = kilometers(event: first, latitude: latitude, longitude: longitude) ?? .infinity
            let secondDistance = kilometers(event: second, latitude: latitude, longitude: longitude) ?? .infinity
            if firstDistance != secondDistance {
                return firstDistance < secondDistance
            }
            if first.startDate != second.startDate {
                return first.startDate < second.startDate
            }
            return first.sourceID < second.sourceID
        }
    }

    // The caller saves its modelContext after this operation completes.
    // A failed venue remains unknown and sorts after known physical venues.
    @discardableResult
    static func resolveMissingCoordinates(in events: [Hackathon]) async -> Int {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 42.351, longitude: -71.105),
            span: MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 0.9)
        )
        var resolved = 0
        for event in events {
            if Task.isCancelled { return resolved }
            guard event.format != "Online", !event.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            if let latitude = event.latitude, let longitude = event.longitude,
               valid(latitude: latitude, longitude: longitude) {
                continue
            }
            let address = event.address
            guard let request = MKGeocodingRequest(addressString: address) else {
                print("ERROR: Could not create venue geocoding request: \(address)")
                continue
            }
            request.preferredLocale = Locale(identifier: "en_US")
            request.region = region
            do {
                let items = try await request.mapItems
                if Task.isCancelled { return resolved }
                // A source refresh can replace the venue while Apple is searching.
                guard event.address == address, event.format != "Online" else { continue }
                guard let coordinate = items.first?.location.coordinate,
                      valid(latitude: coordinate.latitude, longitude: coordinate.longitude),
                      (42.0...42.8).contains(coordinate.latitude),
                      (-71.6 ... -70.7).contains(coordinate.longitude) else {
                    print("ERROR: No confirmed Boston-area map result for venue: \(address)")
                    continue
                }
                event.latitude = coordinate.latitude
                event.longitude = coordinate.longitude
                resolved += 1
            } catch {
                if Task.isCancelled { return resolved }
                print("ERROR: Could not locate venue \(address): \(error.localizedDescription)")
            }
        }
        return resolved
    }

    // Pure distance math is separate so it can be checked with known coordinates.
    nonisolated static func kilometers(latitude: Double, longitude: Double,
                                       destinationLatitude: Double, destinationLongitude: Double) -> Double? {
        guard valid(latitude: latitude, longitude: longitude),
              valid(latitude: destinationLatitude, longitude: destinationLongitude) else {
            return nil
        }
        let radians = Double.pi / 180
        let firstLatitude = latitude * radians
        let secondLatitude = destinationLatitude * radians
        let latitudeDelta = (destinationLatitude - latitude) * radians
        let longitudeDelta = (destinationLongitude - longitude) * radians
        let value = pow(sin(latitudeDelta / 2), 2) + cos(firstLatitude) * cos(secondLatitude) * pow(sin(longitudeDelta / 2), 2)
        let bounded = min(1, max(0, value))
        return 6_371.0088 * 2 * asin(sqrt(bounded))
    }

    nonisolated private static func valid(latitude: Double, longitude: Double) -> Bool {
        return latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}
