import CarPlay
import UIKit

/// Audio/video apps use template scenes. A CPWindow/CPMapTemplate belongs to navigation apps.
final class CarSceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var templateUI: CarTemplateUI?

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        WDLog.car("CarPlay template scene connected")
        DiagnosticLog.recordScreens(event: "CarPlay template didConnect")
        self.interfaceController = interfaceController
        let ui = CarTemplateUI(interfaceController: interfaceController)
        templateUI = ui
        AppState.shared.carConnected(mode: .templates)
        ui.start()
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        WDLog.car("CarPlay template scene disconnected")
        DiagnosticLog.recordScreens(event: "CarPlay template didDisconnect")
        templateUI?.stop()
        templateUI = nil
        self.interfaceController = nil
        AppState.shared.carDisconnected()
    }
}
