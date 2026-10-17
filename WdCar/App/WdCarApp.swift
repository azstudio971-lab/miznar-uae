import SwiftUI
import AVFoundation
import CarPlay

@main
struct WdCarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(AppState.shared)
                .tint(.wdAccent)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // الصوت يخرج من سماعات السيارة ويستمر في الخلفية، والفيديو قابل للبث عبر AirPlay
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo, options: [])
        try? session.setActive(true)
        _ = PlaybackManager.shared
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        WDLog.car("scene connecting role=\(connectingSceneSession.role.rawValue)")
        // التحديث 3: شاشة السيارة كشاشة خارجية (نفس آلية CarTV)
        if CarExternalDisplaySceneDelegate.roles.contains(connectingSceneSession.role.rawValue) {
            let configuration = UISceneConfiguration(name: "External Display", sessionRole: connectingSceneSession.role)
            configuration.delegateClass = CarExternalDisplaySceneDelegate.self
            return configuration
        }
        if connectingSceneSession.role == .carTemplateApplication {
            let configuration = UISceneConfiguration(name: "CarPlay", sessionRole: connectingSceneSession.role)
            configuration.delegateClass = CarSceneDelegate.self
            return configuration
        }
        // مشهد الهاتف تديره SwiftUI
        return UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    }
}
