import CarPlay
import UIKit

/// CarPlay video/audio use Apple's template interface. A navigation window is
/// not an entitlement to display arbitrary web content on the car screen.
final class CarSceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var templateUI: CarTemplateUI?

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        let ui = CarTemplateUI(interfaceController: interfaceController)
        templateUI = ui
        ui.start()
        AppState.shared.carConnected(mode: .templates)
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        templateUI = nil
        AppState.shared.carDisconnected()
    }
}
