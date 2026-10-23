import Foundation
import Combine
import UIKit

/// Explicit browser presentation only. Connecting a display must never mount the
/// legacy dashboard over CarPlay's media-library templates.
final class CarScreenLauncher: ObservableObject {
    static let shared = CarScreenLauncher()
    @Published private(set) var browserRequested = false
    var isLaunching: Bool { false }
    private var requestedDisplay: CarExternalDisplaySceneDelegate?
    private init() {}

    func launch() {
        guard SubscriptionStore.shared.hasAccess else { return }
        PlaybackManager.shared.stop()
        browserRequested = true
        // Use an app-owned external scene only if the system has supplied one.
        // Never draw a WebView into CPWindow or create a video to acquire a route.
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.screen !== UIScreen.main }) {
            let display = CarExternalDisplaySceneDelegate()
            requestedDisplay = display
            display.connect(to: scene, interactive: scene.session.role.rawValue != CarExternalDisplaySceneDelegate.nonInteractiveRole)
        }
        AppState.shared.showCarScreenHelp = true
        WDLog.car("Explicit browser request; no bootstrap video is played")
    }

    func closeBrowser() {
        browserRequested = false
        requestedDisplay?.closeBrowserPresentation()
        requestedDisplay = nil
    }
    func externalDisplayDidConnect() {}
}
