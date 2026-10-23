import CarPlay
import UIKit

/// Audio/video apps use template scenes. A CPWindow/CPMapTemplate belongs to navigation apps.
final class CarSceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var templateUI: CarTemplateUI?

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        CarPlayLaunchDiagnostics.shared.record("template-connected")
        WDLog.car("CarPlay template scene connected")
        self.interfaceController = interfaceController
        let ui = CarTemplateUI(interfaceController: interfaceController)
        templateUI = ui
        AppState.shared.carConnected(mode: .templates)
        ui.start()
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        WDLog.car("CarPlay template scene disconnected")
        CarScreenLauncher.shared.closeBrowser()
        PlaybackManager.shared.carDisconnected()
        templateUI?.stop()
        templateUI = nil
        self.interfaceController = nil
        AppState.shared.carDisconnected()
    }
}

