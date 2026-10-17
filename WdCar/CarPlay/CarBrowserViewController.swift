import UIKit
import Combine
import WebKit

/// متصفح السيارة الكامل — يُرسم داخل نافذة CarPlay.
/// الشريط العلوي (من اليسار): حجم النص | إخفاء الشريط | ملء شاشة الفيديو | حفظ | التبويبات | تحديث | العنوان | الرئيسية | رجوع | إغلاق
final class CarBrowserViewController: UIViewController {

    var onExit: (() -> Void)?
    private let store = TabStore.car
    private let pool = WebViewPool.car
    private var bag = Set<AnyCancellable>()
    private var sessionBag = Set<AnyCancellable>()
    private weak var currentSession: TabSession?

    private var showingHome = true
    private var toolbarCollapsed = false
    private var videoFullscreen = false
    private var blockTimer: Timer?

    // MARK: العناصر

    private let toolbar = UIStackView()
    private let contentView = UIView()
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let shortcutsView = CarShortcutsView()
    private let videoOverlay = CarVideoOverlayView()
    private let drivingOverlay = CarDrivingLockView()
    private let toastLabel = PaddingLabel()
    private let restoreButton = CarUI.iconButton("chevron.down", size: 16, background: UIColor(white: 0.1, alpha: 0.85))
    private var textPanel: CarTextInputView?
    private var tabsPanel: CarTabsPanel?

    private let zoomButton = CarUI.textButton("ع ع", size: 12)
    private let collapseButton = CarUI.iconButton("chevron.up")
    private let fullscreenButton = CarUI.iconButton("arrow.up.left.and.arrow.down.right")
    private let starButton = CarUI.iconButton("star")
    private let tabsButton = CarUI.iconButton("square.on.square")
    private let reloadButton = CarUI.iconButton("arrow.clockwise")
    private let urlButton = CarUI.textButton("أدخل عنوان URL أو ابحث", size: 13)
    private let homeButton = CarUI.iconButton("house")
    private let backButton = CarUI.iconButton("chevron.left")
    private let menuButton = CarUI.iconButton("square.grid.2x2")
    private let closeButton = CarUI.iconButton("xmark")

    private var contentTopToToolbar: NSLayoutConstraint!
    private var contentTopToSafe: NSLayoutConstraint!

    private let zoomLevels: [Double] = [0.65, 0.75, 0.85, 1.0]

    // MARK: دورة الحياة

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.semanticContentAttribute = .forceLeftToRight
        buildToolbar()
        buildContent()
        buildOverlays()
        bind()
        refresh()
    }

    deinit {
        blockTimer?.invalidate()
    }

    // MARK: البناء

    private func buildToolbar() {
        toolbar.axis = .horizontal
        toolbar.spacing = 3
        toolbar.alignment = .fill
        toolbar.semanticContentAttribute = .forceLeftToRight

        var urlConfig = urlButton.configuration
        urlConfig?.titleLineBreakMode = .byTruncatingTail
        urlButton.configuration = urlConfig
        urlButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        urlButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let buttons: [UIButton] = [menuButton, zoomButton, collapseButton, fullscreenButton, starButton, tabsButton,
                                   reloadButton, urlButton, homeButton, backButton, closeButton]
        urlButton.accessibilityIdentifier = "car.address"
        menuButton.accessibilityIdentifier = "car.menu"
        homeButton.accessibilityIdentifier = "car.home"
        buttons.forEach { button in
            var compact = button.configuration
            compact?.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 5, bottom: 3, trailing: 5)
            compact?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            button.configuration = compact
            if button !== urlButton {
                button.setContentHuggingPriority(.required, for: .horizontal)
                button.setContentCompressionResistancePriority(.required, for: .horizontal)
            }
            toolbar.addArrangedSubview(button)
        }

        menuButton.addAction(UIAction { [weak self] _ in
            self?.currentSession?.pauseMedia(); self?.onExit?()
        }, for: .touchUpInside)
        zoomButton.addAction(UIAction { [weak self] _ in self?.cycleZoom() }, for: .touchUpInside)
        collapseButton.addAction(UIAction { [weak self] _ in self?.setToolbarCollapsed(true) }, for: .touchUpInside)
        fullscreenButton.addAction(UIAction { [weak self] _ in self?.enterVideoFullscreen() }, for: .touchUpInside)
        starButton.addAction(UIAction { [weak self] _ in self?.saveShortcut() }, for: .touchUpInside)
        tabsButton.addAction(UIAction { [weak self] _ in self?.showTabsPanel() }, for: .touchUpInside)
        reloadButton.addAction(UIAction { [weak self] _ in self?.currentSession?.reload() }, for: .touchUpInside)
        urlButton.addAction(UIAction { [weak self] _ in self?.presentTextInput(mode: .url, initial: "", placeholder: "") }, for: .touchUpInside)
        homeButton.addAction(UIAction { [weak self] _ in self?.goHome() }, for: .touchUpInside)
        backButton.addAction(UIAction { [weak self] _ in self?.goBack() }, for: .touchUpInside)
        closeButton.addAction(UIAction { [weak self] _ in self?.closeCurrentTab() }, for: .touchUpInside)

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: guide.topAnchor, constant: 3),
            toolbar.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 8),
            toolbar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -8),
            toolbar.heightAnchor.constraint(equalToConstant: 42)
        ])
    }

    private func buildContent() {
        contentView.backgroundColor = .black
        contentView.clipsToBounds = true
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)

        let guide = view.safeAreaLayoutGuide
        contentTopToToolbar = contentView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 3)
        contentTopToSafe = contentView.topAnchor.constraint(equalTo: guide.topAnchor)
        NSLayoutConstraint.activate([
            contentTopToToolbar,
            contentView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        shortcutsView.onSelect = { [weak self] shortcut in self?.open(shortcut.url) }
        contentView.addSubview(shortcutsView)
        CarUI.pin(shortcutsView, to: contentView)

        progressView.progressTintColor = CarUI.accent
        progressView.trackTintColor = .clear
        progressView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: contentView.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 3)
        ])
    }

    private func buildOverlays() {
        restoreButton.isHidden = true
        restoreButton.addAction(UIAction { [weak self] _ in self?.setToolbarCollapsed(false) }, for: .touchUpInside)
        restoreButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(restoreButton)

        videoOverlay.isHidden = true
        videoOverlay.onExit = { [weak self] in self?.currentSession?.exitVideoFullscreen() }
        videoOverlay.onFitChange = { [weak self] fit in self?.currentSession?.setVideoFit(fit) }
        videoOverlay.onTogglePlay = { [weak self] in self?.currentSession?.togglePlay() }
        videoOverlay.onSeekBy = { [weak self] seconds in self?.currentSession?.seek(by: seconds) }
        videoOverlay.onSeekTo = { [weak self] fraction in self?.currentSession?.seek(toFraction: fraction) }
        view.addSubview(videoOverlay)
        CarUI.pin(videoOverlay, to: view)

        drivingOverlay.isHidden = true
        view.addSubview(drivingOverlay)
        CarUI.pin(drivingOverlay, to: view)

        toastLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        toastLabel.textColor = .white
        toastLabel.backgroundColor = UIColor(white: 0.15, alpha: 0.95)
        toastLabel.layer.cornerRadius = 20
        toastLabel.clipsToBounds = true
        toastLabel.alpha = 0
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toastLabel)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            restoreButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 3),
            restoreButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -10),
            restoreButton.widthAnchor.constraint(equalToConstant: 48),
            restoreButton.heightAnchor.constraint(equalToConstant: 36),
            toastLabel.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -24)
        ])
    }

    private func bind() {
        store.$tabs
            .combineLatest(store.$activeID)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in self?.refresh() }
            .store(in: &bag)

        // تبويب جديد أُرسل من الهاتف: نعرضه مباشرة
        store.$activeID
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.showingHome = false
                self?.refresh()
            }
            .store(in: &bag)

        // رابط أُرسل للتبويب الحالي (مثلاً من زر السيارة في الهاتف والتبويبات ممتلئة)
        store.loadRequests
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.showingHome = false
                self?.refresh()
            }
            .store(in: &bag)

        DrivingMonitor.shared.$isMoving
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateDrivingLock() }
            .store(in: &bag)
    }

    // MARK: عرض التبويب الحالي

    private func refresh() {
        updateTabsButton()
        guard let tab = store.activeTab else { return }

        if showingHome || tab.url == nil {
            shortcutsView.isHidden = false
            contentView.bringSubviewToFront(shortcutsView)
            currentSession?.webView.isHidden = true
            progressView.isHidden = true
            CarUI.setTitle(urlButton, carTr("اكتب عنوانًا أو ابحث", "Address or search"), size: 13)
            backButton.isEnabled = tab.url != nil
            return
        }

        let session = pool.session(for: tab.id)
        if session !== currentSession { attach(session) }
        shortcutsView.isHidden = true
        session.webView.isHidden = false
        contentView.bringSubviewToFront(progressView)
        CarUI.setTitle(urlButton, tab.url?.host ?? tab.displayTitle, size: 13)
        backButton.isEnabled = true
    }

    private func attach(_ session: TabSession) {
        sessionBag.removeAll()
        if let old = currentSession {
            if old.isVideoFullscreen { old.exitVideoFullscreen() }
            old.webView.removeFromSuperview()
        }
        currentSession = session

        let webView = session.webView
        webView.pageZoom = CGFloat(WDSettings.carZoom)
        contentView.insertSubview(webView, at: 0)
        CarUI.pin(webView, to: contentView)

        session.$isLoading
            .combineLatest(session.$progress)
            .receive(on: RunLoop.main)
            .sink { [weak self] loading, progress in
                guard let self else { return }
                self.progressView.isHidden = !loading || self.showingHome
                self.progressView.setProgress(Float(progress), animated: true)
                CarUI.setSymbol(self.reloadButton, loading ? "xmark" : "arrow.clockwise", size: 13)
            }
            .store(in: &sessionBag)

        session.$isVideoFullscreen
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] on in self?.setVideoFullscreen(on) }
            .store(in: &sessionBag)

        session.$videoStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in self?.videoOverlay.update(status) }
            .store(in: &sessionBag)

        session.focusEvents
            .receive(on: RunLoop.main)
            .sink { [weak self] info in
                self?.presentTextInput(mode: .webField, initial: info.value, placeholder: info.placeholder)
            }
            .store(in: &sessionBag)
    }

    // MARK: أزرار الشريط

    private func open(_ url: URL) {
        showingHome = false
        store.open(url, inNewTab: false)
        refresh()
    }

    private func goHome() {
        showingHome = true
        currentSession?.pauseMedia()
        refresh()
    }

    private func goBack() {
        if showingHome, store.activeTab?.url != nil {
            showingHome = false
            refresh()
        } else if let session = currentSession, session.canGoBack {
            session.goBack()
        } else {
            goHome()
        }
    }

    private func closeCurrentTab() {
        guard let id = store.activeID else { return }
        if currentSession?.tabID == id {
            sessionBag.removeAll()
            currentSession = nil
        }
        showingHome = false
        store.close(id)
    }

    private func cycleZoom() {
        let current = WDSettings.carZoom
        let index = zoomLevels.firstIndex { abs($0 - current) < 0.01 } ?? 1
        let next = zoomLevels[(index + 1) % zoomLevels.count]
        WDSettings.carZoom = next
        pool.applyZoom(next)
        showToast("حجم النص \(Int(next * 100))%")
    }

    private func saveShortcut() {
        guard let tab = store.activeTab, let url = tab.url, !showingHome else {
            showToast("افتح موقعاً أولاً")
            return
        }
        let added = ShortcutStore.shared.add(name: tab.url?.host ?? tab.displayTitle, url: url)
        showToast(added ? "تمت الإضافة للاختصارات ⭐" : "الموقع موجود في الاختصارات")
    }

    private func enterVideoFullscreen() {
        guard let session = currentSession, !showingHome else { return }
        session.enterVideoFullscreen { [weak self] found in
            if !found { self?.setToolbarCollapsed(true) }
        }
    }

    private func updateTabsButton() {
        var config = tabsButton.configuration
        config?.attributedTitle = AttributedString("\(store.tabs.count)", attributes: AttributeContainer([
            .font: UIFont.systemFont(ofSize: 14, weight: .bold)
        ]))
        config?.imagePadding = 4
        tabsButton.configuration = config
    }

    // MARK: الشريط وملء الشاشة

    private func setToolbarCollapsed(_ collapsed: Bool) {
        toolbarCollapsed = collapsed
        applyToolbarVisibility()
    }

    private func setVideoFullscreen(_ on: Bool) {
        videoFullscreen = on
        if on { videoOverlay.present() } else { videoOverlay.isHidden = true }
        applyToolbarVisibility()
        updateDrivingLock()
    }

    private func applyToolbarVisibility() {
        let hidden = toolbarCollapsed || videoFullscreen
        toolbar.isHidden = hidden
        restoreButton.isHidden = !(toolbarCollapsed && !videoFullscreen)
        NSLayoutConstraint.deactivate([contentTopToToolbar, contentTopToSafe])
        NSLayoutConstraint.activate([hidden ? contentTopToSafe : contentTopToToolbar])
        view.bringSubviewToFront(restoreButton)
        UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
    }

    // MARK: قفل الفيديو أثناء القيادة

    private func updateDrivingLock() {
        let block = DrivingMonitor.shared.shouldBlockVideo
        drivingOverlay.isHidden = !block
        blockTimer?.invalidate()
        blockTimer = nil
        guard block else { return }
        view.bringSubviewToFront(drivingOverlay)
        pool.pauseAllMedia()
        blockTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.pool.pauseAllMedia()
        }
    }

    // MARK: شاشة الكتابة

    private func presentTextInput(mode: CarTextInputView.Mode, initial: String, placeholder: String) {
        guard textPanel == nil else { return }
        let panel = CarTextInputView(mode: mode, initialText: initial, placeholder: placeholder)

        if mode == .webField {
            panel.onLiveText = { [weak self] text in self?.currentSession?.setInputText(text) }
        }
        panel.onSubmit = { [weak self] text in
            guard let self else { return }
            self.dismissTextInput()
            switch mode {
            case .webField:
                self.currentSession?.setInputText(text)
                self.currentSession?.submitInput()
            case .url:
                if let url = URLInput.resolve(text) { self.open(url) }
            }
        }
        panel.onCancel = { [weak self] in
            if mode == .webField { self?.currentSession?.blurInput() }
            self?.dismissTextInput()
        }

        view.addSubview(panel)
        CarUI.pin(panel, to: view)
        if !drivingOverlay.isHidden { view.bringSubviewToFront(drivingOverlay) }
        textPanel = panel
    }

    private func dismissTextInput() {
        textPanel?.removeFromSuperview()
        textPanel = nil
    }

    // MARK: لوحة التبويبات

    private func showTabsPanel() {
        guard tabsPanel == nil else { return }
        currentSession?.takeSnapshot()

        let panel = CarTabsPanel(store: store)
        panel.onSelect = { [weak self] id in
            self?.showingHome = false
            self?.store.select(id)
            self?.hideTabsPanel()
            self?.refresh()
        }
        panel.onNewTab = { [weak self] in
            guard let self else { return }
            if self.store.isFull {
                self.showToast("الحد الأقصى 8 علامات تبويب")
                return
            }
            self.store.newTab()
            self.showingHome = false
            self.hideTabsPanel()
        }
        panel.onDone = { [weak self] in self?.hideTabsPanel() }

        view.addSubview(panel)
        CarUI.pin(panel, to: view)
        tabsPanel = panel
    }

    private func hideTabsPanel() {
        tabsPanel?.removeFromSuperview()
        tabsPanel = nil
    }

    // MARK: تنبيه قصير

    private func showToast(_ text: String) {
        toastLabel.text = text
        view.bringSubviewToFront(toastLabel)
        UIView.animate(withDuration: 0.2) { self.toastLabel.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard self?.toastLabel.text == text else { return }
            UIView.animate(withDuration: 0.3) { self?.toastLabel.alpha = 0 }
        }
    }
}
