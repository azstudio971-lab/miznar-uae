import UIKit
import SwiftUI

/// External media routes must not replace CarPlay's native template interface.
/// The unchanged browser is mounted only following an explicit browser request.
final class CarExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {

    static let interactiveRole = "UIWindowSceneSessionRoleExternalDisplay"
    static let nonInteractiveRole = "UIWindowSceneSessionRoleExternalDisplayNonInteractive"
    static let roles: Set<String> = [interactiveRole, nonInteractiveRole]

    var window: UIWindow?
    private static weak var connectedDelegate: CarExternalDisplaySceneDelegate?
    private weak var connectedScene: UIWindowScene?
    private var interactive = false

    static func presentBrowserIfConnected() -> Bool {
        guard let delegate = connectedDelegate, delegate.connectedScene != nil else { return false }
        delegate.presentBrowser()
        return true
    }

    static func presentRelayIfConnected() -> Bool {
        guard let delegate = connectedDelegate, let scene = delegate.connectedScene else { return false }
        WebViewPool.car.pauseAllMedia()
        AppState.shared.carScreenDisconnected()
        let window = delegate.window ?? UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: RelayDisplay())
        window.backgroundColor = .black
        delegate.window = window
        window.makeKeyAndVisible()
        return true
    }

    static func returnToTemplates() {
        guard let delegate = connectedDelegate else { return }
        WebViewPool.car.pauseAllMedia()
        delegate.window?.isHidden = true
        delegate.window?.rootViewController = nil
        delegate.window = nil
        AppState.shared.carScreenDisconnected()
    }

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else {
            WDLog.car("external display: scene is not a UIWindowScene")
            return
        }
        let role = session.role.rawValue
        let bounds = windowScene.coordinateSpace.bounds
        WDLog.car("external display CONNECTED role=\(role) size=\(Int(bounds.width))x\(Int(bounds.height)) scale=\(windowScene.traitCollection.displayScale)")

        connect(to: windowScene, interactive: role == Self.interactiveRole)
    }

    func connect(to windowScene: UIWindowScene, interactive: Bool) {
        connectedScene = windowScene
        self.interactive = interactive
        Self.connectedDelegate = self
        AppState.shared.externalDisplayConnected()
        ScreenRelay.shared.monitor()
        // Connecting AirPlay or playing native media is never a browser request.
        if CarScreenLauncher.shared.isLaunching {
            presentBrowser()
            CarScreenLauncher.shared.externalDisplayDidConnect()
        }
    }

    private func presentBrowser() {
        guard let scene = connectedScene else { return }
        let window = window ?? UIWindow(windowScene: scene)
        window.backgroundColor = .black
        window.overrideUserInterfaceStyle = .dark
        if !(window.rootViewController is CarBrowserViewController) {
            let browser = CarBrowserViewController()
            browser.onExitEntertainment = { Self.returnToTemplates() }
            window.rootViewController = browser
        }
        self.window = window
        window.makeKeyAndVisible()
        AppState.shared.carScreenConnected(interactive: interactive)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        WDLog.car("external display active")
    }

    func sceneWillResignActive(_ scene: UIScene) {
        WDLog.car("external display will resign active")
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        WDLog.car("external display DISCONNECTED")
        WebViewPool.car.pauseAllMedia()
        window?.rootViewController = nil
        window = nil
        connectedScene = nil
        if Self.connectedDelegate === self { Self.connectedDelegate = nil }
        AppState.shared.externalDisplayDisconnected()
    }
}
