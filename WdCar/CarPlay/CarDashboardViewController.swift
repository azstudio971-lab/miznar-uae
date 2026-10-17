import UIKit

/// Navigation for the external car window. Scene ownership remains UIKit, as in 1.3.1 (4).
final class CarDashboardViewController: UIViewController {
    private let menu = UISegmentedControl(items: ["", "", ""])
    private let bodyView = UIView()
    private var pageView: UIView?
    private var browser: CarBrowserViewController?
    private var zoomLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = CarUI.navy
        menu.accessibilityIdentifier = "car.navigation"
        menu.selectedSegmentTintColor = CarUI.accent
        menu.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        menu.setTitleTextAttributes([.foregroundColor: CarUI.navy], for: .selected)
        menu.selectedSegmentIndex = 0
        menu.addAction(UIAction { [weak self] _ in self?.showSelectedPage() }, for: .valueChanged)
        let stack = UIStackView(arrangedSubviews: [menu, bodyView])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            menu.heightAnchor.constraint(equalToConstant: 34)
        ])
        updateLanguage()
        showSelectedPage()
    }

    private func updateLanguage() {
        menu.setTitle(carTr("الرئيسية", "Home"), forSegmentAt: 0)
        menu.setTitle(carTr("الترفيه", "Entertainment"), forSegmentAt: 1)
        menu.setTitle(carTr("الإعدادات", "Settings"), forSegmentAt: 2)
        view.semanticContentAttribute = WDSettings.carLanguage == "ar" ? .forceRightToLeft : .forceLeftToRight
    }

    private func showSelectedPage() {
        pageView?.removeFromSuperview()
        pageView = nil
        menu.isHidden = false
        browser?.view.isHidden = true
        if menu.selectedSegmentIndex != 1 {
            browser?.pauseForNavigation()
        }
        switch menu.selectedSegmentIndex {
        case 1:
            if browser == nil {
                let controller = CarBrowserViewController()
                controller.onVideoFullscreenChange = { [weak self] on in
                    guard let self else { return }
                    self.menu.isHidden = on && self.menu.selectedSegmentIndex == 1
                }
                addChild(controller)
                bodyView.addSubview(controller.view)
                CarUI.pin(controller.view, to: bodyView)
                controller.didMove(toParent: self)
                browser = controller
            }
            browser?.view.isHidden = false
        case 2: install(makeSettings())
        default: install(makeHome())
        }
    }

    private func install(_ page: UIView) {
        pageView = page
        bodyView.addSubview(page)
        CarUI.pin(page, to: bodyView)
    }

    private func page(_ elements: [UIView]) -> UIView {
        let scroll = UIScrollView()
        scroll.backgroundColor = CarUI.navy
        let stack = UIStackView(arrangedSubviews: elements)
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])
        return scroll
    }

    private func label(_ arabic: String, _ english: String, size: CGFloat = 17, accent: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = carTr(arabic, english)
        label.numberOfLines = 0
        label.textAlignment = WDSettings.carLanguage == "ar" ? .right : .left
        label.font = .systemFont(ofSize: size, weight: accent ? .bold : .medium)
        label.textColor = accent ? CarUI.accent : .white
        return label
    }

    private func makeHome() -> UIView {
        let logo = UIImageView(image: UIImage(named: "LogoMark"))
        logo.contentMode = .scaleAspectFit
        logo.heightAnchor.constraint(equalToConstant: 48).isActive = true
        let page = page([
            logo,
            label("مرحباً بكم في وُد كار (WudCar)", "Welcome to WudCar", size: 23, accent: true),
            label("أهلاً بكم في تجربتكم الترفيهية مع وُد كار.", "Welcome to your entertainment experience with WudCar."),
            label("يمكنكم تخصيص إعدادات التطبيق وإدارة خيارات الترفيه والمواقع المفضلة بسهولة من خلال تطبيق WudCar على هاتف iPhone.",
                  "Customize app settings, entertainment options, and favorite websites in WudCar on your iPhone."),
            label("سلامتكم أولويتنا، لذا نرجو الالتزام بقواعد السلامة المرورية وعدم الانشغال بالشاشة أثناء القيادة.",
                  "Your safety comes first. Please follow traffic safety rules and avoid interacting with the screen while driving."),
            label("رافقتكم السلامة ..", "Safe travels", accent: true)
        ])
        page.accessibilityIdentifier = "car.home"
        return page
    }

    private func makeSettings() -> UIView {
        let language = UISegmentedControl(items: ["العربية", "English"])
        language.accessibilityIdentifier = "car.language"
        language.selectedSegmentIndex = WDSettings.carLanguage == "ar" ? 0 : 1
        language.addAction(UIAction { [weak self, weak language] _ in
            WDSettings.carLanguage = language?.selectedSegmentIndex == 0 ? "ar" : "en"
            self?.updateLanguage()
            self?.showSelectedPage()
        }, for: .valueChanged)

        let display = UISegmentedControl(items: [carTr("سطح المكتب", "Desktop"), carTr("الهاتف", "Mobile")])
        display.accessibilityIdentifier = "car.desktop"
        display.selectedSegmentIndex = WDSettings.carDesktopMode ? 0 : 1
        display.addAction(UIAction { [weak display] _ in
            WDSettings.carDesktopMode = display?.selectedSegmentIndex == 0
            WebViewPool.car.applyDesktopMode(WDSettings.carDesktopMode)
        }, for: .valueChanged)

        let percent = label("", "")
        percent.accessibilityIdentifier = "car.zoom.value"
        zoomLabel = percent
        updateZoomLabel()
        let zoom = UIStepper()
        zoom.accessibilityIdentifier = "car.zoom"
        zoom.minimumValue = 50
        zoom.maximumValue = 150
        zoom.stepValue = 5
        zoom.value = (WDSettings.carZoom * 100).rounded()
        zoom.addAction(UIAction { [weak self, weak zoom] _ in
            guard let zoom else { return }
            WDSettings.carZoom = zoom.value / 100
            WebViewPool.car.applyZoom(WDSettings.carZoom)
            self?.updateZoomLabel()
        }, for: .valueChanged)
        let row = UIStackView(arrangedSubviews: [percent, zoom])
        row.axis = .horizontal
        row.distribution = .equalSpacing
        let reset = CarUI.textButton(carTr("إعادة إلى 100٪", "Reset to 100%"))
        reset.accessibilityIdentifier = "car.zoom.reset"
        reset.addAction(UIAction { [weak self, weak zoom] _ in
            WDSettings.carZoom = 1
            zoom?.value = 100
            WebViewPool.car.applyZoom(1)
            self?.updateZoomLabel()
        }, for: .touchUpInside)
        let settingsPage = page([
            label("إعدادات السيارة", "Car settings", size: 23, accent: true),
            label("اللغة", "Language"), language,
            label("عرض المواقع", "Website layout"), display,
            label("تكبير وتصغير الصفحة", "Page zoom"), row, reset,
            label("تُحفظ اختياراتك تلقائياً. قد يفرض بعض المواقع تخطيطاً ثابتاً.",
                  "Your choices are saved automatically. Some websites may enforce a fixed layout.", size: 14)
        ])
        settingsPage.accessibilityIdentifier = "car.settings"
        return settingsPage
    }

    private func updateZoomLabel() {
        zoomLabel?.text = "\(Int((WDSettings.carZoom * 100).rounded()))%"
    }
}
