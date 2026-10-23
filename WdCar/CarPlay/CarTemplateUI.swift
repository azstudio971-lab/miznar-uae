import CarPlay
import Combine
import CoreMedia
import UIKit

/// Main CarPlay navigation uses Apple's list/tab/Now Playing templates.
/// Native video presentation is selected only through CPPlaybackConfiguration.
final class CarTemplateUI: NSObject, CPSessionConfigurationDelegate, CPTabBarTemplateDelegate {

    private var interfaceController: CPInterfaceController?
    private var sessionConfiguration: CPSessionConfiguration?
    private var home = CPListTemplate(title: carTr("WudCar • مشغّل للفيديو والصوت", "WudCar • Video and audio player"), sections: [])
    private var favorites = CPListTemplate(title: carTr("المفضلة", "Favorites"), sections: [])
    private var filesAndCast = CPListTemplate(title: carTr("الملفات والبث", "Files & AirPlay"), sections: [])
    private var entertainment = CPListTemplate(title: carTr("الترفيه", "Entertainment"), sections: [])
    private var settings = CPListTemplate(title: carTr("الإعدادات", "Settings"), sections: [])
    private var television = CPListTemplate(title: carTr("التلفزيون TV", "TV"), sections: [])
    private var bag = Set<AnyCancellable>()
    private var currentShortcuts: [SiteShortcut] = []
    private var lastReportedVideo: Bool?
    private var startedAt = Date()
    private var statusTimer: Timer?
    private var tabBar: CPTabBarTemplate?

    init(interfaceController: CPInterfaceController?) {
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
        // Complete the initial root installation before loading or replacing it.
        let root = makeLaunchTemplate()
        interfaceController?.setRootTemplate(root, animated: false) { [weak self] success, error in
            CarPlayLaunchDiagnostics.shared.record(success ? "initial-root-installed" : "initial-root-failed: \(error?.localizedDescription ?? "unknown")")
            if success { self?.startMediaInterface() }
        }
    }

    private func startMediaInterface() {
        sessionConfiguration = CPSessionConfiguration(delegate: self)
        prepareTemplates()
        installRoot()

        SubscriptionStore.shared.$state.removeDuplicates().receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.rebuildEntertainment(self.currentShortcuts)
                self.rebuildTelevision()
                self.rebuildMediaLists()
            }.store(in: &bag)

        ShortcutStore.shared.$shortcuts
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] shortcuts in self?.rebuildEntertainment(shortcuts) }
            .store(in: &bag)

        MediaLibrary.shared.$items
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMediaLists() }
            .store(in: &bag)

        XtreamStore.shared.$accounts
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildTelevision() }
            .store(in: &bag)

        M3UStore.shared.$playlists
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildTelevision() }
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

        CarMouseBridge.shared.$input
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                guard let self, let input = value else { return }
                switch input {
                case .selectSection(let section):
                    let template: CPTemplate
                    switch section {
                    case .home: template = self.home
                    case .entertainment: template = self.entertainment
                    case .television: template = self.television
                    case .settings: template = self.settings
                    }
                    if section == .television {
                        self.interfaceController?.pushTemplate(template, animated: true, completion: nil)
                    } else { self.tabBar?.select(template) }
                case .playPause:
                    if !AppState.shared.carScreenActive { PlaybackManager.shared.togglePlayPause() }
                case .stopPlayback:
                    PlaybackManager.shared.stop()
                    self.interfaceController?.popToRootTemplate(animated: true, completion: nil)
                case .seek(let seconds):
                    if !AppState.shared.carScreenActive { PlaybackManager.shared.seek(by: seconds) }
                default:
                    break
                }
            }
            .store(in: &bag)

        WDLog.car("templates connected supportsVideo=\(supportsVideo)")
        startedAt = Date()
        refreshVideoSupport()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshVideoSupport()
        }
    }

    func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate) {
        // Selecting a tab must not start unrelated media or bootstrap an external display.
    }

    /// Also used by the native regression test to inspect the actual template tree.
    func prepareTemplates() {
        home = CPListTemplate(title: carTr("WudCar • مشغّل للفيديو والصوت", "WudCar • Video and audio player"), sections: [])
        favorites = CPListTemplate(title: carTr("المفضلة", "Favorites"), sections: [])
        filesAndCast = CPListTemplate(title: carTr("الملفات والبث", "Files & AirPlay"), sections: [])
        television = CPListTemplate(title: carTr("القنوات والقوائم", "Channels & playlists"), sections: [])
        entertainment = CPListTemplate(title: carTr("الترفيه / المتصفح", "Entertainment / Browser"), sections: [])
        settings = CPListTemplate(title: carTr("الإعدادات", "Settings"), sections: [])
        for (template, title, symbol) in [
            (home, carTr("المكتبة", "Library"), "play.rectangle.on.rectangle"),
            (favorites, carTr("المفضلة", "Favorites"), "star.fill"),
            (filesAndCast, carTr("الملفات والبث", "Files & AirPlay"), "airplay.video"),
            (entertainment, carTr("الترفيه", "Entertainment"), "safari"),
            (settings, carTr("الإعدادات", "Settings"), "gearshape.fill")
        ] {
            template.tabTitle = title
            template.tabImage = UIImage(systemName: symbol)
        }
        television.emptyViewTitleVariants = [carTr("أضف حساب Xtream أو قائمة M3U من iPhone", "Add an Xtream account or M3U playlist on iPhone")]
        rebuildMediaLists()
        rebuildEntertainment(ShortcutStore.shared.shortcuts)
        rebuildTelevision()
        rebuildSettings()
    }

    func makeRootTemplate(maximumTabCount: Int) -> CPTemplate {
        let templates: [CPTemplate] = [home, favorites, filesAndCast, entertainment, settings]
        if maximumTabCount >= templates.count {
            let tabs = CPTabBarTemplate(templates: templates)
            tabs.delegate = self
            tabBar = tabs
            return tabs
        }
        tabBar = nil
        return CPListTemplate(title: carTr("WudCar • مشغّل للفيديو والصوت", "WudCar • Video and audio player"), sections: [
            CPListSection(items: templates.map { template in
                navigationItem(template.tabTitle ?? "WudCar", symbol: nil, template: template)
            })
        ])
    }

    func makeLaunchTemplate() -> CPListTemplate {
        CPListTemplate(title: carTr("WudCar • مشغّل للفيديو والصوت", "WudCar • Video and audio player"), sections: [CPListSection(items: [
            CPListItem(text: carTr("مشغّل للفيديو والصوت", "Video and audio player"), detailText: carTr("جارِ فتح المكتبة والمفضلة…", "Opening your library and favorites…"))
        ])])
    }

    private func installRoot() {
        // Keep one simple, nonempty CPListTemplate as the entry point. Each row
        // opens a native destination; no external UIWindow or tab renderer owns it.
        let root = makeRootTemplate(maximumTabCount: 0)
        interfaceController?.setRootTemplate(root, animated: false) { [weak self] success, error in
            CarPlayLaunchDiagnostics.shared.record(success ? "media-root-installed" : "media-root-failed: \(error?.localizedDescription ?? "unknown")")
            if !success {
                self?.interfaceController?.setRootTemplate(self?.makeLaunchTemplate() ?? CPListTemplate(title: "WudCar", sections: []), animated: false, completion: nil)
            }
        }
    }

    private func navigationItem(_ title: String, symbol: String?, template: CPTemplate) -> CPListItem {
        let row = CPListItem(text: title, detailText: nil, image: symbol.flatMap { UIImage(systemName: $0) })
        row.accessoryType = .disclosureIndicator
        row.handler = { [weak self] _, completion in
            self?.interfaceController?.pushTemplate(template, animated: true, completion: nil)
            completion()
        }
        return row
    }

    private func mediaRows(_ entries: [LibraryMedia]) -> [CPListItem] {
        entries.prefix(Self.maxItems).map { media in
            let row = CPListItem(text: media.title, detailText: media.localFilename == nil ? carTr("مصدر إنترنت", "Internet source") : carTr("ملف مستورد • دون إنترنت", "Imported file • Offline"))
            if let image = UIImage(contentsOfFile: MediaLibrary.shared.thumbnailURL(media.id).path) { row.setImage(image) }
            applyPlaybackConfiguration(to: row)
            row.handler = { [weak self] _, completion in
                guard SubscriptionStore.shared.hasAccess else {
                    self?.showAlert([carTr("فعّل الاشتراك من iPhone أثناء التوقف.", "Activate your subscription on iPhone while parked.")])
                    completion(); return
                }
                CarScreenLauncher.shared.closeBrowser()
                PlaybackManager.shared.playQueue(entries.compactMap(\.playbackItem), startingAt: media.url, presentOnPhone: false)
                if self?.supportsVideo != true {
                    self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
                }
                completion()
            }
            return row
        }
    }

    private func mediaTemplate(_ title: String, entries: [LibraryMedia]) -> CPListTemplate {
        let template = CPListTemplate(title: title, sections: [CPListSection(items: mediaRows(entries))])
        template.emptyViewTitleVariants = [carTr("أضف ملفات وروابط من مكتبة iPhone", "Add files and URLs from the iPhone library")]
        return template
    }

    var favoriteTitles: [String] {
        favorites.sections.flatMap(\.items).compactMap { ($0 as? CPListItem)?.text }
    }

    private func rebuildMediaLists() {
        let media = MediaLibrary.shared.items
        var sections = [CPListSection(items: [
            CPListItem(text: carTr("مشغّل للفيديو والصوت", "Video and audio player"), detailText: carTr("محتواك من iPhone • لا نوفر قنوات أو اشتراكات محتوى", "Your media from iPhone • No channels or content subscriptions supplied")),
            navigationItem(carTr("القنوات وقوائم M3U / Xtream", "Channels and M3U / Xtream playlists"), symbol: "tv", template: television)
        ])]
        let recent = media.filter { $0.position > 0 }.sorted { ($0.lastPlayed ?? $0.added) > ($1.lastPlayed ?? $1.added) }
        if !recent.isEmpty { sections.append(CPListSection(items: mediaRows(Array(recent.prefix(20))), header: carTr("متابعة المشاهدة", "Continue watching"), sectionIndexTitle: nil)) }
        if !media.isEmpty { sections.append(CPListSection(items: mediaRows(Array(media.prefix(max(0, Self.maxItems - 22)))), header: carTr("مكتبة المشغّل", "Player library"), sectionIndexTitle: nil)) }
        else { sections.append(CPListSection(items: [CPListItem(text: carTr("المكتبة فارغة", "Your library is empty"), detailText: carTr("استورد فيديو أو أضف رابطًا من مكتبة الهاتف.", "Import a video or add a URL in the iPhone library."))])) }
        home.updateSections(sections)
        favorites.updateSections([CPListSection(items: mediaRows(media.filter(\.favorite)))])
        favorites.emptyViewTitleVariants = [carTr("لا توجد وسائط مفضلة", "No favorite media")]
        favorites.emptyViewSubtitleVariants = [carTr("أضف للمفضلة من مكتبة iPhone؛ مفضلة القنوات داخل قوائمها.", "Favorite media in the iPhone library; channel favorites are inside their playlists.")]
        filesAndCast.updateSections([CPListSection(items: [
            navigationItem(carTr("الفيديوهات المستوردة", "Imported videos"), symbol: "folder", template: mediaTemplate(carTr("الملفات المحلية", "Local files"), entries: media.filter { $0.localFilename != nil })),
            navigationItem(carTr("روابط الوسائط والبث", "Media URLs & streams"), symbol: "network", template: mediaTemplate(carTr("روابط الوسائط", "Media URLs"), entries: media.filter { $0.localFilename == nil })),
            navigationItem(carTr("البث إلى الشاشة • AirPlay", "Send media to a display • AirPlay"), symbol: "airplay.video", template: castingTemplate())
        ])])
    }

    private func castingTemplate() -> CPListTemplate {
        CPListTemplate(title: carTr("البث إلى الشاشة", "Send media to a display"), sections: [CPListSection(items: [
            CPListItem(text: carTr("إرسال فيديو عبر AirPlay", "Send video with AirPlay"), detailText: carTr("من مكتبة WudCar على iPhone افتح «البث إلى الشاشة»، شغّل فيديو واختر جهازًا من زر AirPlay.", "On iPhone, open Library → Send to display, play a video and choose a device with AirPlay.")),
            videoStatusItem(),
            CPListItem(text: carTr("عرض الفيديو حسب سماح النظام والسيارة", "Video follows system and vehicle permission"), detailText: carTr("إذا حُجب الفيديو، يتحكم النظام بإخراج الصوت. استخدم الشاشة أثناء الوقوف فقط.", "If video is blocked, the system controls audio output. Use the display only while parked.")),
            CPListItem(text: carTr("عكس شاشة iPhone بالكامل غير متاح", "Full iPhone screen mirroring is unavailable"), detailText: carTr("هذه الوظيفة ترسل الوسائط من المشغّل، ولا تستقبل AirPlay أو DLNA.", "This sends player media; it does not receive AirPlay or DLNA."))
        ])])
    }

    private func rebuildSettings() {
        let language = settingItem(
            carTr("اللغة", "Language"),
            detail: WDSettings.carLanguage == "ar" ? "العربية" : "English",
            symbol: "globe"
        ) { [weak self] in
            WDSettings.carLanguage = WDSettings.carLanguage == "ar" ? "en" : "ar"
            guard let self else { return }
            self.prepareTemplates()
            self.installRoot()
        }
        let display = settingItem(
            carTr("عرض المواقع", "Website layout"),
            detail: WDSettings.carDesktopMode ? carTr("سطح المكتب", "Desktop") : carTr("الهاتف", "Mobile"),
            symbol: "desktopcomputer"
        ) { [weak self] in
            WDSettings.carDesktopMode.toggle()
            WebViewPool.car.applyDesktopMode(WDSettings.carDesktopMode)
            self?.rebuildSettings()
        }
        let zoomOut = settingItem(
            carTr("تصغير الصفحة 5٪", "Zoom out 5%"),
            detail: nil,
            symbol: "minus.magnifyingglass"
        ) { [weak self] in self?.changeZoom(by: -5) }
        zoomOut.isEnabled = WDSettings.carZoom > 0.5
        let zoomIn = settingItem(
            carTr("تكبير الصفحة 5٪", "Zoom in 5%"),
            detail: nil,
            symbol: "plus.magnifyingglass"
        ) { [weak self] in self?.changeZoom(by: 5) }
        zoomIn.isEnabled = WDSettings.carZoom < 1.5
        let zoom = CPListItem(
            text: carTr("نسبة عرض الصفحة", "Page zoom"),
            detailText: "\(Int((WDSettings.carZoom * 100).rounded()))%",
            image: UIImage(systemName: "viewfinder")
        )
        let reset = settingItem(carTr("إعادة إلى 100٪", "Reset to 100%"), detail: nil, symbol: "arrow.counterclockwise") { [weak self] in
            WDSettings.carZoom = 1.0
            WebViewPool.car.applyZoom(1.0)
            self?.rebuildSettings()
        }
        let skip = settingItem(carTr("التقديم والتأخير", "Skip interval"), detail: "\(PlayerPreferences.skip) " + carTr("ثانية", "seconds"), symbol: "goforward.15") { [weak self] in
            let values = [10, 15, 30]
            let index = values.firstIndex(of: PlayerPreferences.skip) ?? 1
            UserDefaults.standard.set(values[(index + 1) % values.count], forKey: "wd.media.skip")
            self?.rebuildSettings()
        }
        let resume = settingItem(carTr("الاستئناف من آخر موضع", "Resume from last position"), detail: PlayerPreferences.resume ? carTr("مفعّل", "On") : carTr("متوقف", "Off"), symbol: "play.circle") { [weak self] in
            UserDefaults.standard.set(!PlayerPreferences.resume, forKey: "wd.media.resume")
            self?.rebuildSettings()
        }
        settings.updateSections([
            CPListSection(items: [CPListItem(text: carTr("WudCar • مشغّل فيديو ووسائط", "WudCar • Video & media player"), detailText: carTr("لا نوفر المحتوى. إدارة المصادر والخصوصية من إعدادات iPhone.", "No content supplied. Manage sources and read privacy terms in iPhone Settings.")), skip, resume, language], header: carTr("المشغّل", "Player"), sectionIndexTitle: nil),
            CPListSection(items: [display, zoomOut, zoom, zoomIn, reset], header: carTr("المتصفح", "Browser"), sectionIndexTitle: nil)
        ])
    }

    private func settingItem(_ title: String, detail: String?, symbol: String, action: @escaping () -> Void) -> CPListItem {
        let item = CPListItem(text: title, detailText: detail, image: UIImage(systemName: symbol))
        item.handler = { _, completion in
            action()
            completion()
        }
        return item
    }

    private func changeZoom(by percentage: Int) {
        let current = Int((WDSettings.carZoom * 100).rounded())
        let updated = min(150, max(50, current + percentage))
        let zoom = Double(updated) / 100.0
        WDSettings.carZoom = zoom
        WebViewPool.car.applyZoom(zoom)
        rebuildSettings()
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
            rebuildMediaLists()
        }
    }

    func sessionConfiguration(_ sessionConfiguration: CPSessionConfiguration,
                              limitedUserInterfacesChanged limitedUserInterfaces: CPLimitableUserInterface) {}

    // MARK: - الترفيه

    private func rebuildEntertainment(_ shortcuts: [SiteShortcut]) {
        currentShortcuts = shortcuts
        guard SubscriptionStore.shared.hasAccess else {
            entertainment.updateSections([CPListSection(items: [CPListItem(text: carTr("الاشتراك مطلوب", "Subscription required"), detailText: carTr("فعّل الاشتراك من تطبيق iPhone أثناء التوقف.", "Subscribe in the iPhone app while parked."))])]); return
        }
        let items = shortcuts.prefix(Self.maxItems - 3).map { shortcut -> CPListItem in
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
        let item = CPListItem(text: carTr("المتصفح على iPhone", "Browser on iPhone"), detailText: carTr("افتح المواقع من الهاتف؛ القوالب لا تعرض صفحات ويب.", "Open sites on iPhone; templates do not render web pages."))
        item.setImage(UIImage(systemName: "safari"))
        item.handler = { [weak self] _, completion in
            self?.startCarScreen()
            completion()
        }
        return item
    }

    private func startCarScreen() {
        AppState.shared.showCarScreenHelp = true
        showAlert([carTr("المتصفح متاح على iPhone. لتشغيل محتوى متوافق على السيارة استخدم المشغّل وزر AirPlay أثناء الوقوف، وفق دعم النظام والسيارة.", "The browser is available on iPhone. For compatible in-car media, use the player and AirPlay while parked, subject to system and vehicle support.")])
    }

    /// الاختصار يُفتح على شاشة السيارة إن كان المتصفح معروضاً، وإلا على الهاتف
    private func openShortcut(_ url: URL) {
        guard SubscriptionStore.shared.hasAccess else { startCarScreen(); return }
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
            text: carTr("الفيديو في السيارة", "Video in car"),
            detailText: ok ? carTr("مدعوم", "Supported") : carTr("غير مدعوم — صوت فقط", "Not supported — audio only")
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
                carTr("السيارة تدعم الفيديو. شغّل الفيديو على iPhone ثم اختر شاشة السيارة من زر AirPlay، والسيارة متوقفة.",
                   "The car supports video. Play the video on iPhone, then choose the car display from AirPlay while parked."),
                carTr("الفيديو مدعوم عبر AirPlay", "Video supported via AirPlay")
            ])
        } else {
            showAlert([
                carTr("هذه السيارة أو الشاشة لا تعلن دعم الفيديو (Video in Car). هذا قيد من السيارة نفسها، وسيصل الصوت فقط.",
                   "This car or screen does not report Video in Car support. That is a limit of the car itself; only audio will play."),
                carTr("الفيديو غير مدعوم هنا — صوت فقط", "Video not supported — audio only")
            ])
        }
    }

    private func openOnPhone(_ url: URL) {
        TabStore.phone.newTab(url: url)
        if supportsVideo {
            showAlert([
                carTr("فُتح الموقع على iPhone. شغّل الفيديو واختر شاشة السيارة من زر AirPlay.",
                   "Opened on iPhone. Play the video and choose the car display from AirPlay."),
                carTr("فُتح على iPhone — شغّله عبر AirPlay", "Opened on iPhone — use AirPlay")
            ])
        } else {
            showAlert([
                carTr("فُتح الموقع على iPhone. هذه السيارة لا تعلن دعم الفيديو، فسيصل الصوت فقط.",
                   "Opened on iPhone. This car does not report video support, so only audio is available."),
                carTr("فُتح على iPhone — صوت فقط", "Opened on iPhone — audio only")
            ])
        }
    }

    // MARK: - Xtream

    private func rebuildTelevision() {
        guard SubscriptionStore.shared.hasAccess else {
            television.updateSections([CPListSection(items: [CPListItem(text: carTr("الاشتراك مطلوب", "Subscription required"), detailText: carTr("فعّل الاشتراك من تطبيق iPhone أثناء التوقف.", "Subscribe in the iPhone app while parked."))])]); return
        }
        let accounts = XtreamStore.shared.accounts.map { account -> CPListItem in
            let item = CPListItem(text: account.name, detailText: account.displayHost)
            item.setImage(UIImage(systemName: "antenna.radiowaves.left.and.right"))
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.showCategories(for: account)
                completion()
            }
            return item
        }
        let playlists = M3UStore.shared.playlists.map { playlist -> CPListItem in
            let item = CPListItem(text: playlist.name, detailText: "M3U / M3U8")
            item.setImage(UIImage(systemName: "list.bullet.rectangle"))
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.showM3UEntries(for: playlist)
                completion()
            }
            return item
        }
        var sections: [CPListSection] = []
        if !accounts.isEmpty { sections.append(CPListSection(items: accounts, header: "Xtream Codes", sectionIndexTitle: nil)) }
        if !playlists.isEmpty { sections.append(CPListSection(items: playlists, header: "M3U", sectionIndexTitle: nil)) }
        television.updateSections(sections)
    }

    private func showM3UEntries(for playlist: M3UPlaylist) {
        let template = loadingTemplate(title: playlist.name)
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
        Task { [weak self] in
            do {
                let entries = try await M3UStore.shared.entries(for: playlist)
                await MainActor.run {
                    guard let self else { return }
                    let favorites = M3UStore.shared.favorites(in: playlist, entries: entries)
                    let groups = Dictionary(grouping: entries, by: { $0.group.isEmpty ? carTr("قنوات أخرى", "Other channels") : $0.group })
                    var sections: [CPListSection] = []
                    if !favorites.isEmpty {
                        sections.append(self.m3uSection(carTr("المفضلة", "Favorites"), entries: favorites, playlist: playlist))
                    }
                    for key in groups.keys.sorted() {
                        if let values = groups[key] {
                            sections.append(self.m3uSection(key, entries: values, playlist: playlist))
                        }
                    }
                    template.emptyViewTitleVariants = [carTr("لا يوجد محتوى", "No content")]
                    template.updateSections(sections)
                }
            } catch {
                await MainActor.run { self?.fail(template, error) }
            }
        }
    }

    private func m3uSection(_ title: String, entries: [M3UEntry], playlist: M3UPlaylist) -> CPListSection {
        let items = entries.prefix(Self.maxItems).map { entry -> CPListItem in
            let item = CPListItem(text: entry.title, detailText: nil)
            loadImage(entry.logo, into: item)
            applyPlaybackConfiguration(to: item)
            item.handler = { [weak self] _, completion in
                guard let self else { completion(); return }
                PlaybackManager.shared.play(.init(title: entry.title,
                                                  subtitle: playlist.name,
                                                  url: entry.url,
                                                  isLive: true,
                                                  artworkURL: entry.logo, sourceKey: "m3u-\(playlist.id.uuidString)"),
                                            presentOnPhone: false)
                if !self.supportsVideo {
                    self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
                }
                completion()
            }
            return item
        }
        return CPListSection(items: Array(items), header: title, sectionIndexTitle: nil)
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
                    template.emptyViewTitleVariants = [carTr("لا يوجد محتوى", "No content")]
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
                        let item = CPListItem(text: stream.name, detailText: kind == .live ? carTr("مباشر", "Live") : nil)
                        self.loadImage(stream.icon, into: item)
                        self.applyPlaybackConfiguration(to: item)
                        item.handler = { [weak self] _, completion in
                            self?.play(stream, account: account, client: client)
                            completion()
                        }
                        return item
                    }
                    template.emptyViewTitleVariants = [carTr("لا يوجد محتوى", "No content")]
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
                                          artworkURL: stream.icon, sourceKey: "xtream-\(account.id.uuidString)"),
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
        template.emptyViewTitleVariants = [carTr("جارِ التحميل…", "Loading…")]
        return template
    }

    private func fail(_ template: CPListTemplate, _ error: Error) {
        template.emptyViewTitleVariants = [error.localizedDescription]
        template.emptyViewSubtitleVariants = [carTr("تحقق من الحساب على iPhone", "Check the account on iPhone")]
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
        let ok = CPAlertAction(title: carTr("حسناً", "OK"), style: .default) { [weak self] _ in
            self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
        }
        interfaceController?.presentTemplate(CPAlertTemplate(titleVariants: titles, actions: [ok]),
                                             animated: true, completion: nil)
    }
}

