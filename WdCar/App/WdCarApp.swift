import SwiftUI
import UIKit
import AVFoundation
import CarPlay

/// Explicit UIKit scene ownership for the phone, CarPlay and external displays.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let audio = AVAudioSession.sharedInstance()
        do {
            try audio.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo, options: [])
            try audio.setActive(true)
        } catch {
            WDLog.car("Audio session setup failed: \(error.localizedDescription)")
        }
        _ = PlaybackManager.shared
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        WDLog.car("scene connecting role=\(session.role.rawValue)")
        if session.role == .carTemplateApplication {
            let configuration = UISceneConfiguration(name: "CarPlay", sessionRole: session.role)
            configuration.sceneClass = CPTemplateApplicationScene.self
            configuration.delegateClass = CarSceneDelegate.self
            return configuration
        }
        let external = CarExternalDisplaySceneDelegate.roles.contains(session.role.rawValue)
        let configuration = UISceneConfiguration(name: external ? "External Display" : "Default Configuration",
                                                 sessionRole: session.role)
        configuration.sceneClass = UIWindowScene.self
        configuration.delegateClass = external ? CarExternalDisplaySceneDelegate.self : PhoneSceneDelegate.self
        return configuration
    }
}

final class PhoneSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var externalDisplay = false

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        // Some interactive external screens arrive with the application role.
        externalDisplay = windowScene.screen !== UIScreen.main
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .black
        if externalDisplay {
            window.overrideUserInterfaceStyle = .dark
            window.rootViewController = CarBrowserViewController()
        } else {
            window.rootViewController = UIHostingController(
                rootView: RootView().environmentObject(AppState.shared).tint(.wdAccent))
        }
        self.window = window
        window.makeKeyAndVisible()
        WDLog.car("application scene visible external=\(externalDisplay)")
        if externalDisplay {
            AppState.shared.carScreenConnected(interactive: true)
            CarScreenLauncher.shared.externalDisplayDidConnect()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        if externalDisplay {
            WebViewPool.car.pauseAllMedia()
            AppState.shared.carScreenDisconnected()
        }
        window = nil
    }
}
