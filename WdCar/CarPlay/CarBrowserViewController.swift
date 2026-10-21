import UIKit
import Combine
import WebKit

/// متصفح السيارة الكامل — يُرسم داخل نافذة CarPlay.
/// شريط المتصفح: التكبير | إخفاء الشريط | الفيديو | حفظ | التبويبات | تحديث | العنوان | اختصارات | رجوع | القائمة
final class CarBrowserViewController: UIViewController, UIGestureRecognizerDelegate {
    var onVideoFullscreenChange: ((Bool) -> Void)?
    var onExitEntertainment: (() -> Void)?

    func pauseForNavigation() {
        currentSession?.exitVideoFullscreen()
        pool.pauseAllMedia()
    }

    private let store = TabStore.car
    private let pool = WebViewPool.car
    private var bag = Set<AnyCancellable>()
    private var sessionBag = Set<AnyCancellable>()
    private weak var currentSession: TabSession?
    private let mouseCursor = UIImageView(image: UIImage(systemName: "cursorarrow"))
    private var mouseCursorCenter: CGPoint?
    private var mouseHideTimer: Timer?
    private var mouseHiddenForIdle = true
    private var mouseHasBeenMoved = false
    private var toolbarHideTimer: Timer?
    private var scrollButtonsHideTimer: Timer?
    private var toolbarRevealHideTimer: Timer?
    private var screenTapRecognizer: UITapGestureRecognizer?
    private var webViewTapRecognizer: UITapGestureRecognizer?

    private var showingHome = false
    private var toolbarCollapsed = true
    private var videoFullscreen = false
    private var blockTimer: Timer?

    // MARK: العناصر

    private let toolbar = UIStackView()
    private var viewport: DesktopViewportView?
    private let contentView = UIView()
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let shortcutsView = CarShortcutsView()
    private let videoOverlay = CarVideoOverlayView()
    private let drivingOverlay = CarDrivingLockView()
    private let toastLabel = PaddingLabel()
    private let siteErrorLabel = PaddingLabel()
    private let scrollUpButton = CarUI.iconButton("arrow.up", size: 17, background: UIColor(white: 0.08, alpha: 0.82))
    private let scrollDownButton = CarUI.iconButton("arrow.down", size: 17, background: UIColor(white: 0.08, alpha: 0.82))
    private let toolbarHotspot = UIButton(type: .custom)
    private let toolbarEdge = UIButton(type: .custom)
    private let toolbarRevealButton = CarUI.iconButton("ellipsis", size: 17, background: UIColor(white: 0.05, alpha: 0.82))
    private var scrollControls: UIStackView!
    private var textPanel: CarTextInputView?
    private var tabsPanel: CarTabsPanel?

    private let collapseButton = CarUI.iconButton("chevron.up")
    private let tabsButton = CarUI.iconButton("square.on.square")
    private let urlButton = CarUI.textButton("أدخل عنوان URL أو ابحث", size: 16)
    private let homeButton = CarUI.iconButton("house")
    private let backButton = CarUI.iconButton("chevron.left")
    private let closeButton = CarUI.iconButton("line.3.horizontal")

    private var contentTopToToolbar: NSLayoutConstraint!
    private var contentTopToSafe: NSLayoutConstraint!


    // MARK: دورة الحياة

    override func loadView() {
        view = BrowserChromeView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.semanticContentAttribute = .forceLeftToRight
        buildToolbar()
        buildContent()
        buildOverlays()
        bind()
        refresh()
        setToolbarCollapsed(true)
    }

    deinit {
        blockTimer?.invalidate()
        mouseHideTimer?.invalidate()
        toolbarHideTimer?.invalidate()
        scrollButtonsHideTimer?.invalidate()
        toolbarRevealHideTimer?.invalidate()
    }

    // MARK: البناء

    private func buildToolbar() {
        toolbar.axis = .horizontal
        toolbar.accessibilityIdentifier = "car.browser.toolbar"
        toolbar.spacing = 4
        toolbar.alignment = .fill
        toolbar.semanticContentAttribute = .forceLeftToRight

        var urlConfig = urlButton.configuration
        urlConfig?.titleLineBreakMode = .byTruncatingTail
        urlButton.configuration = urlConfig
        urlButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        urlButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let buttons: [UIButton] = [collapseButton, tabsButton, urlButton, homeButton, backButton, closeButton]
        buttons.forEach { button in
            var buttonConfig = button.configuration
            buttonConfig?.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6)
            button.configuration = buttonConfig
            if button !== urlButton {
                button.setContentHuggingPriority(.required, for: .horizontal)
                button.setContentCompressionResistancePriority(.required, for: .horizontal)
            }
            button.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            if button !== urlButton { button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true }
            toolbar.addArrangedSubview(button)
        }

        collapseButton.accessibilityLabel = carTr("إخفاء الشريط", "Hide toolbar")
        collapseButton.addAction(UIAction { [weak self] _ in self?.setToolbarCollapsed(true) }, for: .touchUpInside)
        tabsButton.addAction(UIAction { [weak self] _ in self?.showTabsPanel() }, for: .touchUpInside)
        urlButton.addAction(UIAction { [weak self] _ in self?.presentTextInput(mode: .url, initial: "", placeholder: "") }, for: .touchUpInside)
        homeButton.addAction(UIAction { [weak self] _ in self?.goHome() }, for: .touchUpInside)
        backButton.addAction(UIAction { [weak self] _ in self?.goBack() }, for: .touchUpInside)
        closeButton.accessibilityIdentifier = "car.exitEntertainment"
        closeButton.accessibilityLabel = carTr("القائمة الرئيسية", "Main menu")
        closeButton.accessibilityHint = carTr("العودة إلى قائمة CarPlay", "Return to the CarPlay menu")
        closeButton.addAction(UIAction { [weak self] _ in self?.onExitEntertainment?() }, for: .touchUpInside)
        buttons.forEach { $0.addAction(UIAction { [weak self] _ in self?.scheduleToolbarHide() }, for: .touchDown) }

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: guide.topAnchor, constant: 3),
            toolbar.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 8),
            toolbar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -8),
            toolbar.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    private func buildContent() {
        (view as? BrowserChromeView)?.browserContent = contentView
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

        mouseCursor.accessibilityIdentifier = "car.mouse.cursor"
        mouseCursor.tintColor = .white
        mouseCursor.backgroundColor = .clear
        mouseCursor.contentMode = .scaleAspectFit
        mouseCursor.layer.shadowColor = UIColor.black.cgColor
        mouseCursor.layer.shadowOpacity = 0.85
        mouseCursor.layer.shadowRadius = 2
        mouseCursor.layer.shadowOffset = CGSize(width: 1, height: 1)
        mouseCursor.frame = CGRect(x: 0, y: 0, width: 26, height: 26)
        mouseCursor.isHidden = true
        mouseCursor.isUserInteractionEnabled = false
        view.addSubview(mouseCursor)

        let screenTap = UITapGestureRecognizer(target: self, action: #selector(handleScreenTap(_:)))
        screenTap.cancelsTouchesInView = false
        screenTap.delaysTouchesBegan = false
        screenTap.delaysTouchesEnded = false
        screenTap.delegate = self
        view.addGestureRecognizer(screenTap)
        screenTapRecognizer = screenTap
    }

    private func buildOverlays() {
        let scrollButtons = UIStackView(arrangedSubviews: [scrollUpButton, scrollDownButton])
        scrollControls = scrollButtons
        scrollButtons.axis = .vertical
        scrollButtons.spacing = 8
        scrollButtons.translatesAutoresizingMaskIntoConstraints = false
        scrollButtons.isHidden = true
        scrollUpButton.accessibilityIdentifier = "car.browser.scroll.up"
        scrollDownButton.accessibilityIdentifier = "car.browser.scroll.down"
        scrollUpButton.accessibilityLabel = carTr("تمرير للأعلى", "Scroll up")
        scrollDownButton.accessibilityLabel = carTr("تمرير للأسفل", "Scroll down")
        scrollUpButton.addAction(UIAction { [weak self] _ in self?.scrollPage(up: true) }, for: .touchUpInside)
        scrollDownButton.addAction(UIAction { [weak self] _ in self?.scrollPage(up: false) }, for: .touchUpInside)
        view.addSubview(scrollButtons)

        toolbarRevealButton.accessibilityIdentifier = "car.browser.toolbar.reveal"
        toolbarRevealButton.accessibilityLabel = carTr("إظهار شريط المتصفح", "Show browser toolbar")
        toolbarRevealButton.isHidden = true
        toolbarRevealButton.translatesAutoresizingMaskIntoConstraints = false
        toolbarRevealButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.toolbarRevealHideTimer?.invalidate()
            self.toolbarRevealButton.isHidden = true
            self.setToolbarCollapsed(false)
        }, for: .primaryActionTriggered)
        view.addSubview(toolbarRevealButton)
        toolbarHotspot.accessibilityLabel = carTr("إظهار خيارات المتصفح", "Show browser options")
        toolbarHotspot.accessibilityIdentifier = "car.browser.toolbar.hotspot"
        toolbarHotspot.translatesAutoresizingMaskIntoConstraints = false
        toolbarHotspot.addAction(UIAction { [weak self] _ in self?.showToolbarRevealButton() }, for: .primaryActionTriggered)
        view.addSubview(toolbarHotspot)
        toolbarEdge.accessibilityIdentifier = "car.browser.toolbar.edge"
        toolbarEdge.accessibilityLabel = carTr("إظهار شريط المتصفح", "Show browser toolbar")
        toolbarEdge.translatesAutoresizingMaskIntoConstraints = false
        toolbarEdge.addAction(UIAction { [weak self] _ in self?.showToolbarRevealButton() }, for: .primaryActionTriggered)
        view.addSubview(toolbarEdge)
        NSLayoutConstraint.activate([
            toolbarEdge.leftAnchor.constraint(equalTo: view.leftAnchor),
            toolbarEdge.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbarEdge.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            toolbarEdge.widthAnchor.constraint(equalToConstant: 12),
            toolbarHotspot.leftAnchor.constraint(equalTo: view.leftAnchor),
            toolbarHotspot.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbarHotspot.widthAnchor.constraint(equalToConstant: 44),
            toolbarHotspot.heightAnchor.constraint(equalToConstant: 44)
        ])
        // Native controls are activated directly by touch, pointer or focus/primary action.
        toolbarRevealButton.menu = nil
        toolbarRevealButton.showsMenuAsPrimaryAction = false
        (view as? BrowserChromeView)?.toolbar = toolbar

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

        siteErrorLabel.font = .systemFont(ofSize: 19, weight: .semibold)
        siteErrorLabel.textColor = .white
        siteErrorLabel.textAlignment = .center
        siteErrorLabel.numberOfLines = 0
        siteErrorLabel.backgroundColor = UIColor(red: 0.10, green: 0.12, blue: 0.17, alpha: 0.96)
        siteErrorLabel.layer.cornerRadius = 16
        siteErrorLabel.clipsToBounds = true
        siteErrorLabel.isHidden = true
        siteErrorLabel.accessibilityIdentifier = "car.site.error"
        siteErrorLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(siteErrorLabel)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            toolbarRevealButton.leftAnchor.constraint(equalTo: guide.leftAnchor, constant: 4),
            toolbarRevealButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 4),
            toolbarRevealButton.widthAnchor.constraint(equalToConstant: 42),
            toolbarRevealButton.heightAnchor.constraint(equalToConstant: 38),
            scrollButtons.leftAnchor.constraint(equalTo: guide.leftAnchor, constant: 4),
            scrollButtons.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
            scrollUpButton.widthAnchor.constraint(equalToConstant: 42),
            scrollUpButton.heightAnchor.constraint(equalToConstant: 40),
            scrollDownButton.widthAnchor.constraint(equalToConstant: 42),
            scrollDownButton.heightAnchor.constraint(equalToConstant: 40),
            toastLabel.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -24),
            siteErrorLabel.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            siteErrorLabel.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
            siteErrorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: 48),
            siteErrorLabel.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -48),
            siteErrorLabel.widthAnchor.constraint(lessThanOrEqualTo: guide.widthAnchor, multiplier: 0.72)
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

        CarMouseBridge.shared.$isActive
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] active in
                guard let self else { return }
                self.mouseHiddenForIdle = true
                self.mouseHasBeenMoved = false
                self.mouseCursor.isHidden = true
                if active && self.mouseCursorCenter == nil {
                    self.mouseCursorCenter = CGPoint(x: self.contentView.bounds.midX, y: self.contentView.bounds.midY)
                }
                if !active { self.mouseHideTimer?.invalidate() }
                self.updateMouseCursorFrame()
            }
            .store(in: &bag)

        CarMouseBridge.shared.$input
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] input in self?.handleMouseInput(input) }
            .store(in: &bag)
    }

    // MARK: عرض التبويب الحالي

    private func refresh() {
        updateTabsButton()
        guard let tab = store.activeTab else { return }

        if showingHome || tab.url == nil {
            scrollControls.isHidden = true
            scrollButtonsHideTimer?.invalidate()
            shortcutsView.isHidden = false
            contentView.bringSubviewToFront(shortcutsView)
            currentSession?.webView.isHidden = true
            progressView.isHidden = true
            updateMouseCursorFrame()
            updateMouseCursorFrame()
            CarUI.setTitle(urlButton, "أدخل عنوان URL أو ابحث", size: 11)
            backButton.isEnabled = tab.url != nil
            return
        }

        let session = pool.session(for: tab.id)
        if session !== currentSession { attach(session) }
        shortcutsView.isHidden = true
        updateMouseCursorFrame()
        session.webView.isHidden = false
        contentView.bringSubviewToFront(progressView)
        CarUI.setTitle(urlButton, tab.url?.host ?? tab.displayTitle, size: 11)
        backButton.isEnabled = true
    }

    private func attach(_ session: TabSession) {
        sessionBag.removeAll()
        if let old = currentSession {
            if old.isVideoFullscreen { old.exitVideoFullscreen() }
            old.webView.removeFromSuperview()
            viewport?.removeFromSuperview()
        }
        currentSession = session

        let webView = session.webView
        if let webViewTapRecognizer { webViewTapRecognizer.view?.removeGestureRecognizer(webViewTapRecognizer) }
        let webTap = UITapGestureRecognizer(target: self, action: #selector(handleScreenTap(_:)))
        webTap.cancelsTouchesInView = false
        webTap.delaysTouchesBegan = false
        webTap.delaysTouchesEnded = false
        webTap.delegate = self
        webView.addGestureRecognizer(webTap)
        webViewTapRecognizer = webTap
        session.applyCarZoom(WDSettings.carZoom)
        let host = DesktopViewportView(session: session)
        viewport = host
        contentView.insertSubview(host, at: 0)
        CarUI.pin(host, to: contentView)

        session.$isLoading
            .combineLatest(session.$progress)
            .receive(on: RunLoop.main)
            .sink { [weak self] loading, progress in
                guard let self else { return }
                self.progressView.isHidden = !loading || self.showingHome
                self.progressView.setProgress(Float(progress), animated: true)
                if loading { self.hideMouseCursorUntilMoved() }
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

        session.$navigationError
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                self?.siteErrorLabel.text = message
                self?.siteErrorLabel.isHidden = message == nil
            }
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
        hideMouseCursorUntilMoved()
        scrollControls.isHidden = true
        scrollButtonsHideTimer?.invalidate()
        store.open(url, inNewTab: false)
        refresh()
    }

    private func goHome() {
        showingHome = true
        hideMouseCursorUntilMoved()
        currentSession?.pauseMedia()
        refresh()
    }

    private func goBack() {
        if showingHome, store.activeTab?.url != nil {
            showingHome = false
            refresh()
        } else if let session = currentSession, session.canGoBack {
            hideMouseCursorUntilMoved()
            session.goBack()
        } else {
            goHome()
        }
    }

    private func handleMouseInput(_ input: CarMouseBridge.Input) {
        guard mouseControlsAllowed else { return }
        switch input {
        case .move(let delta):
            mouseHasBeenMoved = true
            mouseHiddenForIdle = false
            mouseCursor.isHidden = false
            let center = mouseCursorCenter ?? CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            mouseCursorCenter = CGPoint(
                x: min(max(0, center.x + delta.x * view.bounds.width), view.bounds.width - 1),
                y: min(max(0, center.y + delta.y * view.bounds.height), view.bounds.height - 1)
            )
            updateMouseCursorFrame()
            scheduleMouseCursorHide()
        case .scroll(let delta):
            if showingHome || currentSession == nil || currentSession?.webView.isHidden == true {
                shortcutsView.scrollFromPhone(delta)
                return
            }
            guard let session = currentSession else { return }
            let dx = Double(delta.x), dy = Double(delta.y)
            session.runMouseJavaScript("window.scrollBy({left: innerWidth * \(dx), top: innerHeight * \(dy), behavior: 'smooth'})")
        case .click:
            let clickPoint = mouseCursorCenter ?? CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            if activateBrowserChrome(at: clickPoint) { return }
            if showingHome || currentSession == nil || currentSession?.webView.isHidden == true {
                let point = shortcutsView.convert(clickPoint, from: view)
                shortcutsView.activateShortcut(at: point)
                return
            }
            guard let session = currentSession else { return }
            let point = session.webView.convert(clickPoint, from: view)
            let width = max(session.webView.bounds.width, 1), height = max(session.webView.bounds.height, 1)
            let x = max(0, min(1, point.x / width)), y = max(0, min(1, point.y / height))
            session.runMouseJavaScript("(()=>{const x=innerWidth * \(Double(x)), y=innerHeight * \(Double(y)); const e=document.elementFromPoint(x,y); if(!e)return false; const target=e.closest('a,button,[role=button],input,video,select,textarea')||e; target.click(); return true})()")
        case .navigate(let command):
            switch command {
            case .back: goBack()
            case .forward: currentSession?.webView.goForward()
            case .home: goHome()
            case .reload: currentSession?.reload()
            }
        case .zoom(_):
            break // Page zoom is changed from Settings only.
        case .seek(let seconds):
            if PlaybackManager.shared.current != nil { PlaybackManager.shared.seek(by: seconds) }
            else { currentSession?.seek(by: seconds) }
        case .toggleVideoFullscreen:
            guard let session = currentSession, !showingHome else { return }
            if session.isVideoFullscreen { session.exitVideoFullscreen() }
            else { enterVideoFullscreen() }
        case .playPause:
            if PlaybackManager.shared.current != nil { PlaybackManager.shared.togglePlayPause() }
            else { currentSession?.togglePlay() }
        case .stopPlayback:
            PlaybackManager.shared.stop()
        case .selectSection(_):
            break // CarDashboardViewController and CarTemplateUI own section navigation.
        }
    }

    /// Coordinates are in the root view so the existing phone remote can reach chrome too.
    /// This is separate from physical CarPlay input support and does not emulate a UITouch.
    @discardableResult
    func activateBrowserChrome(at point: CGPoint) -> Bool {
        guard !videoFullscreen, textPanel == nil, tabsPanel == nil else { return false }
        let controls = [toolbarRevealButton, toolbarHotspot, toolbarEdge] + toolbar.arrangedSubviews.compactMap { $0 as? UIButton }
        guard let hit = view.hitTest(point, with: nil),
              let button = controls.first(where: { hit === $0 || hit.isDescendant(of: $0) }),
              !button.isHidden, button.isEnabled else { return false }
        if button === toolbarRevealButton || button === toolbarHotspot || button === toolbarEdge {
            button.sendActions(for: .primaryActionTriggered)
        } else {
            button.sendActions(for: .touchUpInside)
            scheduleToolbarHide()
        }
        return true
    }

    private var mouseControlsAllowed: Bool {
        CarMouseBridge.shared.isActive && !view.isHidden && !DrivingMonitor.shared.isMoving
    }

    private func hideMouseCursorUntilMoved() {
        mouseHideTimer?.invalidate()
        mouseHasBeenMoved = false
        mouseHiddenForIdle = true
        mouseCursor.isHidden = true
    }

    @objc private func handleScreenTap(_ recognizer: UITapGestureRecognizer) {
        guard !videoFullscreen else { return }
        showScrollControls()
        if toolbarCollapsed {
            showToolbarRevealButton()
        } else {
            scheduleToolbarHide()
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIControl { return false }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    private func scrollPage(up: Bool) {
        guard let session = currentSession, !showingHome else { return }
        let amount = up ? -0.75 : 0.75
        session.runMouseJavaScript("window.scrollBy({left: 0, top: innerHeight * \(amount), behavior: 'smooth'})")
        showScrollControls()
    }

    private func showScrollControls() {
        guard !videoFullscreen, !showingHome, store.activeTab?.url != nil else { return }
        scrollControls.isHidden = false
        scrollButtonsHideTimer?.invalidate()
        scrollButtonsHideTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            self?.scrollControls.isHidden = true
        }
    }

    func revealScrollControls() { showScrollControls() }

    private func scheduleMouseCursorHide() {
        mouseHideTimer?.invalidate()
        mouseHideTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            guard let self, CarMouseBridge.shared.isActive else { return }
            self.mouseHiddenForIdle = true
            self.mouseCursor.isHidden = true
        }
    }

    private func updateMouseCursorFrame() {
        guard let mouseCursorCenter else { return }
        mouseCursor.frame = CGRect(x: mouseCursorCenter.x - 13, y: mouseCursorCenter.y - 13, width: 26, height: 26)
        mouseCursor.isHidden = !CarMouseBridge.shared.isActive || !mouseHasBeenMoved || mouseHiddenForIdle
        view.bringSubviewToFront(mouseCursor)
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

    private func enterVideoFullscreen() {
        guard let session = currentSession, !showingHome else { return }
        session.enterVideoFullscreen { [weak self] found in
            if !found { self?.setToolbarCollapsed(true) }
        }
    }

    private func updateTabsButton() {
        var config = tabsButton.configuration
        config?.attributedTitle = AttributedString("\(store.tabs.count)", attributes: AttributeContainer([
            .font: UIFont.systemFont(ofSize: 10, weight: .bold)
        ]))
        config?.imagePadding = 4
        tabsButton.configuration = config
    }

    // MARK: الشريط وملء الشاشة

    private func setToolbarCollapsed(_ collapsed: Bool) {
        toolbarCollapsed = collapsed
        toolbarHideTimer?.invalidate()
        if collapsed { toolbarHideTimer = nil }
        applyToolbarVisibility()
        toolbarRevealHideTimer?.invalidate()
        toolbarRevealButton.isHidden = true
        if !collapsed { scheduleToolbarHide() }
    }

    func revealToolbar() { setToolbarCollapsed(false) }

    private func setVideoFullscreen(_ on: Bool) {
        videoFullscreen = on
        onVideoFullscreenChange?(on)
        if on {
            scrollControls.isHidden = true
            scrollButtonsHideTimer?.invalidate()
            videoOverlay.present()
        } else {
            videoOverlay.isHidden = true
        }
        applyToolbarVisibility()
        updateDrivingLock()
    }

    private func applyToolbarVisibility() {
        let hidden = toolbarCollapsed || videoFullscreen
        toolbar.isHidden = hidden
        toolbarHotspot.isHidden = !hidden || videoFullscreen
        toolbarEdge.isHidden = !hidden || videoFullscreen
        NSLayoutConstraint.deactivate([contentTopToToolbar, contentTopToSafe])
        NSLayoutConstraint.activate([hidden ? contentTopToSafe : contentTopToToolbar])
        view.bringSubviewToFront(scrollControls)
        UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
    }

    private func scheduleToolbarHide() {
        toolbarHideTimer?.invalidate()
        guard !toolbarCollapsed, !videoFullscreen else { return }
        toolbarHideTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
            guard let self, self.textPanel == nil, self.tabsPanel == nil, !self.videoFullscreen else { return }
            self.setToolbarCollapsed(true)
            self.showToolbarRevealButton()
        }
    }

    func showToolbarRevealButton() {
        guard toolbarCollapsed, !videoFullscreen, textPanel == nil, tabsPanel == nil else { return }
        toolbarRevealButton.isHidden = false
        view.bringSubviewToFront(toolbarRevealButton)
        toolbarRevealHideTimer?.invalidate()
        toolbarRevealHideTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            self?.toolbarRevealButton.isHidden = true
        }
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
        scheduleToolbarHide()
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
        scheduleToolbarHide()
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
