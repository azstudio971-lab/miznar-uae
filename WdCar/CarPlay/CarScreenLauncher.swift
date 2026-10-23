import Foundation

/// Browser launch no longer plays an unrelated intro to acquire a video surface.
/// The legacy external-display browser is retained for compatibility and requires
/// separate platform/review validation; it is not a media-video transport.
final class CarScreenLauncher {
    static let shared = CarScreenLauncher()
    private(set) var isLaunching = false
    private init() {}
    func launch() {
        AppState.shared.showCarScreenHelp = true
        WDLog.car("Browser external display requested; no bootstrap video is played")
    }
    func externalDisplayDidConnect() {}
}
