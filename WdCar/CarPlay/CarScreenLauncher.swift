import Foundation
import Combine

/// Explicit browser presentation only. Connecting a display must never mount the
/// legacy dashboard over CarPlay's media-library templates.
final class CarScreenLauncher: ObservableObject {
    static let shared = CarScreenLauncher()
    @Published private(set) var browserRequested = false
    var isLaunching: Bool { false }
    private init() {}

    func launch() {
        guard SubscriptionStore.shared.hasAccess else { return }
        PlaybackManager.shared.stop()
        browserRequested = true
        AppState.shared.showCarScreenHelp = true
        WDLog.car("Explicit browser request; no bootstrap video is played")
    }

    func closeBrowser() { browserRequested = false }
    func externalDisplayDidConnect() {}
}
