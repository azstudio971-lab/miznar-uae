import UIKit
import SwiftUI
import AVKit
import Combine

/// Navigation for the external car window. Scene ownership remains UIKit, as in 1.3.1 (4).
final class CarDashboardViewController: UIViewController {
    private let menu = UISegmentedControl(items: ["", "", "", ""])
    private let bodyView = UIView()
    private var pageView: UIView?
    private var browser: CarBrowserViewController?
    private var zoomLabel: UILabel?
    private var tvController: UIHostingController<XtreamHomeView>?
    private var externalPlayer: AVPlayerViewController?
    private let playerCloseButton = CarUI.iconButton("xmark", size: 18, background: UIColor(white: 0.05, alpha: 0.78))
    private let playerFitButton = CarUI.textButton("تمدد", size: 14, background: UIColor(white: 0.05, alpha: 0.78))
    private let playerErrorLabel = UILabel()
    private var playerControlsTimer: Timer?
    private var playerTouchRecognizer: UITapGestureRecognizer?
    private var playerIsStretched = false
    private var bag = Set<AnyCancellable>()
    private weak var welcomeGradient: CAGradientLayer?
    private weak var welcomeCopy: UIStackView?
    private let welcomeSizes: [CGFloat] = [25, 18, 16, 16, 18]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = CarUI.navy
        menu.accessibilityIdentifier = "car.navigation"
        menu.selectedSegmentTintColor = CarUI.accent
        menu.semanticContentAttribute = .forceRightToLeft
        menu.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        menu.setTitleTextAttributes([.foregroundColor: CarUI.navy], for: .selected)
        menu.selectedSegmentIndex = CarScreenLauncher.shared.isLaunching ? 1 : 0
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
        bindRemoteControl()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        welcomeGradient?.frame = pageView?.bounds ?? .zero
        fitWelcomeText()
    }

    private func fitWelcomeText() {
        guard pageView?.accessibilityIdentifier == "car.home", let copy = welcomeCopy,
              copy.bounds.width > 0, let pageView else { return }
        let available = max(1, pageView.bounds.height - 44)
        let labels = copy.arrangedSubviews.compactMap { $0 as? UILabel }
        func requiredHeight(_ scale: CGFloat) -> CGFloat {
            var height = CGFloat(max(0, labels.count - 1)) * 10 * scale
            for (index, item) in labels.enumerated() {
                let weight: UIFont.Weight = (index == 0 || index == 4) ? .bold : .medium
                let font = UIFont.systemFont(ofSize: welcomeSizes[index] * scale, weight: weight)
                let bounds = (item.text ?? "").boundingRect(
                    with: CGSize(width: copy.bounds.width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font], context: nil)
                height += ceil(bounds.height) + 1
            }
            return height
        }
        var low: CGFloat = 0.35
        var high: CGFloat = 1
        for _ in 0..<12 {
            let middle = (low + high) / 2
            if requiredHeight(middle) <= available { low = middle } else { high = middle }
        }
        copy.spacing = 10 * low
        for (index, item) in labels.enumerated() {
            let size = welcomeSizes[index] * low
            if abs(item.font.pointSize - size) > 0.05 {
                item.font = .systemFont(ofSize: size, weight: (index == 0 || index == 4) ? .bold : .medium)
            }
        }
    }

    private func updateLanguage() {
        menu.setTitle(carTr("الرئيسية", "Home"), forSegmentAt: 0)
        menu.setTitle(carTr("الترفيه", "Entertainment"), forSegmentAt: 1)
        menu.setTitle(carTr("التلفزيون TV", "TV"), forSegmentAt: 2)
        menu.setTitle(carTr("الإعدادات", "Settings"), forSegmentAt: 3)
        view.semanticContentAttribute = WDSettings.carLanguage == "ar" ? .forceRightToLeft : .forceLeftToRight
    }

    private func showSelectedPage() {
        pageView?.removeFromSuperview()
        pageView = nil
        menu.isHidden = menu.selectedSegmentIndex == 1
        browser?.view.isHidden = true
        tvController?.view.isHidden = true
        if menu.selectedSegmentIndex != 1 {
            browser?.pauseForNavigation()
        }
        switch menu.selectedSegmentIndex {
        case 1:
            if browser == nil {
                let controller = CarBrowserViewController()
                controller.onVideoFullscreenChange = { [weak self] on in
                    guard let self else { return }
                    self.menu.isHidden = on || self.menu.selectedSegmentIndex == 1
                }
                controller.onExitEntertainment = { [weak self] in
                    guard let self else { return }
                    self.menu.selectedSegmentIndex = 0
                    self.showSelectedPage()
                }
                addChild(controller)
                bodyView.addSubview(controller.view)
                CarUI.pin(controller.view, to: bodyView)
                controller.didMove(toParent: self)
                browser = controller
            }
            browser?.view.isHidden = false
        case 2:
            if tvController == nil {
                let controller = UIHostingController(rootView: XtreamHomeView(readOnly: true, presentPlaybackOnPhone: false))
                controller.view.accessibilityIdentifier = "car.tv.screen"
                controller.view.backgroundColor = UIColor(red: 0.035, green: 0.05, blue: 0.085, alpha: 1)
                controller.overrideUserInterfaceStyle = .dark
                addChild(controller)
                bodyView.addSubview(controller.view)
                CarUI.pin(controller.view, to: bodyView)
                controller.didMove(toParent: self)
                tvController = controller
            }
            if let tvView = tvController?.view {
                if tvView.superview !== bodyView {
                    bodyView.addSubview(tvView)
                    CarUI.pin(tvView, to: bodyView)
                }
                tvView.isHidden = false
                pageView = tvView
            }
        case 3: install(makeSettings())
        default: install(makeHome())
        }
    }


    private func bindRemoteControl() {
        CarMouseBridge.shared.$input
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                guard let self, let input = value else { return }
                switch input {
                case .selectSection(let section):
                    if self.externalPlayer != nil && section == .television { return }
                    if self.externalPlayer != nil { PlaybackManager.shared.stop() }
                    self.menu.selectedSegmentIndex = section.rawValue
                    self.showSelectedPage()
                case .stopPlayback:
                    PlaybackManager.shared.stop()
                default:
                    break
                }
            }
            .store(in: &bag)

        PlaybackManager.shared.$current
            .combineLatest(PlaybackManager.shared.$isExternalDisplayPlayback,
                           PlaybackManager.shared.$errorMessage)
            .receive(on: RunLoop.main)
            .sink { [weak self] current, requestedForDisplay, error in
                guard let self else { return }
                self.updateExternalPlayer(visible: current != nil && requestedForDisplay, error: error)
            }
            .store(in: &bag)

        PlaybackManager.shared.$isPlaying
            .removeDuplicates()
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.externalPlayer != nil else { return }
                self.showExternalPlayerControls()
            }
            .store(in: &bag)

        DrivingMonitor.shared.$isMoving
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] moving in
                guard let self, self.externalPlayer != nil else { return }
                if DrivingMonitor.shared.shouldBlockVideo {
                    PlaybackManager.shared.player.pause()
                    self.playerErrorLabel.text = carTr("تم إيقاف الفيديو أثناء القيادة", "Video paused while driving")
                    self.playerErrorLabel.isHidden = false
                } else if let error = PlaybackManager.shared.errorMessage {
                    self.playerErrorLabel.text = error
                    self.playerErrorLabel.isHidden = false
                } else {
                    self.playerErrorLabel.isHidden = true
                }
            }
            .store(in: &bag)
    }

    private func updateExternalPlayer(visible: Bool, error: String?) {
        guard visible else {
            playerControlsTimer?.invalidate()
            playerControlsTimer = nil
            if let playerTouchRecognizer { bodyView.removeGestureRecognizer(playerTouchRecognizer) }
            playerTouchRecognizer = nil
            externalPlayer?.willMove(toParent: nil)
            externalPlayer?.view.removeFromSuperview()
            externalPlayer?.removeFromParent()
            externalPlayer = nil
            playerCloseButton.removeFromSuperview()
            playerFitButton.removeFromSuperview()
            playerErrorLabel.removeFromSuperview()
            menu.isHidden = menu.selectedSegmentIndex == 1
            showSelectedPage()
            return
        }
        if externalPlayer == nil {
            menu.selectedSegmentIndex = CarMouseBridge.DashboardSection.television.rawValue
            showSelectedPage()
            menu.isHidden = true
            let controller = AVPlayerViewController()
            controller.player = PlaybackManager.shared.player
            controller.showsPlaybackControls = true
            controller.allowsPictureInPicturePlayback = false
            controller.updatesNowPlayingInfoCenter = false
            controller.videoGravity = .resizeAspect
            addChild(controller)
            bodyView.addSubview(controller.view)
            CarUI.pin(controller.view, to: bodyView)
            controller.didMove(toParent: self)
            externalPlayer = controller
            playerIsStretched = false

            playerCloseButton.accessibilityIdentifier = "car.tv.player.close"
            playerCloseButton.accessibilityLabel = carTr("إيقاف والعودة للقنوات", "Stop and return to channels")
            playerCloseButton.addAction(UIAction { _ in PlaybackManager.shared.stop() }, for: .touchUpInside)
            playerCloseButton.translatesAutoresizingMaskIntoConstraints = false
            bodyView.addSubview(playerCloseButton)
            playerFitButton.translatesAutoresizingMaskIntoConstraints = false
            bodyView.addSubview(playerFitButton)
            NSLayoutConstraint.activate([
                playerCloseButton.topAnchor.constraint(equalTo: bodyView.safeAreaLayoutGuide.topAnchor, constant: 10),
                playerCloseButton.trailingAnchor.constraint(equalTo: bodyView.safeAreaLayoutGuide.trailingAnchor, constant: -12),
                playerCloseButton.widthAnchor.constraint(equalToConstant: 46),
                playerCloseButton.heightAnchor.constraint(equalToConstant: 40),
                playerFitButton.topAnchor.constraint(equalTo: playerCloseButton.topAnchor),
                playerFitButton.trailingAnchor.constraint(equalTo: playerCloseButton.leadingAnchor, constant: -8),
                playerFitButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 92),
                playerFitButton.heightAnchor.constraint(equalTo: playerCloseButton.heightAnchor)
            ])

            playerFitButton.accessibilityIdentifier = "car.tv.player.stretch"
            playerFitButton.accessibilityLabel = carTr("تمدد لملء الشاشة", "Stretch to fill screen")
            playerFitButton.addAction(UIAction { [weak self] _ in
                guard let self, let player = self.externalPlayer else { return }
                self.playerIsStretched.toggle()
                player.videoGravity = self.playerIsStretched ? .resize : .resizeAspect
                CarUI.setTitle(self.playerFitButton,
                               self.playerIsStretched ? carTr("ملاءمة", "Fit") : carTr("تمدد", "Stretch"), size: 14)
                self.showExternalPlayerControls()
            }, for: .touchUpInside)
            bodyView.bringSubviewToFront(playerFitButton)

            let tap = UITapGestureRecognizer(target: self, action: #selector(externalPlayerWasTouched))
            tap.cancelsTouchesInView = false
            bodyView.addGestureRecognizer(tap)
            playerTouchRecognizer = tap
            bodyView.bringSubviewToFront(playerCloseButton)
            PlaybackManager.shared.player.playImmediately(atRate: 1)
            showExternalPlayerControls()

            playerErrorLabel.textColor = .white
            playerErrorLabel.backgroundColor = UIColor(white: 0.08, alpha: 0.92)
            playerErrorLabel.textAlignment = .center
            playerErrorLabel.numberOfLines = 0
            playerErrorLabel.font = .systemFont(ofSize: 18, weight: .semibold)
            playerErrorLabel.isHidden = true
            playerErrorLabel.layer.cornerRadius = 14
            playerErrorLabel.clipsToBounds = true
            playerErrorLabel.accessibilityIdentifier = "car.tv.player.error"
            playerErrorLabel.translatesAutoresizingMaskIntoConstraints = false
            bodyView.addSubview(playerErrorLabel)
            NSLayoutConstraint.activate([
                playerErrorLabel.centerXAnchor.constraint(equalTo: bodyView.centerXAnchor),
                playerErrorLabel.centerYAnchor.constraint(equalTo: bodyView.centerYAnchor),
                playerErrorLabel.widthAnchor.constraint(lessThanOrEqualTo: bodyView.widthAnchor, multiplier: 0.8),
                playerErrorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: bodyView.leadingAnchor, constant: 30),
                playerErrorLabel.trailingAnchor.constraint(lessThanOrEqualTo: bodyView.trailingAnchor, constant: -30)
            ])
        }
        if let error {
            playerErrorLabel.text = carTr("تعذّر تشغيل القناة: ", "Channel playback failed: ") + error
            playerErrorLabel.isHidden = false
        } else if DrivingMonitor.shared.shouldBlockVideo {
            playerErrorLabel.text = carTr("تم إيقاف الفيديو أثناء القيادة", "Video paused while driving")
            playerErrorLabel.isHidden = false
            PlaybackManager.shared.player.pause()
        } else {
            playerErrorLabel.isHidden = true
        }
    }

    @objc private func externalPlayerWasTouched() {
        showExternalPlayerControls()
    }

    private func showExternalPlayerControls() {
        playerCloseButton.isHidden = false
        playerFitButton.isHidden = false
        playerControlsTimer?.invalidate()
        playerControlsTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            self?.playerCloseButton.isHidden = true
            self?.playerFitButton.isHidden = true
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
        let page = UIView()
        page.accessibilityIdentifier = "car.home"
        page.backgroundColor = CarUI.navy
        let gradient = CAGradientLayer()
        gradient.colors = [
            CarUI.navy.cgColor,
            CarUI.navy.cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        page.layer.insertSublayer(gradient, at: 0)
        welcomeGradient = gradient

        let logo = UIImageView(image: UIImage(named: "LogoCarMark") ?? UIImage(named: "LogoMark") ?? UIImage(named: "LogoFull"))
        logo.contentMode = .scaleAspectFit
        logo.translatesAutoresizingMaskIntoConstraints = false

        let copy = UIStackView(arrangedSubviews: [
            label("مرحباً بكم في وُد كار (WudCar)", "Welcome to WudCar", size: 25, accent: true),
            label("أهلاً بكم في تجربتكم الترفيهية مع وُد كار.", "Welcome to your entertainment experience with WudCar.", size: 18),
            label("يمكنكم تخصيص إعدادات التطبيق وإدارة خيارات الترفيه والمواقع المفضلة بسهولة من خلال تطبيق WudCar على هاتف iPhone.",
                  "Customize app settings, entertainment options, and favorite websites in WudCar on your iPhone.", size: 16),
            label("سلامتكم أولويتنا، لذا نرجو الالتزام بقواعد السلامة المرورية وعدم الانشغال بالشاشة أثناء القيادة.",
                  "Your safety comes first. Please follow traffic safety rules and avoid interacting with the screen while driving.", size: 16),
            label("رافقتكم السلامة ..", "Safe travels", size: 18, accent: true)
        ])
        welcomeCopy = copy
        copy.axis = .vertical
        copy.spacing = 10
        copy.alignment = .fill
        copy.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [logo, copy])
        row.axis = .horizontal
        row.spacing = 30
        row.alignment = .center
        row.semanticContentAttribute = .forceLeftToRight
        copy.semanticContentAttribute = .forceRightToLeft
        row.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: 34),
            row.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -34),
            row.topAnchor.constraint(equalTo: page.topAnchor, constant: 22),
            row.bottomAnchor.constraint(equalTo: page.bottomAnchor, constant: -22),
            logo.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.29),
            logo.heightAnchor.constraint(lessThanOrEqualTo: row.heightAnchor, multiplier: 0.82),
            copy.heightAnchor.constraint(lessThanOrEqualTo: row.heightAnchor)
        ])
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
