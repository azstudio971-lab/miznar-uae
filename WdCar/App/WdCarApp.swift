import SwiftUI
import UIKit
import AVFoundation
import CarPlay

/// Keep a SwiftUI application scene available for sessions restored from earlier releases.
@main
struct WdCarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup {
            DisplayRootView().environmentObject(AppState.shared).tint(.wdAccent)
        }
    }
}

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
        if CarExternalDisplaySceneDelegate.roles.contains(session.role.rawValue) {
            let configuration = UISceneConfiguration(name: "External Display", sessionRole: session.role)
            configuration.sceneClass = UIWindowScene.self
            configuration.delegateClass = CarExternalDisplaySceneDelegate.self
            return configuration
        }
        // SwiftUI owns new phone scenes. Keep PhoneSceneDelegate below for existing UIKit sessions.
        return UISceneConfiguration(name: nil, sessionRole: session.role)
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
        #if DEBUG
        let preview = ProcessInfo.processInfo.arguments.contains("--car-ui-preview")
        externalDisplay = externalDisplay || preview
        #else
        let preview = false
        #endif
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .black
        if externalDisplay {
            window.overrideUserInterfaceStyle = .dark
            window.rootViewController = CarDashboardViewController()
        } else {
            window.rootViewController = UIHostingController(
                rootView: RootView().environmentObject(AppState.shared).tint(.wdAccent))
        }
        self.window = window
        window.makeKeyAndVisible()
        WDLog.car("application scene visible external=\(externalDisplay)")
        if externalDisplay && !preview {
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

/// Also handles an external screen supplied with the ordinary application scene role.
private struct DisplayRootView: View {
    @State private var external = false
    private var preview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--car-ui-preview")
        #else
        false
        #endif
    }
    var body: some View {
        Group {
            if external || preview { CarDashboardHost() } else { RootView() }
        }
        .background(ScreenProbe { value in
            guard external != value else { return }
            external = value
            if value {
                AppState.shared.carScreenConnected(interactive: true)
                CarScreenLauncher.shared.externalDisplayDidConnect()
            }
        })
        .onDisappear {
            if external { WebViewPool.car.pauseAllMedia(); AppState.shared.carScreenDisconnected() }
        }
    }
}
private struct CarDashboardHost: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CarDashboardViewController { CarDashboardViewController() }
    func updateUIViewController(_ uiViewController: CarDashboardViewController, context: Context) {}
}
private struct ScreenProbe: UIViewRepresentable {
    let report: (Bool) -> Void
    func makeUIView(context: Context) -> ProbeView { let view = ProbeView(); view.report = report; return view }
    func updateUIView(_ uiView: ProbeView, context: Context) { uiView.report = report }
    final class ProbeView: UIView {
        var report: ((Bool) -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window else { return }
            let external = window.windowScene?.screen !== UIScreen.main
            DispatchQueue.main.async { [weak self] in self?.report?(external) }
        }
    }
}
