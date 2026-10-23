import SwiftUI
import UIKit
import AVFoundation
import CarPlay
import Combine

/// Explicit UIKit scene ownership for the phone, CarPlay and external displays.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        CarPlayLaunchDiagnostics.shared.record("app-launched")
        // A media audio session is activated by PlaybackManager only when the
        // user starts real content. Launching the browser/library must not claim
        // a long-form video route with an empty player.
        _ = PlaybackManager.shared
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        CarPlayLaunchDiagnostics.shared.record("scene-request: \(session.role.rawValue)")
        WDLog.car("scene connecting role=\(session.role.rawValue)")
        if session.role == .carTemplateApplication {
            let configuration = UISceneConfiguration(name: "CarPlay", sessionRole: session.role)
            configuration.sceneClass = CPTemplateApplicationScene.self
            configuration.delegateClass = CarSceneDelegate.self
            return configuration
        }
        if CarScreenLauncher.shared.browserRequested,
           CarExternalDisplaySceneDelegate.roles.contains(session.role.rawValue) {
            let configuration = UISceneConfiguration(name: "Requested Browser Display", sessionRole: session.role)
            configuration.sceneClass = UIWindowScene.self
            configuration.delegateClass = CarExternalDisplaySceneDelegate.self
            return configuration
        }
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: session.role)
        configuration.sceneClass = UIWindowScene.self
        configuration.delegateClass = PhoneSceneDelegate.self
        return configuration
    }
}

final class PhoneSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .black
        window.rootViewController = UIHostingController(
            rootView: RootView().environmentObject(AppState.shared).tint(.wdAccent))
        self.window = window
        window.makeKeyAndVisible()
        WDLog.car("phone application scene visible")
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
    }
}
