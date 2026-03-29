import CoreLocation
import Foundation

enum SignificantPlace: String, Codable, Sendable {
    case home
    case work
    case gym
    case other

    var displayName: String {
        switch self {
        case .home: "Home"
        case .work: "Work"
        case .gym: "Gym"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .work: "briefcase.fill"
        case .gym: "dumbbell.fill"
        case .other: "mappin"
        }
    }
}

struct DetectedPlace: Codable, Sendable {
    let latitude: Double
    let longitude: Double
    let label: SignificantPlace
    let visitCount: Int
    let averageArrivalHour: Int
    let averageDepartureHour: Int
    let lastVisited: Date
}

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let visitStorageKey = "com.aifam.visitHistory"

    var currentPlace: SignificantPlace?
    var detectedPlaces: [DetectedPlace] = []
    var isMonitoring = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        loadPlaces()
    }

    // MARK: - Start/Stop Monitoring

    func startMonitoring() {
        locationManager.startMonitoringVisits()
        isMonitoring = true
    }

    func stopMonitoring() {
        locationManager.stopMonitoringVisits()
        isMonitoring = false
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        guard visit.departureDate != .distantFuture else {
            // Still at this location — arrival only
            return
        }

        let coordinate = visit.coordinate
        let arrivalHour = Calendar.current.component(.hour, from: visit.arrivalDate)
        let departureHour = Calendar.current.component(.hour, from: visit.departureDate)

        recordVisit(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            arrivalHour: arrivalHour,
            departureHour: departureHour
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // CLVisit monitoring is best-effort — silently handle errors
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            startMonitoring()
        case .authorizedWhenInUse:
            startMonitoring()
        default:
            stopMonitoring()
        }
    }

    // MARK: - Visit Recording and Place Detection

    private func recordVisit(latitude: Double, longitude: Double, arrivalHour: Int, departureHour: Int) {
        let matchRadius: Double = 150.0 // meters

        if let existingIndex = detectedPlaces.firstIndex(where: { place in
            distance(lat1: place.latitude, lon1: place.longitude, lat2: latitude, lon2: longitude) < matchRadius
        }) {
            // Update existing place
            var place = detectedPlaces[existingIndex]
            let newCount = place.visitCount + 1
            let avgArrival = (place.averageArrivalHour * place.visitCount + arrivalHour) / newCount
            let avgDeparture = (place.averageDepartureHour * place.visitCount + departureHour) / newCount

            place = DetectedPlace(
                latitude: place.latitude,
                longitude: place.longitude,
                label: classifyPlace(visitCount: newCount, avgArrivalHour: avgArrival, avgDepartureHour: avgDeparture),
                visitCount: newCount,
                averageArrivalHour: avgArrival,
                averageDepartureHour: avgDeparture,
                lastVisited: Date()
            )
            detectedPlaces[existingIndex] = place
        } else {
            // New place
            let label = classifyPlace(visitCount: 1, avgArrivalHour: arrivalHour, avgDepartureHour: departureHour)
            let place = DetectedPlace(
                latitude: latitude,
                longitude: longitude,
                label: label,
                visitCount: 1,
                averageArrivalHour: arrivalHour,
                averageDepartureHour: departureHour,
                lastVisited: Date()
            )
            detectedPlaces.append(place)
        }

        savePlaces()
        updateCurrentPlace(latitude: latitude, longitude: longitude)
    }

    // MARK: - Place Classification

    private func classifyPlace(visitCount: Int, avgArrivalHour: Int, avgDepartureHour: Int) -> SignificantPlace {
        // Home: most visited place with evening arrivals / morning departures
        // Work: frequent visits with morning arrivals / evening departures
        // Gym: moderate visits with consistent short durations

        let isEveningArrival = avgArrivalHour >= 17 || avgArrivalHour <= 2
        let isMorningDeparture = avgDepartureHour >= 6 && avgDepartureHour <= 10
        let isMorningArrival = avgArrivalHour >= 7 && avgArrivalHour <= 10
        let isEveningDeparture = avgDepartureHour >= 16 && avgDepartureHour <= 20
        let duration = avgDepartureHour - avgArrivalHour

        if visitCount >= 10 && (isEveningArrival || isMorningDeparture) {
            return .home
        }

        if visitCount >= 5 && isMorningArrival && isEveningDeparture {
            return .work
        }

        if visitCount >= 3 && duration >= 1 && duration <= 3 {
            return .gym
        }

        return .other
    }

    private func updateCurrentPlace(latitude: Double, longitude: Double) {
        let matchRadius: Double = 150.0
        currentPlace = detectedPlaces.first { place in
            distance(lat1: place.latitude, lon1: place.longitude, lat2: latitude, lon2: longitude) < matchRadius
        }?.label
    }

    // MARK: - Persistence

    private func savePlaces() {
        if let data = try? JSONEncoder().encode(detectedPlaces) {
            UserDefaults.standard.set(data, forKey: visitStorageKey)
        }
    }

    private func loadPlaces() {
        guard let data = UserDefaults.standard.data(forKey: visitStorageKey),
              let places = try? JSONDecoder().decode([DetectedPlace].self, from: data) else { return }
        detectedPlaces = places
    }

    // MARK: - Haversine Distance

    private func distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius: Double = 6_371_000 // meters
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
            sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }
}
