import CoreLocation
import Combine

/// يراقب سرعة السيارة ليوقف الفيديو أثناء القيادة (يعمل فقط والسيارة متصلة).
final class DrivingMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = DrivingMonitor()

    @Published private(set) var isMoving = false

    private let manager = CLLocationManager()
    private var running = false
    private var movingSamples = 0
    private var stillSamples = 0

    /// فوق هذه السرعة (متر/ثانية ≈ 9 كم/س) تُعتبر السيارة متحركة
    private let movingSpeed: CLLocationSpeed = 2.5

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .automotiveNavigation
    }

    var shouldBlockVideo: Bool { isMoving && WDSettings.lockVideoWhileDriving }

    func start() {
        guard !running else { return }
        running = true
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    func stop() {
        running = false
        manager.stopUpdatingLocation()
        movingSamples = 0
        stillSamples = 0
        isMoving = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if running { manager.startUpdatingLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.speed >= 0 else { return }
        if location.speed > movingSpeed {
            movingSamples += 1
            stillSamples = 0
        } else {
            stillSamples += 1
            movingSamples = 0
        }
        if movingSamples >= 2, !isMoving { isMoving = true }
        if stillSamples >= 3, isMoving { isMoving = false }
    }
}
