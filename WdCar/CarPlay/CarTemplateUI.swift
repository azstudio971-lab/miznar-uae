import CarPlay
import Combine
import CoreMedia
import UIKit

/// واجهة CarPlay الرسمية لصلاحية CarPlay Video (قوالب فقط، بدون WebView على شاشة السيارة):
///
/// • تبويب «الترفيه»: اختصارات المواقع. القوالب لا تعرض صفحات الويب، لذلك يُفتح الموقع على iPhone
///   ويُبث الفيديو لشاشة السيارة عبر AirPlay.
/// • تبويب «Xtream Codes»: الحسابات ← الأقسام ← القنوات/الأفلام. كل عنصر يحمل
///   CPPlaybackConfiguration(preferredPresentation: .video) (iOS 26.4+)، فيعرض CarPlay الفيديو
///   على شاشة السيارة وهي متوقفة، ويحوّله لصوت فقط أثناء القيادة تلقائياً.
final class CarTemplateUI: NSObject, CPSessionConfigurationDelegate {

    private weak var interfaceController: CPInterfaceController?
    private var sessionConfiguration: CPSessionConfiguration?
    private let entertainment = CPListTemplate(title: tr("الترفيه", "Entertainment"), sections: [])
    private let xtream = CPListTemplate(title: "Xtream Codes", sections: [])
    private var bag = Set<AnyCancellable>()
    private var currentShortcuts: [SiteShortcut] = []
    private var lastReportedVideo: Bool?
    private var startedAt = Date()
    private var statusTimer: Timer?

    init(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        super.init()
    }

    deinit { statusTimer?.invalidate() }

    /// يُستدعى عند فصل السيارة
    func stop() {
        statusTimer?.invalidate()
        statusTimer = nil
        bag.removeAll()
    }

    /// هل السيارة المتصلة تدعم تشغيل الفيديو (ميزة Video in Car)؟
    var supportsVideo: Bool {
        if #available(iOS 26.4, *) {
            return sessionConfiguration?.supportsVideoPlayback ?? false
        }
        return false
    }

    func start() {
        sessionConfiguration = CPSessionConfiguration(delegate: self)

        entertainment.tabTitle = tr("الترفيه", "Entertainment")
        entertainment.tabImage = UIImage(systemName: "play.tv")
        entertainment.emptyViewTitleVariants = [tr("أضف مواقع من iPhone", "Add sites on iPhone")]

        xtream.tabTitle = "Xtream"
        xtream.tabImage = UIImage(systemName: "antenna.radiowaves.left.and.right")
        xtream.emptyViewTitleVariants = [tr("أضف حساب Xtream من iPhone", "Add an Xtream account on iPhone")]

        let tabs = CPTabBarTemplate(templates: [entertainment, xtream])
        interfaceController?.setRootTemplate(tabs, animated: false, completion: nil)

        ShortcutStore.shared.$shortcuts
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] shortcuts in self?.rebuildEntertainment(shortcuts) }
            .store(in: &bag)

        XtreamStore.shared.$accounts
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] accounts in self?.rebuildAccounts(accounts) }
            .store(in: &bag)

        AppState.shared.$carScreenActive
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] active in
                guard let self else { return }
                WDLog.car("templates: carScreenActive=\(active)")
                self.rebuildEntertainment(self.currentShortcuts)
            }
            .store(in: &bag)

        WDLog.car("templates connected supportsVideo=\(supportsVideo)")

        // السيارة تعلن قدراتها بعد الاتصال بثوانٍ، فنراقب دعم الفيديو ونعرضه بصدق
        startedAt = Date()
        refreshVideoSupport()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshVideoSupport()
        }
    }

    /// يقرأ دعم الفيديو من السيارة ويحدّث الواجهة والهاتف عند تغيّره
    private func refreshVideoSupport() {
        let current = supportsVideo
        // أول ثوانٍ قد تكون القيمة false لأن السيارة لم تعلن بعد: لا نحكم قبل ٤ ثوانٍ
        if !current && Date().timeIntervalSince(startedAt) < 4 { return }
        AppState.shared.updateCarVideoSupport(current)
        if lastReportedVideo != current {
            lastReportedVideo = current
            WDLog.car("templates: supportsVideoPlayback=\(current)")
            rebuildEntertainment(currentShortcuts)
        }
    }

    func sessionConfiguration(_ sessionConfiguration: CPSessionConfiguration,
                              limitedUserInterfacesChanged limitedUserInterfaces: CPLimitableUserInterface) {}

    // MARK: - الترفيه

    private func rebuildEntertainment(_ shortcuts: [SiteShortcut]) {
        currentShortcuts = shortcuts
        let items = shortcuts.prefix(Self.maxItems - 2).map { shortcut -> CPListItem in
            let item = CPListItem(text: shortcut.name, detailText: shortcut.url.host)
            loadImage(Favicon.url(for: shortcut.url), into: item)
            item.handler = { [weak self] _, completion in
                self?.openShortcut(shortcut.url)
                completion()
            }
            return item
        }
        entertainment.updateSections([
            CPListSection(items: [carScreenItem(), videoStatusItem()]),
            CPListSection(items: Array(items))
        ])
    }

    // MARK: - التحديث 3: المتصفح على شاشة السيارة

    /// العنصر الأول: يفتح متصفح ود كار على شاشة السيارة (كشاشة خارجية) مثل CarTV
    private func carScreenItem() -> CPListItem {
        let active = AppState.shared.carScreenActive
        let item = CPListItem(
            text: tr("المتصفح على شاشة السيارة", "Browser on car screen"),
            detailText: active ? tr("يعمل الآن", "Running now") : tr("اضغط للتشغيل", "Tap to start")
        )
        item.setImage(UIImage(systemName: active ? "safari.fill" : "safari"))
        applyPlaybackConfiguration(to: item)
        item.handler = { [weak self] _, completion in
            self?.startCarScreen()
            completion()
        }
        return item
    }

    private func startCarScreen() {
        WDLog.car("templates: browser item tapped active=\(AppState.shared.carScreenActive) supportsVideo=\(supportsVideo)")
        if AppState.shared.carScreenActive {
            showAlert([
                tr("المتصفح يعمل على شاشة السيارة. افتح المواقع من الهاتف أو من الاختصارات هنا.",
                   "The browser is on the car screen. Open sites from iPhone or from shortcuts here."),
                tr("المتصفح يعمل", "Browser running")
            ])
            return
        }
        // المسار 1: فتح وضع الفيديو من CarPlay مباشرة
        CarScreenLauncher.shared.launch()
        // المسار 2: على الهاتف تظهر نافذة فيها زر AirPlay لاختيار شاشة السيارة
        AppState.shared.showCarScreenHelp = true
        if !supportsVideo {
            showAlert([
                tr("إذا لم يظهر المتصفح، اختر شاشة السيارة من زر AirPlay في ود كار على iPhone.",
                   "If the browser does not appear, choose the car display from AirPlay in WudCar on iPhone."),
                tr("اختر شاشة السيارة من AirPlay", "Choose the car display in AirPlay")
            ])
        }
    }

    /// الاختصار يُفتح على شاشة السيارة إن كان المتصفح معروضاً، وإلا على الهاتف
    private func openShortcut(_ url: URL) {
        if AppState.shared.carScreenActive {
            WDLog.car("templates: open shortcut on car screen \(url.host ?? "")")
            TabStore.car.newTab(url: url)
        } else {
            openOnPhone(url)
        }
    }

    /// صف الحالة: يوضح للمستخدم هل هذه السيارة تقبل الفيديو أم لا
    private func videoStatusItem() -> CPListItem {
        let ok = supportsVideo
        let item = CPListItem(
            text: tr("الفيديو في السيارة", "Video in car"),
            detailText: ok ? tr("مدعوم", "Supported") : tr("غير مدعوم — صوت فقط", "Not supported — audio only")
        )
        item.setImage(UIImage(systemName: ok ? "checkmark.circle.fill" : "speaker.wave.2.circle.fill"))
        item.handler = { [weak self] _, completion in
            self?.explainVideoStatus(supported: ok)
            completion()
        }
        return item
    }

    private func explainVideoStatus(supported: Bool) {
        if supported {
            showAlert([
                tr("السيارة تدعم الفيديو. شغّل الفيديو على iPhone ثم اختر شاشة السيارة من زر AirPlay، والسيارة متوقفة.",
                   "The car supports video. Play the video on iPhone, then choose the car display from AirPlay while parked."),
                tr("الفيديو مدعوم عبر AirPlay", "Video supported via AirPlay")
            ])
        } else {
            showAlert([
                tr("هذه السيارة أو الشاشة لا تعلن دعم الفيديو (Video in Car). هذا قيد من السيارة نفسها، وسيصل الصوت فقط.",
                   "This car or screen does not report Video in Car support. That is a limit of the car itself; only audio will play."),
                tr("الفيديو غير مدعوم هنا — صوت فقط", "Video not supported — audio only")
            ])
        }
    }

    private func openOnPhone(_ url: URL) {
        TabStore.phone.newTab(url: url)
        if supportsVideo {
            showAlert([
                tr("فُتح الموقع على iPhone. شغّل الفيديو واختر شاشة السيارة من زر AirPlay.",
                   "Opened on iPhone. Play the video and choose the car display from AirPlay."),
                tr("فُتح على iPhone — شغّله عبر AirPlay", "Opened on iPhone — use AirPlay")
            ])
        } else {
            showAlert([
                tr("فُتح الموقع على iPhone. هذه السيارة لا تعلن دعم الفيديو، فسيصل الصوت فقط.",
                   "Opened on iPhone. This car does not report video support, so only audio is available."),
                tr("فُتح على iPhone — صوت فقط", "Opened on iPhone — audio only")
            ])
        }
    }

    // MARK: - Xtream

    private func rebuildAccounts(_ accounts: [XtreamAccount]) {
        let items = accounts.map { account -> CPListItem in
            let item = CPListItem(text: account.name, detailText: account.displayHost)
            item.setImage(UIImage(systemName: "antenna.radiowaves.left.and.right"))
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.showCategories(for: account)
                completion()
            }
            return item
        }
        xtream.updateSections([CPListSection(items: items)])
    }

    private func showCategories(for account: XtreamAccount) {
        let template = loadingTemplate(title: account.name)
        interfaceController?.pushTemplate(template, animated: true, completion: nil)

        Task { [weak self] in
            let client = XtreamClient(account: account)
            do {
                async let live = client.categories(.live)
                async let movies = client.categories(.movies)
                let (liveCategories, movieCategories) = try await (live, movies)
                await MainActor.run {
                    guard let self else { return }
                    var sections: [CPListSection] = []
                    for (kind, categories) in [(XtreamKind.live, liveCategories), (XtreamKind.movies, movieCategories)] where !categories.isEmpty {
                        let items = categories.prefix(Self.maxItems).map { category -> CPListItem in
                            let item = CPListItem(text: category.name, detailText: nil)
                            item.accessoryType = .disclosureIndicator
                            item.handler = { [weak self] _, completion in
                                self?.showStreams(account: account, kind: kind, category: category)
                                completion()
                            }
                            return item
                        }
                        sections.append(CPListSection(items: Array(items), header: kind.title, sectionIndexTitle: nil))
                    }
                    template.emptyViewTitleVariants = [tr("لا يوجد محتوى", "No content")]
                    template.updateSections(sections)
                }
            } catch {
                await MainActor.run { self?.fail(template, error) }
            }
        }
    }

    private func showStreams(account: XtreamAccount, kind: XtreamKind, category: XtreamCategory) {
        let template = loadingTemplate(title: category.name)
        interfaceController?.pushTemplate(template, animated: true, completion: nil)

        Task { [weak self] in
            let client = XtreamClient(account: account)
            do {
                let streams = try await client.streams(kind, categoryID: category.id)
                await MainActor.run {
                    guard let self else { return }
                    let items = streams.prefix(Self.maxItems).map { stream -> CPListItem in
                        let item = CPListItem(text: stream.name, detailText: kind == .live ? tr("مباشر", "Live") : nil)
                        self.loadImage(stream.icon, into: item)
                        self.applyPlaybackConfiguration(to: item)
                        item.handler = { [weak self] _, completion in
                            self?.play(stream, account: account, client: client)
                            completion()
                        }
                        return item
                    }
                    template.emptyViewTitleVariants = [tr("لا يوجد محتوى", "No content")]
                    template.updateSections([CPListSection(items: Array(items))])
                }
            } catch {
                await MainActor.run { self?.fail(template, error) }
            }
        }
    }

    /// إعلان العنصر كمحتوى فيديو: CarPlay يعرضه فيديو عند التوقف، وصوتاً أثناء القيادة
    private func applyPlaybackConfiguration(to item: CPListItem) {
        if #available(iOS 26.4, *) {
            item.playbackConfiguration = CPPlaybackConfiguration(
                preferredPresentation: supportsVideo ? .video : .audio,
                playbackAction: .play,
                elapsedTime: .zero,
                duration: .zero
            )
        }
    }

    private func play(_ stream: XtreamStream, account: XtreamAccount, client: XtreamClient) {
        guard let url = client.playbackURL(for: stream) else {
            showAlert([XtreamError.missingPassword.localizedDescription])
            return
        }
        PlaybackManager.shared.play(.init(title: stream.name,
                                          subtitle: account.name,
                                          url: url,
                                          isLive: stream.kind == .live,
                                          artworkURL: stream.icon),
                                    presentOnPhone: false)
        // مع دعم الفيديو يعرض CarPlay المشغل تلقائياً. بدونه نعرض شاشة التشغيل الحالي (صوت).
        if !supportsVideo {
            interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
        }
    }

    // MARK: - أدوات

    private static var maxItems: Int { min(200, CPListTemplate.maximumItemCount) }

    private func loadingTemplate(title: String) -> CPListTemplate {
        let template = CPListTemplate(title: title, sections: [])
        template.emptyViewTitleVariants = [tr("جارِ التحميل…", "Loading…")]
        return template
    }

    private func fail(_ template: CPListTemplate, _ error: Error) {
        template.emptyViewTitleVariants = [error.localizedDescription]
        template.emptyViewSubtitleVariants = [tr("تحقق من الحساب على iPhone", "Check the account on iPhone")]
        template.updateSections([])
    }

    private func loadImage(_ url: URL?, into item: CPListItem) {
        ImageLoader.shared.load(url) { image in
            guard let image else { return }
            let size = CPListItem.maximumImageSize
            let resized = UIGraphicsImageRenderer(size: size).image { _ in
                let scale = min(size.width / image.size.width, size.height / image.size.height)
                let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                image.draw(in: CGRect(x: (size.width - drawSize.width) / 2,
                                      y: (size.height - drawSize.height) / 2,
                                      width: drawSize.width, height: drawSize.height))
            }
            item.setImage(resized)
        }
    }

    private func showAlert(_ titles: [String]) {
        let ok = CPAlertAction(title: tr("حسناً", "OK"), style: .default) { [weak self] _ in
            self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
        }
        interfaceController?.presentTemplate(CPAlertTemplate(titleVariants: titles, actions: [ok]),
                                             animated: true, completion: nil)
    }
}
