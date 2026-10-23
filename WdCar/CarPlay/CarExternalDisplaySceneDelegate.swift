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
        WDLog.car("external display CONNECTED role=\(role) size=\(Int(bounds.width))x\(Int(bounds.height)) scale=\(windowScene.traitCollection.displayScale) interactive=\(role == Self.interactiveRole)")
        DiagnosticLog.recordScreens(event: "external display connected")
        DiagnosticLog.shared.markExternalDisplayConnected()

        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .black
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = CarDashboardViewController()
        window.isHidden = false
        window.makeKeyAndVisible()
        self.window = window

        AppState.shared.carScreenConnected(interactive: role == Self.interactiveRole)
        // مقطع التشغيل الذي فتح وضع الفيديو لم يعد مطلوباً بعد ظهور الشاشة
        CarScreenLauncher.shared.externalDisplayDidConnect()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        WDLog.car("external display active")
        WDLog.car("external sceneDidBecomeActive role=\(scene.session.role.rawValue)")
    }

    func sceneWillResignActive(_ scene: UIScene) {
        WDLog.car("external display will resign active")
        WDLog.car("external sceneWillResignActive role=\(scene.session.role.rawValue)")
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        WDLog.car("external display DISCONNECTED")
        WDLog.car("external sceneDidDisconnect role=\(scene.session.role.rawValue)")
        DiagnosticLog.recordScreens(event: "external display disconnected")
        WebViewPool.car.pauseAllMedia()
        window?.rootViewController = nil
        window = nil
        AppState.shared.carScreenDisconnected()
    }
}
