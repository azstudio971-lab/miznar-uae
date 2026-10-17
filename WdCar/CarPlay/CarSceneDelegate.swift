import CarPlay
import UIKit

/// نقطة دخول CarPlay.
/// يدعم وضعين ويختار النظام المناسب حسب صلاحيات التطبيق:
/// - نافذة حرة (didConnect … to window): متصفح ود كار الكامل على شاشة السيارة.
/// - قوالب فقط (didConnect بدون نافذة): قوائم المواقع والتبويبات، والفيديو عبر AirPlay.
final class CarSceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var carWindow: CPWindow?
    private var browserController: CarBrowserViewController?
    private var templateUI: CarTemplateUI?

    // MARK: وضع النافذة الحرة — المتصفح الكامل

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController,
                                  to window: CPWindow) {
        self.interfaceController = interfaceController
        self.carWindow = window

        let controller = CarBrowserViewController()
        window.rootViewController = controller
        browserController = controller

        // قالب جذري فارغ بدون أزرار، والواجهة كلها مرسومة في النافذة
        let root = CPMapTemplate()
        root.automaticallyHidesNavigationBar = true
        root.hidesButtonsWithNavigationBar = true
        interfaceController.setRootTemplate(root, animated: false, completion: nil)

        AppState.shared.carConnected(mode: .window)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnect interfaceController: CPInterfaceController,
                                  from window: CPWindow) {
        WebViewPool.car.pauseAllMedia()
        window.rootViewController = nil
        browserController = nil
        carWindow = nil
        self.interfaceController = nil
        AppState.shared.carDisconnected()
    }

    // MARK: وضع القوالب — صلاحية CarPlay Video الرسمية

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        let ui = CarTemplateUI(interfaceController: interfaceController)
        templateUI = ui
        ui.start()
        AppState.shared.carConnected(mode: .templates)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        templateUI?.stop()
        templateUI = nil
        self.interfaceController = nil
        AppState.shared.carDisconnected()
    }
}
