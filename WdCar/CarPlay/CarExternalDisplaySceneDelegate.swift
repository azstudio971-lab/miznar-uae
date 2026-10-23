import UIKit
import Combine

/// The main CarPlay interface belongs to CarSceneDelegate and Apple's templates.
/// An external scene is reserved for an explicitly requested legacy browser.
/// Native media output remains system-managed; no custom dashboard is installed.
final class CarExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    static let interactiveRole = "UIWindowSceneSessionRoleExternalDisplay"
    static let nonInteractiveRole = "UIWindowSceneSessionRoleExternalDisplayNonInteractive"
    static let roles: Set<String> = [interactiveRole, nonInteractiveRole]

    var window: UIWindow?
    private weak var displayScene: UIWindowScene?
    private var observations = Set<AnyCancellable>()
    private var interactive = false

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        displayScene = scene
        interactive = session.role.rawValue != Self.nonInteractiveRole
        WDLog.car("external display connected; main navigation remains native templates")
        CarScreenLauncher.shared.$browserRequested
            .combineLatest(PlaybackManager.shared.$current)
            .receive(on: RunLoop.main)
            .sink { [weak self] requested, media in
                self?.updateBrowser(visible: requested && media == nil)
            }.store(in: &observations)
    }

    private func updateBrowser(visible: Bool) {
        guard visible, let scene = displayScene else {
            guard let window else { return }
            (window.rootViewController as? CarBrowserViewController)?.pauseForNavigation()
            window.isHidden = true
            window.rootViewController = nil
            self.window = nil
            AppState.shared.carScreenDisconnected()
            return
        }
        guard window == nil else { return }
        let browser = CarBrowserViewController()
        browser.onExitEntertainment = { CarScreenLauncher.shared.closeBrowser() }
        let window = UIWindow(windowScene: scene)
        window.backgroundColor = .black
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = browser
        self.window = window
        window.makeKeyAndVisible()
        AppState.shared.carScreenConnected(interactive: interactive)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        observations.removeAll()
        updateBrowser(visible: false)
        displayScene = nil
        CarScreenLauncher.shared.closeBrowser()
    }
}
