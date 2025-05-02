import Foundation
import CoreLocation
import Combine

class RunManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentPace: Double = 0.0          // in min/km
    @Published var averagePace: Double = 0.0          // in min/km
    @Published var distance: Double = 0.0             // in meters
    @Published var elapsedTime: TimeInterval = 0.0    // in seconds

    private var locationManager: CLLocationManager = CLLocationManager()
    private var timer: Timer?
    public var startTime: Date?
    private var lastLocation: CLLocation?
    private var paceSamples: [Double] = []
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Start & Stop

    func startRun() {
        startTime = Date()
        elapsedTime = 0
        distance = 0
        paceSamples.removeAll()
        currentPace = 0
        averagePace = 0
        lastLocation = nil

        locationManager.startUpdatingLocation()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateElapsedTime()
        }
    }

    func stopRun() {
        timer?.invalidate()
        locationManager.stopUpdatingLocation()
    }

    private func updateElapsedTime() {
        guard let start = startTime else { return }
        elapsedTime = Date().timeIntervalSince(start)
        updateAveragePace()
    }

    private func updateAveragePace() {
        let totalMinutes = elapsedTime / 60
        averagePace = totalMinutes > 0 ? (distance / 1000) > 0 ? totalMinutes / (distance / 1000) : 0 : 0
    }

    // MARK: - CLLocationDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last, newLocation.horizontalAccuracy >= 0 else { return }

        if let last = lastLocation {
            let delta = newLocation.distance(from: last)
            distance += delta

            let timeDelta = newLocation.timestamp.timeIntervalSince(last.timestamp)
            if timeDelta > 0 {
                let speed = delta / timeDelta // m/s
                let pace = speed > 0 ? (1000 / 60) / speed : 0
                paceSamples.append(pace)

                let smoothedPace = paceSamples.suffix(5).reduce(0, +) / Double(min(5, paceSamples.count))
                currentPace = smoothedPace
            }
        }

        lastLocation = newLocation
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }
}

