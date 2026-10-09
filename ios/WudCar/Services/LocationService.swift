import Foundation
import CoreLocation
import Combine

@MainActor final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()
    private let manager = CLLocationManager()
    @Published var locating = false
    @Published var error: String?
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyKilometer }
    func request() { locating = true; error = nil
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: locating = false; error = "اسمح بالموقع من إعدادات iOS، أو اختر المدينة يدوياً. / Allow location in iOS Settings or select a city."
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if locating && [.authorizedAlways, .authorizedWhenInUse].contains(manager.authorizationStatus) { manager.requestLocation() }
        else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted { locating = false }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { locating = false; self.error = error.localizedDescription }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { locating = false; return }
        Task { do {
            let place = try await CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "en_US")).first
            let state = AppState.shared
            state.preferences.latitude = location.coordinate.latitude
            state.preferences.longitude = location.coordinate.longitude
            state.preferences.city = place?.locality ?? place?.administrativeArea ?? "My location"
            state.preferences.region = place?.administrativeArea ?? ""
            state.preferences.country = place?.isoCountryCode ?? ""
            state.preferences.timezone = place?.timeZone?.identifier ?? TimeZone.current.identifier
            state.preferences.locationMode = "auto"
            await state.sync(); await state.refresh()
        } catch { self.error = error.localizedDescription }
        locating = false
        }
    }
}
