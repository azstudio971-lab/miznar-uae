import CarPlay
import Combine
import UIKit

// Video-only development shell. This is deliberately NOT a web-view adapter.
// No public general-browser CarPlay template was identified in the 2026-10-13
// Developer Guide. Do not redirect taps to the phone and report success in the car.
@MainActor final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var controller: CPInterfaceController?
    private var subscription: AnyCancellable?

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        controller = interfaceController
        showStatus()
        subscription = AppState.shared.$preferences
            .map(\.language).removeDuplicates().dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.showStatus() }
    }

    private func showStatus() {
        let state = AppState.shared
        let browser = CPListItem(text: state.text("المتصفح", "Browser"),
                                 detailText: state.text("متصفح السيارة غير متاح في هذه النسخة", "The car browser is not available in this build"),
                                 image: UIImage(systemName: "safari"))
        browser.isEnabled = false
        let entertainment = CPListTemplate(title: state.text("الترفيه", "Entertainment"), sections: [CPListSection(items: [browser])])
        entertainment.tabTitle = state.text("الترفيه", "Entertainment")
        entertainment.tabImage = UIImage(systemName: "play.rectangle")
        let tv = CPListTemplate(title: "TV", sections: [])
        tv.tabTitle = "TV"
        tv.tabImage = UIImage(systemName: "tv")
        tv.emptyViewTitleVariants = [state.text("غير متاح في هذه النسخة", "Not available in this build")]
        controller?.setRootTemplate(CPTabBarTemplate(templates: [entertainment, tv]), animated: false, completion: nil)
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        subscription = nil
        controller = nil
    }
}
