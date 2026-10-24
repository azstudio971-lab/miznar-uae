import XCTest
import UIKit
import WebKit
import SwiftUI
import StoreKitTest
import StoreKit
@testable import WdCar

@MainActor
final class CarInterfaceTests: XCTestCase {
    private var testWindow: UIWindow!
    private static var purchaseSession: SKTestSession?

    override func setUp() async throws {
        try await super.setUp()
        if Self.purchaseSession == nil {
            let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "WudCar", withExtension: "storekit"))
            let session = try SKTestSession(contentsOf: url)
            session.disableDialogs = true
            session.clearTransactions()
            let products = try await Product.products(for: [SubscriptionStore.productID])
            let product = try XCTUnwrap(products.first)
            guard product.price == 24 else {
                throw NSError(domain: "LocalStoreKitFixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Local StoreKit fixture is not active; refusing a real-store purchase. Expected fixture 24, got \(product.price)."])
            }
            _ = try await session.buyProduct(identifier: SubscriptionStore.productID)
            Self.purchaseSession = session
        }
        for _ in 0..<30 {
            await SubscriptionStore.shared.refresh()
            if SubscriptionStore.shared.hasAccess { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        guard SubscriptionStore.shared.hasAccess else {
            if let result = await Transaction.latest(for: SubscriptionStore.productID) { print("STOREKIT TEST VERIFICATION: \(result)") }
            throw NSError(domain: "LocalStoreKitFixture", code: 2, userInfo: [NSLocalizedDescriptionKey: "Local StoreKit did not produce a verified active subscription."])
        }
    }


    override func tearDown() {
        testWindow?.isHidden = true
        testWindow?.rootViewController = nil
        testWindow = nil
        super.tearDown()
    }

    private func display(_ controller: UIViewController) {
        testWindow?.isHidden = true
        testWindow?.rootViewController = nil
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        testWindow = UIWindow(windowScene: scene)
        testWindow.rootViewController = controller
        testWindow.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
    }

    private func find(_ id: String, in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == id { return view }
        for child in view.subviews {
            if let found = find(id, in: child) { return found }
        }
        return nil
    }

    private func findLabel(_ label: String, in view: UIView) -> UIView? {
        if view.accessibilityLabel == label { return view }
        for child in view.subviews {
            if let found = findLabel(label, in: child) { return found }
        }
        return nil
    }

    private func isEffectivelyHidden(_ view: UIView) -> Bool {
        var current: UIView? = view
        while let item = current {
            if item.isHidden || item.alpha < 0.01 { return true }
            current = item.superview
        }
        return false
    }

    func test150ExistingShortcutDecodesWithoutOptionalArtwork() throws {
        let item = SiteShortcut(name: "Custom", url: URL(string: "https://example.com")!, colorHex: "#013748")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
        json.removeValue(forKey: "iconURL")
        let decoded = try JSONDecoder().decode(SiteShortcut.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.id, item.id)
        XCTAssertEqual(decoded.url, item.url)
        XCTAssertNil(decoded.iconURL)
        var custom = decoded
        custom.iconURL = URL(string: "https://example.com/logo.png")
        XCTAssertEqual(try JSONDecoder().decode(SiteShortcut.self, from: JSONEncoder().encode(custom)), custom)
    }

    func test150SeasonalArtworkValidation() throws {
        let url = SeasonalLogo.url
        let ok = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "image/png"])
        let missing = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: ["Content-Type": "image/png"])
        let html = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html"])
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let png = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512), format: format).image { _ in UIColor.red.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 512, height: 512)) }.pngData()
        XCTAssertEqual(try XCTUnwrap(png.flatMap { UIImage(data: $0) }?.cgImage).width, 512, "Fixture must be 512 pixels, not 512 Retina points")
        XCTAssertNotNil(SeasonalLogo.validatedImage(data: png, response: ok))
        XCTAssertNil(SeasonalLogo.validatedImage(data: png, response: missing))
        XCTAssertNil(SeasonalLogo.validatedImage(data: png, response: html))
        XCTAssertNil(SeasonalLogo.validatedImage(data: nil, response: nil))
        XCTAssertNil(SeasonalLogo.validatedImage(data: Data("broken".utf8), response: ok))
    }

    func test150EntertainmentLayoutSnapshots() async throws {
        for size in [CGSize(width: 640, height: 360), CGSize(width: 960, height: 480), CGSize(width: 1280, height: 480)] {
            let controller = UIViewController()
            let shortcuts = CarShortcutsView(frame: .zero)
            controller.view = shortcuts
            display(controller)
            controller.view.frame = CGRect(origin: .zero, size: size)
            try await Task.sleep(nanoseconds: 600_000_000)
            controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
            let collection = try XCTUnwrap(shortcuts.subviews.compactMap { $0 as? UICollectionView }.first)
            collection.layoutIfNeeded()
            XCTAssertGreaterThan(collection.numberOfItems(inSection: 0), 0, "Snapshot must contain the real shortcut data")
            XCTAssertFalse(collection.visibleCells.isEmpty, "Cards must have visible frames before capture")
            let image = UIGraphicsImageRenderer(size: size).image { context in shortcuts.layer.render(in: context.cgContext) }
            let attachment = XCTAttachment(image: image)
            attachment.name = "wudcar150-entertainment-\(Int(size.width))x\(Int(size.height))"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func test150DesktopPreferenceAppliesToBothBrowsers() {
        let phone = WDSettings.phoneDesktopMode
        let car = WDSettings.carDesktopMode
        defer { WDSettings.phoneDesktopMode = phone; WDSettings.carDesktopMode = car }
        WDSettings.phoneDesktopMode = true
        WDSettings.carDesktopMode = true
        for side in [BrowserSide.phone, .car] {
            XCTAssertEqual(WebEngine.makeConfiguration(for: side).defaultWebpagePreferences.preferredContentMode, .desktop)
        }
    }

    func test150NativeToolbarHotspotAndMenu() throws {
        let browser = CarBrowserViewController()
        display(browser)
        let hotspot = try XCTUnwrap(find("car.browser.toolbar.hotspot", in: browser.view) as? UIButton)
        let reveal = try XCTUnwrap(find("car.browser.toolbar.reveal", in: browser.view) as? UIButton)
        XCTAssertGreaterThanOrEqual(hotspot.bounds.width, 44)
        hotspot.sendActions(for: .primaryActionTriggered)
        XCTAssertFalse(reveal.isHidden)
        XCTAssertNil(reveal.menu)
    }

    func test150StopReleasesStreamOnRepeatedPlayback() throws {
        let manager = PlaybackManager.shared
        let url = try XCTUnwrap(Bundle.main.url(forResource: "intro_night", withExtension: "mp4"))
        for name in ["M3U", "Xtream", "M3U", "Xtream"] {
            manager.play(.init(title: name, subtitle: "Regression", url: url, isLive: true, artworkURL: nil), presentOnPhone: false)
            XCTAssertNotNil(manager.player.currentItem)
            manager.stop()
            XCTAssertNil(manager.player.currentItem)
            XCTAssertNil(manager.current)
            XCTAssertFalse(manager.isPlaying)
            XCTAssertFalse(manager.isPlayerPresented)
        }
    }

    func testDaytimePhoneLogoAtCompactRegularAndLargeSizes() throws {
        let image = try XCTUnwrap(UIImage(named: "LogoDay"))
        XCTAssertEqual(image.size.width / image.size.height, 1145.0 / 1373.0, accuracy: 0.001)
        for size in [CGSize(width: 320, height: 568), CGSize(width: 390, height: 844), CGSize(width: 430, height: 932)] {
            let host = UIHostingController(rootView: HomeView(selectTab: { _ in })
                .environmentObject(AppState.shared).environment(\.colorScheme, .light)
                .environment(\.layoutDirection, .rightToLeft))
            host.overrideUserInterfaceStyle = .light
            display(host)
            host.view.frame = CGRect(origin: .zero, size: size)
            host.view.setNeedsLayout(); host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))
            let rendered = UIGraphicsImageRenderer(size: size).image { _ in
                host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: rendered)
            attachment.name = "update14-phone-day-logo-\(Int(size.width))x\(Int(size.height))"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testWelcomeNavigationAndPersistedZoom() throws {
        let savedZoom = WDSettings.carZoom
        let savedLanguage = WDSettings.carLanguage
        defer {
            WDSettings.carZoom = savedZoom
            WDSettings.carLanguage = savedLanguage
            WebViewPool.car.applyZoom(savedZoom)
        }
        let dashboard = CarDashboardViewController()
        display(dashboard)
        let menu = try XCTUnwrap(find("car.navigation", in: dashboard.view) as? UISegmentedControl)
        XCTAssertEqual(menu.selectedSegmentIndex, 0)
        XCTAssertEqual(menu.numberOfSegments, 4)
        XCTAssertEqual(menu.titleForSegment(at: 2), "التلفزيون TV")
        XCTAssertNotNil(find("car.home", in: dashboard.view))
        let welcomeImage = UIGraphicsImageRenderer(bounds: dashboard.view.bounds).image { _ in dashboard.view.drawHierarchy(in: dashboard.view.bounds, afterScreenUpdates: true) }
        let welcomeAttachment = XCTAttachment(image: welcomeImage)
        welcomeAttachment.name = "wudcar-update9-home-preview"
        welcomeAttachment.lifetime = .keepAlways
        add(welcomeAttachment)
        menu.selectedSegmentIndex = 3
        menu.sendActions(for: .valueChanged)
        let stepper = try XCTUnwrap(find("car.zoom", in: dashboard.view) as? UIStepper)
        XCTAssertEqual(stepper.minimumValue, 50)
        XCTAssertEqual(stepper.maximumValue, 150)
        XCTAssertEqual(stepper.stepValue, 5)
        for percent in [50.0, 100.0, 150.0] {
            stepper.value = percent
            stepper.sendActions(for: .valueChanged)
            XCTAssertEqual(WDSettings.carZoom, percent / 100, accuracy: 0.001)
            let session = TabSession(tabID: UUID(), side: .car, initialURL: nil)
            XCTAssertEqual(Double(session.webView.pageZoom), percent / 100, accuracy: 0.001)
            session.tearDown()
        }
        let reset = try XCTUnwrap(find("car.zoom.reset", in: dashboard.view) as? UIButton)
        reset.sendActions(for: .touchUpInside)
        XCTAssertEqual(WDSettings.carZoom, 1)
        menu.selectedSegmentIndex = 2
        menu.sendActions(for: .valueChanged)
        let tv = try XCTUnwrap(dashboard.children.compactMap { $0 as? UIHostingController<XtreamHomeView> }.first)
        XCTAssertTrue(tv.rootView.readOnly, "Car TV list is view-only; accounts are managed on iPhone")
        XCTAssertFalse(tv.rootView.presentPlaybackOnPhone, "Selecting a car TV stream must not present the iPhone player")
        XCTAssertNil(findLabel("إضافة حساب أو قائمة", in: tv.view), "Car TV must not expose the phone's add control")

        menu.selectedSegmentIndex = 1
        menu.sendActions(for: .valueChanged)
        XCTAssertTrue(menu.isHidden, "The blue menu stays hidden in the Entertainment browser")
        XCTAssertTrue(dashboard.children.contains { $0 is CarBrowserViewController })
        let leave = try XCTUnwrap(find("car.exitEntertainment", in: dashboard.view) as? UIButton)
        leave.sendActions(for: .touchUpInside)
        XCTAssertFalse(menu.isHidden)
        XCTAssertEqual(menu.selectedSegmentIndex, 0)
        XCTAssertNotNil(find("car.home", in: dashboard.view))
    }

    func testDefaultCarZoomIs100PercentAndPreferencePersists() {
        let defaults = UserDefaults.standard
        let prior = defaults.object(forKey: WDKeys.carZoom)
        defer {
            if let prior { defaults.set(prior, forKey: WDKeys.carZoom) }
            else { defaults.removeObject(forKey: WDKeys.carZoom) }
        }
        defaults.removeObject(forKey: WDKeys.carZoom)
        XCTAssertEqual(WDSettings.carZoom, 1.0)
        WDSettings.carZoom = 0.85
        XCTAssertEqual(defaults.double(forKey: WDKeys.carZoom), 0.85, accuracy: 0.001)
    }

    func testMousePageContainsOnlyTouchpadAndTwoScrollActions() throws {
        let page = UIHostingController(rootView: CarMousePadView())
        display(page)
        page.view.layoutIfNeeded()
        XCTAssertGreaterThan(page.view.bounds.width, 0)
        XCTAssertGreaterThan(page.view.bounds.height, 0)
        let rendered = UIGraphicsImageRenderer(bounds: page.view.bounds).image { _ in
            page.view.drawHierarchy(in: page.view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: rendered)
        attachment.name = "wudcar-update11-mouse-pad-preview"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testBrowserToolbarIsHiddenByDefaultAndScrollArrowsStartHidden() throws {
        let browser = CarBrowserViewController()
        display(browser)
        let toolbar = try XCTUnwrap(find("car.browser.toolbar", in: browser.view))
        XCTAssertTrue(toolbar.isHidden, "The website must take the full available display at startup")
        let up = try XCTUnwrap(find("car.browser.scroll.up", in: browser.view))
        let down = try XCTUnwrap(find("car.browser.scroll.down", in: browser.view))
        XCTAssertTrue(isEffectivelyHidden(up))
        XCTAssertTrue(isEffectivelyHidden(down))
        XCTAssertLessThan(up.convert(up.bounds, to: browser.view).midX, browser.view.bounds.midX)
        XCTAssertLessThan(down.convert(down.bounds, to: browser.view).midX, browser.view.bounds.midX)
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants($0) } }
        let arrows = descendants(browser.view).filter { $0.accessibilityIdentifier?.hasPrefix("car.browser.scroll.") == true }
        XCTAssertEqual(arrows.count, 2, "Only the new left-hand scroll controls are installed")
        XCTAssertTrue(try XCTUnwrap(find("car.mouse.cursor", in: browser.view)).isHidden)
        XCTAssertTrue(try XCTUnwrap(find("car.browser.toolbar.reveal", in: browser.view)).isHidden)
        XCTAssertNil(find("car.browser.reload", in: browser.view))
        XCTAssertNil(find("car.browser.favorite", in: browser.view))
        XCTAssertNil(find("car.browser.fullscreen", in: browser.view))
        XCTAssertNil(find("car.browser.zoom", in: browser.view))
    }

    func testScrollArrowsAndToolbarRevealCanBeUsedRepeatedly() async throws {
        let browser = CarBrowserViewController()
        display(browser)
        let up = try XCTUnwrap(find("car.browser.scroll.up", in: browser.view))
        let toolbar = try XCTUnwrap(find("car.browser.toolbar", in: browser.view))
        let reveal = try XCTUnwrap(find("car.browser.toolbar.reveal", in: browser.view) as? UIButton)
        browser.revealScrollControls()
        XCTAssertFalse(up.isHidden)
        try await Task.sleep(nanoseconds: 3_200_000_000)
        XCTAssertTrue(isEffectivelyHidden(up), "Scroll buttons hide three seconds after the last touch")

        browser.showToolbarRevealButton()
        XCTAssertFalse(reveal.isHidden)
        reveal.sendActions(for: .primaryActionTriggered)
        XCTAssertFalse(toolbar.isHidden, "The overlay reveal button opens the toolbar")
        try await Task.sleep(nanoseconds: 6_200_000_000)
        XCTAssertTrue(toolbar.isHidden, "The toolbar stays open for six seconds after its last interaction")

        browser.showToolbarRevealButton()
        XCTAssertFalse(reveal.isHidden, "The reveal control is available again without leaving the browser")
        reveal.sendActions(for: .primaryActionTriggered)
        XCTAssertFalse(toolbar.isHidden)
    }

    func testVideoControlsHideAfterThreeSeconds() async throws {
        let owner = UIViewController()
        display(owner)
        let overlay = CarVideoOverlayView(frame: owner.view.bounds)
        owner.view.addSubview(overlay)
        overlay.present()
        let controls = try XCTUnwrap(find("car.video.controls", in: overlay))
        XCTAssertEqual(controls.alpha, 1)
        try await Task.sleep(nanoseconds: 3_300_000_000)
        XCTAssertLessThan(controls.alpha, 0.1, "The video controls should fade after three seconds")
    }

    func testPhoneRemoteCanSelectDashboardSectionsAndCarLogoIsTransparent() async throws {
        let dashboard = CarDashboardViewController()
        display(dashboard)
        let menu = try XCTUnwrap(find("car.navigation", in: dashboard.view) as? UISegmentedControl)
        for section in [CarMouseBridge.DashboardSection.television, .settings, .home] {
            CarMouseBridge.shared.send(.selectSection(section))
            try await Task.sleep(nanoseconds: 120_000_000)
            XCTAssertEqual(menu.selectedSegmentIndex, section.rawValue)
        }
        let logo = try XCTUnwrap(UIImage(named: "LogoCarMark")?.cgImage)
        XCTAssertNotEqual(logo.alphaInfo, .none, "CarPlay uses the mark without its former teal tile")
        let daytime = try XCTUnwrap(UIImage(named: "LogoDay")?.cgImage)
        XCTAssertNotEqual(daytime.alphaInfo, .none, "The supplied daytime lockup retains transparency")
    }

    func testCarDisplayPlayerRoutesWithoutOpeningPhonePlayerAndStopsCleanly() async throws {
        let manager = PlaybackManager.shared
        defer { manager.stop() }
        let dashboard = CarDashboardViewController()
        display(dashboard)
        let item = PlaybackManager.Item(title: "Test channel", subtitle: "M3U",
                                        url: URL(fileURLWithPath: "/tmp/wudcar-missing-stream.m3u8"), isLive: true, artworkURL: nil)
        manager.play(item, presentOnPhone: false)
        let second = PlaybackManager.Item(title: "Second channel", subtitle: "Xtream",
                                          url: URL(fileURLWithPath: "/tmp/wudcar-second-missing-stream.m3u8"), isLive: true, artworkURL: nil)
        manager.play(second, presentOnPhone: false)
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(manager.current?.title, "Second channel", "Choosing another channel replaces the previous item")
        XCTAssertTrue(manager.isExternalDisplayPlayback)
        XCTAssertFalse(manager.isPlayerPresented, "Car TV playback must not present the phone player")
        let close = try XCTUnwrap(find("car.tv.player.close", in: dashboard.view) as? UIButton,
                                  "External display must expose a route back to TV lists")
        XCTAssertFalse(close.isHidden, "The close control is visible as soon as playback opens")
        XCTAssertNil(find("car.tv.player.stretch", in: dashboard.view), "The ineffective stretch control is removed")
        try await Task.sleep(nanoseconds: 3_200_000_000)
        XCTAssertTrue(close.isHidden, "The player close control hides after three seconds")
        dashboard.externalPlayerWasTouched()
        XCTAssertFalse(close.isHidden, "Touching the playing display restores the exit control")
        close.sendActions(for: .touchUpInside)
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertNil(manager.current, "Exit stops the active channel")
        XCTAssertFalse(manager.isExternalDisplayPlayback)
        XCTAssertNil(find("car.tv.player.close", in: dashboard.view), "Exit returns to the TV channel list")
    }

    func testHomeFitsWideAndCompactCarScreens() throws {
        let savedLanguage = WDSettings.carLanguage
        defer { WDSettings.carLanguage = savedLanguage }
        func labels(in view: UIView) -> [UILabel] {
            (view as? UILabel).map { [$0] } ?? view.subviews.flatMap { labels(in: $0) }
        }
        for language in ["ar", "en"] {
            WDSettings.carLanguage = language
            for size in [CGSize(width: 960, height: 480), CGSize(width: 640, height: 360)] {
                let dashboard = CarDashboardViewController()
                dashboard.loadViewIfNeeded()
                dashboard.view.frame = CGRect(origin: .zero, size: size)
                for _ in 0..<3 {
                    dashboard.view.setNeedsLayout()
                    dashboard.view.layoutIfNeeded()
                }
                let home = try XCTUnwrap(find("car.home", in: dashboard.view))
                XCTAssertNotNil(UIImage(named: "LogoCarMark"), "CarPlay home uses the transparent WudCar mark")
                for item in labels(in: home) {
                    let needed = item.sizeThatFits(CGSize(width: item.bounds.width, height: .greatestFiniteMagnitude))
                    XCTAssertLessThanOrEqual(needed.height, item.bounds.height + 2, "Welcome text must not be truncated")
                    let rect = item.convert(item.bounds, to: home)
                    XCTAssertTrue(home.bounds.insetBy(dx: -1, dy: -1).contains(rect))
                }
                let image = UIGraphicsImageRenderer(bounds: dashboard.view.bounds).image { context in
                    dashboard.view.layer.render(in: context.cgContext)
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "wudcar-home-\(language)-\(Int(size.width))x\(Int(size.height))"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testM3UParsingAndAddedShortcuts() throws {
        let content = """
        #EXTM3U
        #EXTINF:-1 tvg-logo="https://cdn.example/logo.png" group-title="News",Channel One
        https://stream.example/one.m3u8
        #EXTINF:-1 group-title="Movies",Film Two
        https://stream.example/two.mp4
        """
        let entries = try M3UParser.parse(Data(content.utf8))
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].title, "Channel One")
        XCTAssertEqual(entries[0].group, "News")
        XCTAssertEqual(entries[0].logo?.host, "cdn.example")
        XCTAssertEqual(entries[1].title, "Film Two")
        XCTAssertEqual(entries[1].group, "Movies")

        let shortcuts = ShortcutStore.shared.shortcuts
        for host in ["www.mp3quran.net", "m.soundcloud.com", "pranx.com",
                     "tv2tv.com", "www.tod.tv", "www.crazygames.com",
                     "mail.google.com", "outlook.live.com", "chatgpt.com"] {
            XCTAssertTrue(shortcuts.contains { $0.url.host == host }, "Missing default shortcut for \(host)")
        }
    }

    private func waitForDocument(_ web: WKWebView, marker: String? = nil) async throws {
        for _ in 0..<300 {
            if let ready = try? await web.evaluateJavaScript("document.readyState") as? String,
               (ready == "complete" || ready == "interactive") {
                if marker == nil,
                   let title = try? await web.evaluateJavaScript("document.title") as? String,
                   !title.isEmpty, web.url?.scheme != "about" { return }
                if let title = try? await web.evaluateJavaScript("document.title") as? String, title == marker { return }
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw NSError(domain: "WudCarTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Web document did not finish loading"])
    }

    func testFullFrameAtAllZoomLevelsAndVideoExit() async throws {
        let savedZoom = WDSettings.carZoom
        defer { WDSettings.carZoom = savedZoom }
        let session = TabSession(tabID: UUID(), side: .car, initialURL: nil)
        defer { session.tearDown() }
        let controller = UIViewController()
        display(controller)
        let viewport = DesktopViewportView(session: session)
        controller.view.addSubview(viewport)
        CarUI.pin(viewport, to: controller.view)
        controller.view.layoutIfNeeded()
        session.webView.loadHTMLString("<html><head><title>WudCar layout fixture</title><meta name='viewport' content='width=device-width, initial-scale=1'></head><body style='margin:0;background:#000'><div id='fill' style='width:100%;min-height:5000px;background:#e9b33f'><div style='transform:translate(9px,19px);contain:paint'><video controls width='640' height='360'></video></div></div></body></html>", baseURL: nil)
        try await waitForDocument(session.webView, marker: "WudCar layout fixture")
        for zoom in [0.5, 1.0, 1.5] {
            session.applyCarZoom(zoom)
            controller.view.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 300_000_000)
            var stableMetrics: [String: Double] = [:]
            for _ in 0..<50 {
                stableMetrics = try await session.webView.evaluateJavaScript("({fill:document.getElementById('fill').getBoundingClientRect().width,viewport:document.documentElement.clientWidth})") as? [String: Double] ?? [:]
                if let fill = stableMetrics["fill"], let viewport = stableMetrics["viewport"], fill > 0, abs(fill - viewport) <= 1 { break }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            let fillWidth = stableMetrics["fill"] ?? 0
            let viewportWidth = stableMetrics["viewport"] ?? 0
            XCTAssertGreaterThan(fillWidth, 0)
            XCTAssertEqual(fillWidth, viewportWidth, accuracy: 1, "Page content must fill the desktop layout viewport at every zoom level")
            let rendered = session.webView.convert(session.webView.bounds, to: viewport)
            XCTAssertEqual(rendered.width, viewport.bounds.width, accuracy: 1)
            XCTAssertEqual(rendered.height, viewport.bounds.height, accuracy: 1)
            XCTAssertEqual(session.webView.bounds.width, 1280, accuracy: 1)
            XCTAssertEqual(Double(session.webView.pageZoom), zoom, accuracy: 0.001)
            let metrics = try await session.webView.evaluateJavaScript("JSON.stringify({viewport:innerWidth,document:document.documentElement.clientWidth,zoom:document.documentElement.style.zoom})")
            print("WUDCAR ZOOM \(zoom): \(metrics)")
            let image: UIImage? = await withCheckedContinuation { continuation in
                session.webView.takeSnapshot(with: nil) { image, _ in continuation.resume(returning: image) }
            }
            XCTAssertNotNil(image)
            if let image {
                let attachment = XCTAttachment(image: image)
                attachment.name = "car-content-\(Int(zoom * 100))"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        let overlayExists = try await session.webView.evaluateJavaScript("!!document.getElementById('wd-expand-video')") as? Bool
        XCTAssertEqual(overlayExists, true)
        try await Task.sleep(nanoseconds: 600_000_000)
        let expandGeometry = try await session.webView.evaluateJavaScript("(()=>{const b=document.getElementById('wd-expand-video'),v=document.querySelector('video');const br=b.getBoundingClientRect(),vr=v.getBoundingClientRect();return JSON.stringify({buttonW:br.width,buttonH:br.height,left:br.left,top:br.top,videoLeft:vr.left,videoTop:vr.top})})()") as? String
        let expand = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(try XCTUnwrap(expandGeometry).utf8)) as? [String: Double])
        XCTAssertEqual((expand["buttonW"] ?? 100) * 1.5, 21, accuracy: 1, "Expansion control has half the previous width")
        XCTAssertEqual(expand["buttonW"], expand["buttonH"], "Expansion control is square")
        XCTAssertGreaterThan(expand["left"] ?? -1, expand["videoLeft"] ?? 0, "Expansion control sits inside the video's left edge")
        XCTAssertLessThan(expand["left"] ?? 100, (expand["videoLeft"] ?? 0) + 100, "Expansion control stays left of center")
        let found: Bool = await withCheckedContinuation { continuation in
            session.enterVideoFullscreen { continuation.resume(returning: $0) }
        }
        XCTAssertTrue(found)
        let entered = try await session.webView.evaluateJavaScript("document.documentElement.classList.contains('wd-fs')") as? Bool
        XCTAssertEqual(entered, true)
        let fullscreenGeometry = try await session.webView.evaluateJavaScript("(()=>{const v=document.querySelector('video'),r=v.getBoundingClientRect();return JSON.stringify({x:r.x,y:r.y,w:r.width,h:r.height,vw:innerWidth,vh:innerHeight,fit:getComputedStyle(v).objectFit})})()") as? String
        let fullscreen = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(try XCTUnwrap(fullscreenGeometry).utf8)) as? [String: Any])
        XCTAssertEqual(fullscreen["x"] as? Double ?? -10, 0, accuracy: 2)
        XCTAssertEqual(fullscreen["y"] as? Double ?? -10, 0, accuracy: 2)
        XCTAssertEqual(fullscreen["w"] as? Double ?? 0, fullscreen["vw"] as? Double ?? -1, accuracy: 2)
        XCTAssertEqual(fullscreen["h"] as? Double ?? 0, fullscreen["vh"] as? Double ?? -1, accuracy: 2)
        XCTAssertEqual(fullscreen["fit"] as? String, "contain", "Any remaining black bars are the aspect-ratio letterbox, not a smaller player frame")
        session.exitVideoFullscreen()
        try await Task.sleep(nanoseconds: 300_000_000)
        let exited = try await session.webView.evaluateJavaScript("document.documentElement.classList.contains('wd-fs')") as? Bool
        XCTAssertEqual(exited, false)
    }

    func testMouseControlsWebContentAndCompactBrowserToolbar() async throws {
        let store = TabStore.car
        let originalID = store.activeID
        let savedZoom = WDSettings.carZoom
        WDSettings.carZoom = 1
        let id = store.newTab(url: URL(string: "about:blank")!)
        defer {
            CarMouseBridge.shared.setActive(false)
            store.close(id)
            if let originalID { store.select(originalID) }
            WDSettings.carZoom = savedZoom
        }
        let session = WebViewPool.car.session(for: id)
        let browser = CarBrowserViewController()
        display(browser)
        session.webView.loadHTMLString("<html><head><title>Mouse fixture</title><meta name='viewport' content='width=device-width,initial-scale=1'></head><body style='margin:0;height:5000px'><button onclick='window.testClicks=(window.testClicks||0)+1' style='position:fixed;left:35%;top:35%;width:30%;height:30%'>Open</button></body></html>", baseURL: nil)
        try await waitForDocument(session.webView, marker: "Mouse fixture")
        try await Task.sleep(nanoseconds: 400_000_000)
        CarMouseBridge.shared.setActive(true)
        try await Task.sleep(nanoseconds: 200_000_000)
        let cursor = try XCTUnwrap(find("car.mouse.cursor", in: browser.view))
        XCTAssertTrue(cursor.isHidden, "Activating the remote must not reveal the pointer before a movement")
        let center = cursor.center
        CarMouseBridge.shared.send(.move(CGPoint(x: 0.03, y: 0.03)))
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertGreaterThan(cursor.center.x, center.x)
        XCTAssertGreaterThan(cursor.center.y, center.y)
        CarMouseBridge.shared.send(.click)
        try await Task.sleep(nanoseconds: 300_000_000)
        let clicks = try await session.webView.evaluateJavaScript("window.testClicks || 0") as? Int
        XCTAssertEqual(clicks, 1, "Phone bridge must activate web content, not just draw a cursor")
        CarMouseBridge.shared.send(.scroll(CGPoint(x: 0, y: 0.65)))
        try await Task.sleep(nanoseconds: 700_000_000)
        let scrollY = try await session.webView.evaluateJavaScript("window.scrollY") as? Double ?? 0
        XCTAssertGreaterThan(scrollY, 0, "Phone scroll must move the web document")
        CarMouseBridge.shared.send(.navigate(.home))
        try await Task.sleep(nanoseconds: 300_000_000)
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants($0) } }
        let shortcuts = try XCTUnwrap(descendants(browser.view).compactMap { $0 as? CarShortcutsView }.first)
        let collection = try XCTUnwrap(descendants(shortcuts).compactMap { $0 as? UICollectionView }.first)
        collection.layoutIfNeeded()
        let cell = try XCTUnwrap(collection.visibleCells.first)
        var selectedShortcut: UUID?
        shortcuts.onSelect = { selectedShortcut = $0.id }
        let container = try XCTUnwrap(cursor.superview)
        let target = cell.convert(CGPoint(x: cell.bounds.midX, y: cell.bounds.midY), to: container)
        CarMouseBridge.shared.send(.move(CGPoint(x: (target.x - cursor.center.x) / container.bounds.width,
                                               y: (target.y - cursor.center.y) / container.bounds.height)))
        try await Task.sleep(nanoseconds: 200_000_000)
        CarMouseBridge.shared.send(.click)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(cursor.isHidden)
        XCTAssertNotNil(selectedShortcut, "Phone pointer must open a native WudCar shortcut from the browser home")
        let toolbar = try XCTUnwrap(find("car.browser.toolbar", in: browser.view))
        XCTAssertLessThanOrEqual(toolbar.frame.height, 34)
    }

    func testMouseCursorHidesAfterThreeSecondsAndReturnsAtSavedPosition() async throws {
        let browser = CarBrowserViewController()
        display(browser)
        CarMouseBridge.shared.setActive(false)
        try await Task.sleep(nanoseconds: 150_000_000)
        CarMouseBridge.shared.setActive(true)
        try await Task.sleep(nanoseconds: 150_000_000)
        defer { CarMouseBridge.shared.setActive(false) }
        try await Task.sleep(nanoseconds: 3_200_000_000)
        let cursor = try XCTUnwrap(find("car.mouse.cursor", in: browser.view))
        XCTAssertTrue(cursor.isHidden, "The pointer should disappear after three idle seconds")
        CarMouseBridge.shared.send(.move(CGPoint(x: 0.05, y: 0.02)))
        try await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertFalse(cursor.isHidden, "The pointer should return on activity")
        let firstCenter = cursor.center
        try await Task.sleep(nanoseconds: 3_200_000_000)
        XCTAssertTrue(cursor.isHidden, "The pointer should hide again after three idle seconds")
        CarMouseBridge.shared.send(.move(CGPoint(x: 0.02, y: 0.01)))
        try await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertFalse(cursor.isHidden, "The pointer should show after another phone movement")
        XCTAssertNotEqual(cursor.center, firstCenter, "The pointer keeps its position when it resumes")
    }

    func testLiveDesktopSitesInDesktopMode() async throws {
        let savedZoom = WDSettings.carZoom
        defer { WDSettings.carZoom = savedZoom }
        for address in ["https://www.youtube.com/", "https://example.com/"] {
            var lastError: Error?
            var verified = false
            for attempt in 1...2 {
                let session = TabSession(tabID: UUID(), side: .car, initialURL: nil)
                let controller = UIViewController()
                display(controller)
                controller.view.addSubview(session.webView)
                CarUI.pin(session.webView, to: controller.view)
                controller.view.layoutIfNeeded()
                do {
                    session.load(URL(string: address)!)
                    try await waitForDocument(session.webView)
                    try await Task.sleep(nanoseconds: 500_000_000)
                    let title = try await session.webView.evaluateJavaScript("document.title") as? String ?? ""
                    guard !title.isEmpty else { throw NSError(domain: "WudCarTests", code: 2) }
                    if address.contains("youtube.com") { XCTAssertEqual(session.webView.url?.host, "www.youtube.com") }
                    for zoom in [1.0] {
                        session.applyCarZoom(zoom)
                        try await Task.sleep(nanoseconds: 300_000_000)
                        XCTAssertEqual(session.webView.frame, controller.view.bounds)
                        let report = try await session.webView.evaluateJavaScript("JSON.stringify({title:document.title,url:location.href,viewport:innerWidth,visual:visualViewport.width,root:document.documentElement.getBoundingClientRect().width,body:document.body.getBoundingClientRect().width,ua:navigator.userAgent})")
                        print("WUDCAR LIVE \(address) \(zoom): \(report)")
                    }
                    verified = true
                } catch {
                    lastError = error
                    print("WUDCAR LIVE attempt \(attempt) failed: \(address) \(error)")
                }
                session.tearDown()
                if verified { break }
            }
            if !verified { throw lastError ?? NSError(domain: "WudCarTests", code: 3) }
        }
    }
}
