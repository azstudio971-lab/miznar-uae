import CarPlay
import Combine
import CoreMedia
import CoreLocation
import UIKit

/// واجهة CarPlay الرسمية لصلاحية CarPlay Video (قوالب فقط، بدون WebView على شاشة السيارة):
///
/// • تبويب «الترفيه»: اختصارات المواقع. القوالب لا تعرض صفحات الويب، لذلك يُفتح الموقع على iPhone
///   ويُبث الفيديو لشاشة السيارة عبر AirPlay.
/// • تبويب «Xtream Codes»: الحسابات ← الأقسام ← القنوات/الأفلام. كل عنصر يحمل
///   CPPlaybackConfiguration(preferredPresentation: .video) (iOS 26.4+)، فيعرض CarPlay الفيديو
///   على شاشة السيارة وهي متوقفة، ويحوّله لصوت فقط أثناء القيادة تلقائياً.
final class CarTemplateUI: NSObject, CPSessionConfigurationDelegate, CPTabBarTemplateDelegate, CPNowPlayingTemplateObserver {

    private var interfaceController: CPInterfaceController?
    private var sessionConfiguration: CPSessionConfiguration?
    private let home = CPListTemplate(title: carTr("المكتبة", "Library"), sections: [])
    private let entertainment = CPListTemplate(title: carTr("المفضلة", "Favorites"), sections: [])
    private let cast = CPListTemplate(title: "Cast", sections: [])
    private let settings = CPListTemplate(title: carTr("الإعدادات", "Settings"), sections: [])
    private let television = CPListTemplate(title: carTr("التلفزيون TV", "TV"), sections: [])
    private var bag = Set<AnyCancellable>()
    private var currentShortcuts: [SiteShortcut] = []
    private var lastReportedVideo: Bool?
    private var startedAt = Date()
    private var statusTimer: Timer?
    private var tabBar: CPTabBarTemplate?
    private var browserWarningAccepted = false
    private var favoriteChannelRows: [CPListItem] = []
    static let tabOrder = ["library", "tv", "favorites", "cast"]
    static func makeTabBar(library: CPTemplate, tv: CPTemplate, favorites: CPTemplate, settings: CPTemplate) -> CPTabBarTemplate {
        let values = ["library": library, "tv": tv, "favorites": favorites, "cast": settings]
        return CPTabBarTemplate(templates: tabOrder.compactMap { values[$0] })
    }

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
        CPNowPlayingTemplate.shared.remove(self)
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
        let now = CPNowPlayingTemplate.shared
        now.add(self)
        now.isUpNextButtonEnabled = true
        now.upNextTitle = carTr("التالي", "Up next")
        let rate = CPNowPlayingPlaybackRateButton { _ in }
        // Playback speed is phone-only; retain the official control without changing car playback speed.
        rate.isEnabled = false
        now.updateNowPlayingButtons([rate])
        #if WUDCAR_IOS27_SDK
        if #available(iOS 27.0, *) { now.allowsMiniPlayer = true }
        #endif
        MediaLibrary.shared.$items.combineLatest(MediaLibrary.shared.$playlists)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in self?.rebuildHome(); self?.rebuildEntertainment(self?.currentShortcuts ?? []) }.store(in: &bag)

        let search = CPBarButton(type: .image) { [weak self] _ in
            AppState.shared.showMediaSearch = true
            self?.showAlert([carTr("اكتب على iPhone أثناء التوقف", "Search on iPhone while parked")])
        }
        search.image = UIImage(systemName: "magnifyingglass")
        home.trailingNavigationBarButtons = [search]
        television.trailingNavigationBarButtons = [search]
        home.tabTitle = carTr("المكتبة", "Library")
        home.tabImage = UIImage(systemName: "play.rectangle.on.rectangle")
        entertainment.tabTitle = carTr("المفضلة", "Favorites")
        entertainment.tabImage = UIImage(systemName: "star.fill")
        entertainment.emptyViewTitleVariants = [carTr("أضف مواقع من iPhone", "Add sites on iPhone")]
        television.tabTitle = carTr("البث", "TV")
        television.tabImage = UIImage(systemName: "antenna.radiowaves.left.and.right")
        television.emptyViewTitleVariants = [carTr("أضف حساب Xtream أو قائمة M3U من iPhone", "Add an Xtream account or M3U playlist on iPhone")]
        settings.tabTitle = carTr("الإعدادات", "Settings")
        settings.tabImage = UIImage(systemName: "gearshape.fill")

        cast.tabTitle = "Cast"
        cast.tabImage = UIImage(systemName: "airplay.video")
        let tabs = Self.makeTabBar(library: home, tv: television, favorites: entertainment, settings: cast)
        tabs.delegate = self
        tabBar = tabs
        rebuildHome()
        rebuildEntertainment(ShortcutStore.shared.shortcuts)
        rebuildTelevision()
        rebuildSettings()
        rebuildCast()
        ScreenRelay.shared.$active.receive(on: RunLoop.main).sink { [weak self] _ in self?.rebuildCast() }.store(in: &bag)
        SourceStore.shared.$sources.debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildHome(); self?.rebuildTelevision() }.store(in: &bag)
        interfaceController?.setRootTemplate(tabs, animated: false) { [weak self] success, error in
            WDLog.car("root template installed=\(success) error=\(String(describing: error))")
            guard !success, let self else { return }
            let retry = CPListItem(text: carTr("إعادة فتح ود كار", "Open WudCar"), detailText: error?.localizedDescription)
            retry.handler = { [weak self] _, completion in
                self?.interfaceController?.setRootTemplate(tabs, animated: false, completion: nil)
                completion()
            }
            let fallback = CPListTemplate(title: "WudCar", sections: [CPListSection(items: [retry])])
            self.interfaceController?.setRootTemplate(fallback, animated: false, completion: nil)
        }

        SubscriptionStore.shared.$state.removeDuplicates().receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.rebuildEntertainment(self.currentShortcuts)
                self.rebuildTelevision()
            }.store(in: &bag)

        ShortcutStore.shared.$shortcuts
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] shortcuts in self?.rebuildEntertainment(shortcuts) }
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
                    CarExternalDisplaySceneDelegate.returnToTemplates()
                    let template: CPTemplate
                    switch section {
                    case .home: template = self.home
                    case .entertainment: template = self.entertainment
                    case .television: template = self.television
                    case .settings: template = self.cast
                    }
                    self.tabBar?.select(template)
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

        M3UStore.shared.objectWillChange.debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.refreshFavoriteChannels() }.store(in: &bag)
        refreshFavoriteChannels()
        NotificationCenter.default.publisher(for: PlaybackManager.carPlaybackRequested)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard self?.interfaceController?.topTemplate !== CPNowPlayingTemplate.shared else { return }
                self?.showNowPlaying()
            }.store(in: &bag)
        DrivingMonitor.shared.$isMoving.receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildSettings(); self?.rebuildCast() }.store(in: &bag)
        WDLog.car("templates connected supportsVideo=\(supportsVideo)")
        startedAt = Date()
        refreshVideoSupport()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshVideoSupport()
        }
    }

    func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate) {
        // Selection never launches playback or the browser.
    }

    private func rebuildHome() {
        let library = MediaLibrary.shared
        let sections = [
            mediaSection(carTr("متابعة المشاهدة", "Continue watching"), items: library.items.filter { $0.position > 0 }),
            compactSection(carTr("قوائم التشغيل", "Playlists"), rows: library.playlists.map { list in
                let item = CPListItem(text: list.name, detailText: "\(list.itemIDs.count)", image: UIImage(systemName: "list.bullet.rectangle"))
                item.handler = { [weak self] _, done in
                    let members = library.members(list.id)
                    let rows = members.map { media -> CPListItem in
                        let row = self?.mediaItem(media) ?? CPListItem(text: media.title, detailText: nil)
                        row.handler = { _, finished in
                            PlaybackManager.shared.playQueue(members.compactMap(\.playbackItem), startingAt: media.url, presentOnPhone: false, playlistName: list.name)
                            if self?.supportsVideo != true { self?.showNowPlaying() }
                            finished()
                        }
                        return row
                    }
                    self?.showPagedRows(title: list.name, rows: rows); done()
                }
                return item
            }),
            mediaSection(carTr("الفيديوهات والملفات المحلية", "Local video and audio"), items: library.items.filter { $0.localFilename != nil }),
            mediaSection(carTr("روابط الوسائط", "Media URLs"), items: library.items.filter { $0.localFilename == nil })
        ]
        home.updateSections(bounded([sections[0], sourceSection()] + Array(sections.dropFirst())))
    }
    private func bounded(_ sections: [CPListSection]) -> [CPListSection] {
        var remaining = Self.maxItems
        return sections.prefix(CPListTemplate.maximumSectionCount).compactMap { section in
            guard remaining > 0 else { return nil }
            let items = Array(section.items.prefix(remaining)); remaining -= items.count
            return CPListSection(items: items, header: section.header, sectionIndexTitle: section.sectionIndexTitle)
        }
    }
    private func showNowPlaying() {
        guard let controller = interfaceController, controller.topTemplate !== CPNowPlayingTemplate.shared else { return }
        if controller.templates.count >= 5 {
            controller.popToRootTemplate(animated: false) { _, _ in
                controller.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            }
        } else { controller.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil) }
    }
    private func showPagedRows(title: String, rows: [CPListItem]) {
        let template = CPListTemplate(title: title, sections: [])
        populateRows(template, rows: rows, offset: 0)
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }
    private func populateRows(_ template: CPListTemplate, rows: [CPListItem], offset: Int) {
        let capacity = max(1, Self.maxItems - 1)
        var page = Array(rows.dropFirst(offset).prefix(capacity))
        for row in page { if let url = row.userInfo as? URL { loadImage(url, into: row) } }
        if offset + capacity < rows.count {
            let more = CPListItem(text: carTr("المزيد", "More"), detailText: nil)
            more.handler = { [weak self] _, done in self?.populateRows(template, rows: rows, offset: offset + capacity); done() }; page.append(more)
        }
        template.updateSections([CPListSection(items: page)])
    }
    private func compactSection(_ title: String, rows: [CPListItem]) -> CPListSection {
        guard !rows.isEmpty else { return CPListSection(items: []) }
        let item = CPListItem(text: title, detailText: "\(rows.count)", image: UIImage(systemName: "list.bullet"))
        item.handler = { [weak self] _, done in self?.showPagedRows(title: title, rows: rows); done() }
        return CPListSection(items: [item], header: title, sectionIndexTitle: nil)
    }
    private func rebuildCast() {
        let route = CPListItem(text: carTr("AirPlay", "AirPlay"), detailText: PlaybackManager.shared.isAirPlayActive ? carTr("متصل بشاشة", "Connected to a display") : carTr("اختر جهاز الاستقبال من iPhone", "Choose a receiver on iPhone"), image: UIImage(systemName: "airplay.video"))
        let mirroring = CPListItem(text: carTr("عكس الشاشة", "Screen mirroring"), detailText: ScreenRelay.shared.active ? carTr("العكس نشط", "Sharing active") : carTr("ابدأ العكس من iPhone أثناء التوقف", "Start sharing from iPhone while parked"))
        let preferences = settingItem(carTr("الإعدادات", "Settings"), detail: nil, symbol: "gearshape") { [weak self] in
            guard let self else { return }; self.rebuildSettings(); self.interfaceController?.pushTemplate(self.settings, animated: true, completion: nil)
        }
        cast.updateSections(bounded([CPListSection(items: [route, mirroring, videoStatusItem(), preferences])]))
    }
    private func sourceSection(liveOnly: Bool = false) -> CPListSection {
        let rows = SourceStore.shared.sources.filter { !$0.hidden && (!liveOnly || [.playlist, .pasted, .stream].contains($0.kind)) }.map { source -> CPListItem in
            let item = CPListItem(text: source.name, detailText: "\(source.count)", image: UIImage(systemName: "server.rack"))
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, done in self?.showSource(source); done() }; return item
        }
        return compactSection(carTr("المصادر", "Sources"), rows: Array(rows))
    }
    private func showSource(_ source: MediaSource, parent: String? = nil, title: String? = nil) {
        let template = loadingTemplate(title: title ?? source.name)
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let items = try await SourceStore.shared.browse(source, parent: parent)
                self.populateSource(template, source: source, items: items, offset: 0)
            } catch { self.fail(template, error) }
        }
    }
    private func populateSource(_ template: CPListTemplate, source: MediaSource, items: [SourceMedia], offset: Int, trail: [[SourceMedia]] = []) {
        let capacity = max(1, Self.maxItems - 1 - (trail.isEmpty ? 0 : 1))
        var rows = items.dropFirst(offset).prefix(capacity).map { media -> CPListItem in
            let row = CPListItem(text: media.title, detailText: media.group.isEmpty ? nil : media.group, image: UIImage(systemName: media.folder ? "folder" : "play.rectangle"))
            loadImage(media.artwork, into: row)
            if !media.folder { applyPlaybackConfiguration(to: row) }
            row.handler = { [weak self] _, done in
                if media.folder {
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        do {
                            let children = try await SourceStore.shared.browse(source, parent: media.id)
                            self.populateSource(template, source: source, items: children, offset: 0, trail: trail + [items])
                        } catch { self.fail(template, error) }
                    }
                }
                else {
                    SourceStore.shared.play(media, source: source, onPhone: false, queue: items)
                    if self?.supportsVideo != true { self?.showNowPlaying() }
                }
                done()
            }
            return row
        }
        if offset + capacity < items.count {
            let more = CPListItem(text: carTr("المزيد", "More"), detailText: nil)
            more.handler = { [weak self] _, done in self?.populateSource(template, source: source, items: items, offset: offset + capacity, trail: trail); done() }; rows.append(more)
        }
        if let previous = trail.last {
            let up = CPListItem(text: carTr("المجلد السابق", "Previous folder"), detailText: nil, image: UIImage(systemName: "arrow.up"))
            up.handler = { [weak self] _, done in self?.populateSource(template, source: source, items: previous, offset: 0, trail: Array(trail.dropLast())); done() }
            rows.insert(up, at: 0)
        }
        template.updateSections([CPListSection(items: rows)])
    }
    private func mediaSection(_ title: String, items: [LibraryMedia]) -> CPListSection {
        if #available(iOS 26.4, *), !items.isEmpty {
            let visible = Array(items.prefix(min(12, Int(CPMaximumNumberOfGridImages))))
            let cards = visible.map { media in
                let image = UIImage(contentsOfFile: MediaLibrary.shared.thumbnailURL(media.id).path) ?? UIImage(systemName: "play.rectangle")!
                let card = CPListImageRowItemCardElement(image: image, showsImageFullHeight: false, title: media.title, subtitle: media.isLive ? carTr("مباشر", "Live") : nil, tintColor: .darkGray)
                card.playbackConfiguration = CPPlaybackConfiguration(preferredPresentation: supportsVideo ? .video : .audio, playbackAction: .play, elapsedTime: CMTime(seconds: media.position, preferredTimescale: 600), duration: CMTime(seconds: media.duration ?? 0, preferredTimescale: 600))
                return card
            }
            let row = CPListImageRowItem(text: title, cardElements: cards, allowsMultipleLines: true)
            row.listImageRowHandler = { [weak self] _, index, done in
                guard visible.indices.contains(index) else { done(); return }
                PlaybackManager.shared.playQueue(items.compactMap(\.playbackItem), startingAt: visible[index].url, presentOnPhone: false)
                if self?.supportsVideo != true { self?.showNowPlaying() }
                done()
            }
            var rows: [CPListTemplateItem] = [row]
            if items.count > visible.count {
                let more = CPListItem(text: carTr("عرض الكل", "Show all"), detailText: "\(items.count)")
                more.handler = { [weak self] _, done in
                    guard let self else { done(); return }
                    self.showPagedRows(title: title, rows: items.map(self.mediaItem)); done()
                }; rows.append(more)
            }
            return CPListSection(items: rows)
        }
        return CPListSection(items: items.map(mediaItem), header: title, sectionIndexTitle: nil)
    }

    private func mediaItem(_ media: LibraryMedia) -> CPListItem {
        let image = UIImage(contentsOfFile: MediaLibrary.shared.thumbnailURL(media.id).path) ?? UIImage(systemName: "play.rectangle")
        let item = CPListItem(text: media.title, detailText: media.isLive ? carTr("مباشر", "Live") : nil, image: image)
        if #available(iOS 26.4, *) {
            item.playbackConfiguration = CPPlaybackConfiguration(preferredPresentation: supportsVideo ? .video : .audio, playbackAction: .play, elapsedTime: CMTime(seconds: media.position, preferredTimescale: 600), duration: CMTime(seconds: media.duration ?? 0, preferredTimescale: 600))
        }
        item.handler = { [weak self] _, done in
            let items = MediaLibrary.shared.items.compactMap(\.playbackItem)
            PlaybackManager.shared.playQueue(items, startingAt: media.url, presentOnPhone: false)
            if self?.supportsVideo != true { self?.showNowPlaying() }; done()
        }
        return item
    }
    func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        let items = PlaybackManager.shared.queue.map { media in
            let item = CPListItem(text: media.title, detailText: media.subtitle)
            item.handler = { _, done in PlaybackManager.shared.playQueue(PlaybackManager.shared.queue, startingAt: media.url, presentOnPhone: false); done() }
            return item
        }
        interfaceController?.pushTemplate(CPListTemplate(title: carTr("التالي", "Up next"), sections: bounded([CPListSection(items: items)])), animated: true, completion: nil)
    }

    private func rebuildSettings() {
        let language = settingItem(
            carTr("اللغة", "Language"),
            detail: WDSettings.carLanguage == "ar" ? "العربية" : "English",
            symbol: "globe"
        ) { [weak self] in
            WDSettings.carLanguage = WDSettings.carLanguage == "ar" ? "en" : "ar"
            guard let self else { return }
            self.home.tabTitle = carTr("المكتبة", "Library")
            self.entertainment.tabTitle = carTr("المفضلة", "Favorites")
            self.television.tabTitle = carTr("البث", "TV")
            self.settings.tabTitle = carTr("الإعدادات", "Settings")
            self.tabBar?.updateTemplates([self.home, self.television, self.entertainment, self.settings])
            self.rebuildHome()
            self.rebuildSettings()
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
        let safety = CPListItem(text: carTr("للركاب فقط — لا تشاهد أثناء القيادة", "Passengers only — do not watch while driving"), detailText: nil)
        let lockDetail = DrivingMonitor.shared.shouldBlockVideo ? carTr("الفيديو محجوب الآن — صوت فقط", "Video blocked now — audio only") : carTr("مفروض دائماً على شاشة السيارة", "Always enforced on the car display")
        let lock = CPListItem(text: carTr("قفل الفيديو أثناء الحركة", "Video lock while moving"), detailText: lockDetail)
        let about = CPListItem(text: "WudCar Media Player 3.0.1", detailText: carTr("إدارة الوسائط والإعدادات من iPhone", "Manage media and preferences on iPhone"))
        settings.updateSections([CPListSection(items: [language, display, zoomOut, zoom, zoomIn, reset, safety, lock, about])])
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
        let items = shortcuts.map { shortcut -> CPListItem in
            let item = CPListItem(text: shortcut.name, detailText: shortcut.url.host)
            item.userInfo = Favicon.url(for: shortcut.url)
            item.handler = { [weak self] _, completion in
                self?.openShortcut(shortcut.url)
                completion()
            }
            return item
        }
        let browser = carScreenItem()
        browser.handler = { [weak self] _, done in self?.confirmBrowserLaunch(); done() }
        let media = MediaLibrary.shared.items.filter { $0.favorite && !$0.isLive }.map(mediaItem)
        let channels = favoriteChannelRows + MediaLibrary.shared.items.filter { $0.favorite && $0.isLive }.map(mediaItem)
        let websiteBudget = max(0, Self.maxItems - (channels.isEmpty ? 0 : 1) - (media.isEmpty ? 0 : 1) - 3)
        var websites = Array(items.prefix(websiteBudget))
        if websites.count < items.count {
            let more = CPListItem(text: carTr("كل اختصارات المواقع", "All website shortcuts"), detailText: "\(shortcuts.count)")
            more.handler = { [weak self] _, done in self?.showPagedRows(title: carTr("تشغيل من الويب", "Play from web"), rows: Array(items)); done() }; websites.append(more)
        }
        for row in websites { if let url = row.userInfo as? URL { loadImage(url, into: row) } }
        entertainment.updateSections(bounded([
            compactSection(carTr("القنوات المفضلة", "Favorite channels"), rows: channels),
            compactSection(carTr("الوسائط المفضلة", "Favorite media"), rows: media),
            CPListSection(items: [browser] + websites + [videoStatusItem()], header: carTr("تشغيل من الويب", "Play from web"), sectionIndexTitle: nil)
        ]))
    }

    private func refreshFavoriteChannels() {
        let playlists = M3UStore.shared.playlists
        Task { [weak self] in
            var rows: [CPListItem] = []
            for playlist in playlists {
                guard let entries = try? await M3UStore.shared.entries(for: playlist) else { continue }
                guard let self else { return }
                let favorites = M3UStore.shared.favorites(in: playlist, entries: entries)
                let section = self.m3uSection(playlist.name, entries: favorites, playlist: playlist)
                rows += section.items.compactMap { $0 as? CPListItem }
            }
            self?.favoriteChannelRows = rows
            self?.rebuildEntertainment(self?.currentShortcuts ?? [])
        }
    }

    private func confirmBrowserLaunch() {
        let permission = DrivingMonitor.shared.authorization
        if (permission == .denied || permission == .restricted), !supportsVideo {
            showAlert([carTr("فيديو السيارة محجوب لأن إذن الموقع غير متاح والسيارة لا تعلن دعم الفيديو. فعّل إذن الموقع أثناء الاستخدام من إعدادات iPhone لرصد الحركة بأمان.", "Car video is blocked because location permission is unavailable and the car does not report video support. Enable When In Use location in iPhone Settings for safe motion detection.")])
            return
        }
        guard !browserWarningAccepted else { startCarScreen(); return }
        let proceed = CPAlertAction(title: carTr("متابعة", "Continue"), style: .default) { [weak self] _ in
            self?.interfaceController?.dismissTemplate(animated: true) { _, _ in
                self?.browserWarningAccepted = true
                self?.startCarScreen()
            }
        }
        let cancel = CPAlertAction(title: carTr("إلغاء", "Cancel"), style: .cancel) { [weak self] _ in self?.interfaceController?.dismissTemplate(animated: true, completion: nil) }
        interfaceController?.presentTemplate(CPAlertTemplate(titleVariants: [carTr("المتصفح لتشغيل فيديو الويب للركاب فقط وأثناء التوقف", "Web video browser for passengers only while parked")], actions: [proceed, cancel]), animated: true, completion: nil)
    }

    // MARK: - التحديث 3: المتصفح على شاشة السيارة

    /// العنصر الأول: يفتح متصفح ود كار على شاشة السيارة (كشاشة خارجية) مثل CarTV
    private func carScreenItem() -> CPListItem {
        let active = AppState.shared.carScreenActive
        let item = CPListItem(
            text: carTr("المتصفح على شاشة السيارة", "Browser on car screen"),
            detailText: active ? carTr("يعمل الآن", "Running now") : carTr("اضغط للتشغيل", "Tap to start")
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
        guard SubscriptionStore.shared.hasAccess else {
            showAlert([carTr("فعّل اشتراك ود كار أو استعده من تطبيق iPhone أثناء التوقف.", "Activate or restore WudCar Premium on iPhone while parked.")]); return
        }
        WDLog.car("templates: browser item tapped active=\(AppState.shared.carScreenActive) supportsVideo=\(supportsVideo)")
        if AppState.shared.carScreenActive {
            showAlert([
                carTr("المتصفح يعمل على شاشة السيارة. افتح المواقع من الهاتف أو من الاختصارات هنا.",
                   "The browser is on the car screen. Open sites from iPhone or from shortcuts here."),
                carTr("المتصفح يعمل", "Browser running")
            ])
            return
        }
        // المسار 1: فتح وضع الفيديو من CarPlay مباشرة
        CarScreenLauncher.shared.launch()
        // المسار 2: على الهاتف تظهر نافذة فيها زر AirPlay لاختيار شاشة السيارة
        AppState.shared.showCarScreenHelp = true
        if !supportsVideo {
            showAlert([
                carTr("إذا لم يظهر المتصفح، اختر شاشة السيارة من زر AirPlay في ود كار على iPhone.",
                   "If the browser does not appear, choose the car display from AirPlay in WudCar on iPhone."),
                carTr("اختر شاشة السيارة من AirPlay", "Choose the car display in AirPlay")
            ])
        }
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
        if !accounts.isEmpty { sections.append(compactSection("Xtream Codes", rows: accounts)) }
        if !playlists.isEmpty { sections.append(compactSection("M3U", rows: playlists)) }
        sections.append(sourceSection(liveOnly: true))
        television.updateSections(bounded(sections))
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
                    var rows: [CPListItem] = []
                    func addGroup(_ title: String, values: [M3UEntry]) {
                        let row = CPListItem(text: title, detailText: "\(values.count)", image: UIImage(systemName: "folder"))
                        row.handler = { [weak self] _, done in
                            guard let self else { done(); return }
                            let items = self.m3uSection(title, entries: values, playlist: playlist).items.compactMap { $0 as? CPListItem }
                            self.showPagedRows(title: title, rows: items); done()
                        }; rows.append(row)
                    }
                    if !favorites.isEmpty { addGroup(carTr("المفضلة", "Favorites"), values: favorites) }
                    for key in groups.keys.sorted() { if let values = groups[key] { addGroup(key, values: values) } }
                    template.emptyViewTitleVariants = [carTr("لا يوجد محتوى", "No content")]
                    self.populateRows(template, rows: rows, offset: 0)
                }
            } catch {
                await MainActor.run { self?.fail(template, error) }
            }
        }
    }

    private func m3uSection(_ title: String, entries: [M3UEntry], playlist: M3UPlaylist) -> CPListSection {
        let items = entries.map { entry -> CPListItem in
            let item = CPListItem(text: entry.title, detailText: nil)
            item.userInfo = entry.logo
            applyPlaybackConfiguration(to: item)
            item.handler = { [weak self] _, completion in
                guard let self else { completion(); return }
                PlaybackManager.shared.play(.init(title: entry.title,
                                                  subtitle: playlist.name,
                                                  url: entry.url,
                                                  isLive: true,
                                                  artworkURL: entry.logo),
                                            presentOnPhone: false)
                if !self.supportsVideo {
                    self.showNowPlaying()
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
                        let items = categories.map { category -> CPListItem in
                            let item = CPListItem(text: category.name, detailText: nil)
                            item.accessoryType = .disclosureIndicator
                            item.handler = { [weak self] _, completion in
                                self?.showStreams(account: account, kind: kind, category: category)
                                completion()
                            }
                            return item
                        }
                        sections.append(self.compactSection(kind.title, rows: Array(items)))
                    }
                    template.emptyViewTitleVariants = [carTr("لا يوجد محتوى", "No content")]
                    template.updateSections(bounded(sections))
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
                    let items = streams.map { stream -> CPListItem in
                        let item = CPListItem(text: stream.name, detailText: kind == .live ? carTr("مباشر", "Live") : nil)
                        item.userInfo = stream.icon
                        self.applyPlaybackConfiguration(to: item)
                        item.handler = { [weak self] _, completion in
                            self?.play(stream, account: account, client: client)
                            completion()
                        }
                        return item
                    }
                    template.emptyViewTitleVariants = [carTr("لا يوجد محتوى", "No content")]
                    self.populateRows(template, rows: Array(items), offset: 0)
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
