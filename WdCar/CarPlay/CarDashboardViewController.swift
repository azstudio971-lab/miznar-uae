import UIKit
import SwiftUI
import AVKit
import Combine

/// The external display always starts here; creating a browser is an explicit action.
final class CarDashboardViewController: UIViewController {
    private var page: UIViewController?
    private var bag = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        showWelcome()
        NotificationCenter.default.publisher(for: .wdCarPlayXtream)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.showPlayer() }.store(in: &bag)
        DrivingMonitor.shared.$isMoving.receive(on: RunLoop.main)
            .sink { [weak self] moving in
                if moving && WDSettings.lockVideoWhileDriving { PlaybackManager.shared.player.pause(); self?.presentedViewController?.dismiss(animated: false) }
            }.store(in: &bag)
    }

    private func install(_ controller: UIViewController) {
        page?.willMove(toParent: nil)
        page?.view.removeFromSuperview()
        page?.removeFromParent()
        page = controller
        addChild(controller)
        view.addSubview(controller.view)
        CarUI.pin(controller.view, to: view)
        controller.didMove(toParent: self)
    }

    private func showWelcome() {
        let controller = UIViewController()
        controller.view.backgroundColor = UIColor(red: 0.025, green: 0.05, blue: 0.08, alpha: 1)
        let title = UILabel()
        title.text = carTr("مرحبًا بكم في ود كار", "Welcome to WudCar")
        title.textColor = .white
        title.textAlignment = .center
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.accessibilityIdentifier = "car.welcome"
        let subtitle = UILabel()
        subtitle.text = carTr("اختر وجهتك", "Choose where to go")
        subtitle.textColor = .lightGray
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textAlignment = .center
        let buttons = UIStackView()
        buttons.axis = .horizontal
        buttons.distribution = .fillEqually
        buttons.spacing = 10
        buttons.addArrangedSubview(menuButton(carTr("الترفيه", "Entertainment"), symbol: "play.tv", id: "car.entertainment") { [weak self] in
            let browser = CarBrowserViewController()
            browser.onExit = { [weak self] in self?.showWelcome() }
            self?.install(browser)
        })
        buttons.addArrangedSubview(menuButton("Xtream Codes", symbol: "antenna.radiowaves.left.and.right", id: "car.xtream") { [weak self] in
            self?.showXtream()
        })
        buttons.addArrangedSubview(menuButton(carTr("الإعدادات", "Settings"), symbol: "gearshape", id: "car.settings") { [weak self] in
            let settings = CarSettingsViewController()
            settings.onBack = { [weak self] in self?.showWelcome() }
            self?.install(settings)
        })
        let stack = UIStackView(arrangedSubviews: [title, subtitle, buttons])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(stack)
        let guide = controller.view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: guide.topAnchor, constant: 8),
            buttons.heightAnchor.constraint(equalToConstant: 70)
        ])
        install(controller)
    }

    private func menuButton(_ title: String, symbol: String, id: String, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = UIColor(white: 0.12, alpha: 1)
        config.baseForegroundColor = .white
        config.title = title
        config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 20))
        config.imagePlacement = .top
        config.imagePadding = 7
        config.cornerStyle = .medium
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { input in
            var result = input; result.font = .systemFont(ofSize: 14, weight: .semibold); return result
        }
        let button = UIButton(configuration: config, primaryAction: UIAction { _ in action() })
        button.accessibilityIdentifier = id
        return button
    }

    private func showXtream() {
        let host = UIHostingController(rootView: CarXtreamRoot(onBack: { [weak self] in self?.showWelcome() }))
        install(host)
    }

    private func showPlayer() {
        guard !DrivingMonitor.shared.isMoving || !WDSettings.lockVideoWhileDriving else { return }
        let player = AVPlayerViewController()
        player.player = PlaybackManager.shared.player
        player.updatesNowPlayingInfoCenter = false
        player.modalPresentationStyle = .fullScreen
        present(player, animated: true)
    }
}

private struct CarXtreamRoot: View {
    let onBack: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) { Label(carTr("القائمة", "Menu"), systemImage: "chevron.left") }
                    .accessibilityIdentifier("car.menu")
                Spacer()
            }.font(.system(size: 13)).padding(8)
            XtreamHomeView().environment(\.isCarDisplay, true)
        }
        .preferredColorScheme(.dark)
    }
}

private struct IsCarDisplayKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var isCarDisplay: Bool {
        get { self[IsCarDisplayKey.self] }
        set { self[IsCarDisplayKey.self] = newValue }
    }
}
extension Notification.Name { static let wdCarPlayXtream = Notification.Name("wd.car.playXtream") }

func carTr(_ ar: String, _ en: String) -> String { WDSettings.carLanguage == "ar" ? ar : en }

final class CarSettingsViewController: UIViewController {
    var onBack: (() -> Void)?
    override func viewDidLoad() { super.viewDidLoad(); render() }
    private func render() {
        view.subviews.forEach { $0.removeFromSuperview() }
        view.backgroundColor = .black
        let menu = UIButton(type: .system)
        menu.setTitle(carTr("‹ القائمة", "‹ Menu"), for: .normal)
        menu.accessibilityIdentifier = "car.menu"
        menu.addAction(UIAction { [weak self] _ in self?.onBack?() }, for: .touchUpInside)
        let language = UISegmentedControl(items: ["العربية", "English"])
        language.selectedSegmentIndex = WDSettings.carLanguage == "ar" ? 0 : 1
        language.accessibilityIdentifier = "car.language"
        language.addAction(UIAction { [weak self, weak language] _ in
            WDSettings.carLanguage = language?.selectedSegmentIndex == 0 ? "ar" : "en"
            self?.render()
        }, for: .valueChanged)
        let mode = UISegmentedControl(items: [carTr("سطح المكتب", "Desktop"), carTr("الهاتف", "Mobile")])
        mode.selectedSegmentIndex = WDSettings.carDesktopMode ? 0 : 1
        mode.accessibilityIdentifier = "car.browserMode"
        mode.addAction(UIAction { [weak mode] _ in
            WDSettings.carDesktopMode = mode?.selectedSegmentIndex == 0
            WebViewPool.car.applyDesktopMode(WDSettings.carDesktopMode)
        }, for: .valueChanged)
        let zoom = UISegmentedControl(items: ["65%", "75%", "85%", "100%"])
        let values = [0.65, 0.75, 0.85, 1.0]
        zoom.selectedSegmentIndex = values.enumerated().min(by: { abs($0.element - WDSettings.carZoom) < abs($1.element - WDSettings.carZoom) })?.offset ?? 1
        zoom.addAction(UIAction { [weak zoom] _ in
            guard let index = zoom?.selectedSegmentIndex, values.indices.contains(index) else { return }
            WDSettings.carZoom = values[index]
            WebViewPool.car.applyZoom(values[index])
        }, for: .valueChanged)
        func label(_ ar: String, _ en: String) -> UILabel {
            let result = UILabel(); result.text = carTr(ar, en); result.textColor = .white
            result.font = .systemFont(ofSize: 13, weight: .semibold); return result
        }
        let stack = UIStackView(arrangedSubviews: [menu, label("اللغة", "Language"), language,
            label("عرض المواقع", "Website layout"), mode, label("حجم صفحات المتصفح", "Page scale"), zoom])
        stack.axis = .vertical; stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll); CarUI.pin(scroll, to: view, insets: UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
    }
}
