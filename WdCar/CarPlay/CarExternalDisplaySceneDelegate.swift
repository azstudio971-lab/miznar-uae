import UIKit

/// التحديث 3 — نفس آلية CarTV:
/// مع ميزة الفيديو في CarPlay (iOS 26.4+) تظهر شاشة السيارة للتطبيق كـ «شاشة خارجية» عبر AirPlay.
/// عندما يُنشئ النظام هذا المشهد نرسم عليه متصفح ود كار الكامل (تبويبات، كيبورد، ملء شاشة الفيديو).
final class CarExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {

    static let interactiveRole = "UIWindowSceneSessionRoleExternalDisplay"
    static let nonInteractiveRole = "UIWindowSceneSessionRoleExternalDisplayNonInteractive"
    static let roles: Set<String> = [interactiveRole, nonInteractiveRole]

    var window: UIWindow?

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

        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .black
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = CarBrowserViewController()
        window.isHidden = false
        if role == Self.interactiveRole { window.makeKeyAndVisible() }
        self.window = window

        AppState.shared.carScreenConnected(interactive: role == Self.interactiveRole)
        // مقطع التشغيل الذي فتح وضع الفيديو لم يعد مطلوباً بعد ظهور الشاشة
        CarScreenLauncher.shared.externalDisplayDidConnect()
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
        AppState.shared.carScreenDisconnected()
    }
}
