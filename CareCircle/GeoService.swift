import Foundation

// MARK: - Distance & bounding box (50km filter)

enum GeoService {
    /// Earth radius in km for Haversine.
    private static let earthRadiusKm = 6371.0

    /// Distance in km between two points (Haversine formula).
    static func distanceInKM(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let dLat = radians(from: lat2 - lat1)
        let dLon = radians(from: lon2 - lon1)
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(radians(from: lat1)) * cos(radians(from: lat2)) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusKm * c
    }

    private static func radians(from degrees: Double) -> Double {
        degrees * .pi / 180
    }

    /// Bounding box deltas for ~50km. ~0.45 degree lat ≈ 50km; at mid-lat 0.5 deg lng ≈ 40–55km.
    /// Use to query Firestore (one range on latitude), then filter longitude and exact distance in memory.
    static func boundingBoxDeltas(radiusKm: Double = 50) -> Double {
        // 50km / 111km per degree ≈ 0.45; use 0.5 to be safe for query, then Haversine filter
        50.0 / 111.0
    }

    /// Min/max lat/lng for a center point and radius (for in-memory filter or query bounds).
    static func boundingBox(lat: Double, lng: Double, radiusKm: Double = 50) -> (minLat: Double, maxLat: Double, minLng: Double, maxLng: Double) {
        let delta = radiusKm / 111.0
        let lngDelta = radiusKm / (111.0 * max(0.3, cos(lat * .pi / 180)))
        return (
            minLat: lat - delta,
            maxLat: lat + delta,
            minLng: lng - lngDelta,
            maxLng: lng + lngDelta
        )
    }
}
