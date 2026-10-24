import XCTest
import UIKit
import WebKit
import SwiftUI
@testable import WdCar

@MainActor
final class Release160Tests: XCTestCase {
    private var window: UIWindow?
    override func tearDown() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        super.tearDown()
    }
    private func display(_ view: UIView, size: CGSize) {
        let vc = UIViewController()
        vc.view = view
        display(vc, size: size)
    }
    private func display(_ controller: UIViewController, size: CGSize) {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let w = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: CGRect(origin: .zero, size: size))
        w.rootViewController = controller
        w.makeKeyAndVisible()
        window = w
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.layoutIfNeeded()
    }
    private func find(_ id: String, in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == id { return view }
        return view.subviews.lazy.compactMap { self.find(id, in: $0) }.first
    }
    private func evaluate(_ js: String, web: WKWebView) async throws -> Any {
        try await withCheckedThrowingContinuation { continuation in
            var completed = false
            let timeout = DispatchWorkItem {
                guard !completed else { return }
                completed = true
                continuation.resume(throwing: NSError(domain: "WebKitTestTimeout", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "JavaScript callback timed out after 10 seconds: \(js)"]))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeout)
            web.evaluateJavaScript(js) { value, error in
                guard !completed else { return }
                completed = true
                timeout.cancel()
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: value ?? NSNull()) }
            }
        }
    }

    private func ready(_ web: WKWebView, marker: String = "document.readyState === 'complete'") async throws {
        for _ in 0..<150 {
            if !web.isLoading, (try? await evaluate(marker, web: web)) as? Bool == true { return }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        XCTFail("WKWebView did not finish the requested document")
    }
    /// Require five seconds of continuous desktop rendering, including site-triggered reloads.
    private func stableYouTube(_ web: WKWebView, path: String) async throws -> Bool {
        var consecutive = 0
        let literal = WebEngine.jsLiteral(path)
        for _ in 0..<180 {
            let desktop = (try await evaluate("location.pathname === \(literal) && document.readyState === 'complete' && document.title.length > 0 && !!document.querySelector('ytd-app') && !document.querySelector('ytm-app') && innerWidth >= 1200", web: web)) as? Bool == true
            consecutive = (!web.isLoading && desktop) ? consecutive + 1 : 0
            if consecutive >= 20 { return true }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        return false
    }
    private func capture(_ web: WKWebView, name: String) async throws {
        let image: UIImage = try await withCheckedThrowingContinuation { continuation in
            web.takeSnapshot(with: nil) { image, error in
                if let image { continuation.resume(returning: image) }
                else { continuation.resume(throwing: error ?? NSError(domain: "Snapshot", code: 1)) }
            }
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func captureApp(_ view: UIView, name: String) {
        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testZoomUpgradeIsOnceAndManualPreferenceSurvives() throws {
        let name = "WudCar160-\(UUID())"
        let d = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { d.removePersistentDomain(forName: name) }
        d.set(0.5, forKey: WDKeys.carZoom)
        WDSettings.migrateBrowserZoom(in: d)
        XCTAssertEqual(d.double(forKey: WDKeys.carZoom), 1)
        d.set(0.5, forKey: WDKeys.carZoom)
        WDSettings.migrateBrowserZoom(in: d)
        XCTAssertEqual(d.double(forKey: WDKeys.carZoom), 0.5, "Explicit zoom after upgrade must persist")
        d.removePersistentDomain(forName: name)
        d.set(1.25, forKey: WDKeys.carZoom)
        WDSettings.migrateBrowserZoom(in: d)
        XCTAssertEqual(d.double(forKey: WDKeys.carZoom), 1.25)
    }
    func testDesktopViewportZoomNavigationAndResizeOnPhoneThenCar() async throws {
        let phoneMode = WDSettings.phoneDesktopMode, carMode = WDSettings.carDesktopMode, zoom = WDSettings.carZoom
        defer { WDSettings.phoneDesktopMode = phoneMode; WDSettings.carDesktopMode = carMode; WDSettings.carZoom = zoom }
        WDSettings.phoneDesktopMode = true; WDSettings.carDesktopMode = true; WDSettings.carZoom = 1
        let fixture = """
        <!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>body{margin:0;background:#013748;color:white;font:24px system-ui}main{display:grid;grid-template-columns:1fr;gap:20px;padding:20px}@media(min-width:1100px){main{grid-template-columns:repeat(3,1fr)}}article{background:#182e3a;padding:30px;height:200px}a{color:#ffb13b}</style>
        <h1>WudCar desktop viewport fixture</h1><input placeholder="Search"><main><article>Video 1</article><article>Video 2</article><article>Video 3</article></main><a href="#second">Next page</a><div style="height:2000px">Scroll</div><div id="second">Second page</div><video controls width="640" height="360"></video>
        <script>setTimeout(()=>{document.body.dataset.loaded='yes'},800)</script>
        """
        for side in [BrowserSide.phone, .car] {
            let session = TabSession(tabID: UUID(), side: side, initialURL: nil)
            defer { session.tearDown() }
            let host = DesktopViewportView(session: session)
            let sizes = side == .phone ? [CGSize(width: 390, height: 700), CGSize(width: 844, height: 320)] : [CGSize(width: 640, height: 360), CGSize(width: 960, height: 480), CGSize(width: 1280, height: 480)]
            display(host, size: sizes[0])
            session.webView.loadHTMLString(fixture, baseURL: URL(string: "https://fixture.invalid"))
            try await ready(session.webView, marker: "document.body && document.body.dataset.loaded === 'yes'")
            for size in sizes {
                host.frame.size = size; host.setNeedsLayout(); host.layoutIfNeeded()
                try await Task.sleep(nanoseconds: 300_000_000)
                XCTAssertEqual(session.webView.pageZoom, 1, accuracy: 0.001)
                XCTAssertEqual(session.webView.bounds.width, 1280, accuracy: 1)
                let rendered = session.webView.convert(session.webView.bounds, to: host)
                XCTAssertEqual(rendered.width, size.width, accuracy: 1)
                XCTAssertEqual(rendered.height, size.height, accuracy: 1)
                let width = try await evaluate("innerWidth", web: session.webView) as? Double ?? 0
                XCTAssertGreaterThanOrEqual(width, 1200, "Must retain a real desktop CSS viewport after page load and resize")
                let columns = try await evaluate("getComputedStyle(document.querySelector('main')).gridTemplateColumns.split(' ').length", web: session.webView) as? Int
                XCTAssertEqual(columns, 3)
                try await capture(session.webView, name: "160-\(side)-desktop-\(Int(size.width))x\(Int(size.height))")
                _ = try await evaluate("document.querySelector('input').value='WudCar'; document.querySelector('a').click()", web: session.webView)
                let hash = try await evaluate("location.hash", web: session.webView) as? String
                XCTAssertEqual(hash, "#second")
                _ = try await evaluate("scrollTo(0,0)", web: session.webView)
            }
            if side == .car {
                let fullscreen: Bool = await withCheckedContinuation { continuation in
                    session.enterVideoFullscreen { continuation.resume(returning: $0) }
                }
                XCTAssertTrue(fullscreen, "Existing video overlay must still enter fullscreen in the fitted viewport")
                try await Task.sleep(nanoseconds: 300_000_000)
                let videoWidth = try await evaluate("document.querySelector('video').getBoundingClientRect().width", web: session.webView) as? Double ?? 0
                let viewportWidth = try await evaluate("visualViewport.width", web: session.webView) as? Double ?? 0
                XCTAssertEqual(videoWidth, viewportWidth, accuracy: 1)
                session.exitVideoFullscreen()
                try await Task.sleep(nanoseconds: 200_000_000)
                let fullscreenAfterExit = try await evaluate("document.documentElement.classList.contains('wd-fs')", web: session.webView) as? Bool ?? true
                XCTAssertFalse(fullscreenAfterExit)
            }
            session.setDesktopMode(false)
            host.setNeedsLayout(); host.layoutIfNeeded()
            XCTAssertEqual(session.webView.bounds.width, sizes.last!.width, accuracy: 1)
        }
    }
    func testYouTubeViewportFallbackIsScopedAndRespectsAuthorMetadata() async throws {
        let saved = WDSettings.phoneDesktopMode
        defer { WDSettings.phoneDesktopMode = saved }
        WDSettings.phoneDesktopMode = true
        let session = TabSession(tabID: UUID(), side: .phone, initialURL: nil)
        defer { session.tearDown() }
        display(DesktopViewportView(session: session), size: CGSize(width: 390, height: 700))
        for (index, item) in [("www.youtube.com", false), ("www.youtube.com", true), ("example.com", false)].enumerated() {
            let (host, authored) = item
            let title = "ScopedViewport-\(index)"
            let viewport = authored ? "<meta name='viewport' content='width=1024'>" : ""
            session.webView.loadHTMLString("<html><head><title>\(title)</title>\(viewport)</head><body>Fixture</body></html>", baseURL: URL(string: "https://\(host)/"))
            try await ready(session.webView, marker: "document.title === \(WebEngine.jsLiteral(title)) && document.readyState === 'complete'")
            let value = try await evaluate("document.querySelector('meta[name=viewport]')?.content || ''", web: session.webView) as? String
            XCTAssertEqual(value, authored ? "width=1024" : (host == "www.youtube.com" ? "width=device-width, initial-scale=1" : ""))
        }
    }

    /// A network probe on real WKWebView in Simulator, never a claim of physical-device acceptance.
    func testLiveYouTubePhoneBeforeCarProbe() async throws {
        print("WUDCAR160 LIVE PROBE START")
        let phone = WDSettings.phoneDesktopMode, car = WDSettings.carDesktopMode, zoom = WDSettings.carZoom
        defer { WDSettings.phoneDesktopMode = phone; WDSettings.carDesktopMode = car; WDSettings.carZoom = zoom }
        WDSettings.phoneDesktopMode = true; WDSettings.carDesktopMode = true; WDSettings.carZoom = 1
        for side in [BrowserSide.phone, .car] {
            let store = TabStore.of(side)
            guard !store.isFull else { throw XCTSkip("No disposable tab slot in test installation") }
            let previousID = store.activeID
            let id = store.newTab(url: URL(string: "https://www.youtube.com/results?search_query=NASA&app=desktop")!)
            defer { store.close(id); if let previousID { store.select(previousID) } }
            let session = WebViewPool.of(side).session(for: id)
            // Mount the shipping phone browser, including SwiftUI chrome and the real tab pool.
            let controller: UIViewController = side == .phone
                ? UIHostingController(rootView: PhoneBrowserScreen().environmentObject(AppState.shared))
                : CarBrowserViewController()
            display(controller, size: side == .phone ? CGSize(width: 390, height: 700) : CGSize(width: 960, height: 480))
            controller.view.layoutIfNeeded()
            let desktop = try await stableYouTube(session.webView, path: "/results")
            let metrics = try? await evaluate("JSON.stringify({url:location.href,title:document.title,width:innerWidth,desktop:!!document.querySelector('ytd-app'),mobile:!!document.querySelector('ytm-app'),videos:document.querySelectorAll('a[href*=watch]').length,meta:document.querySelector('meta[name=viewport]')?.content,client:document.documentElement.clientWidth,visual:visualViewport.width})", web: session.webView)
            let record = XCTAttachment(string: "SIMULATOR ONLY \(side): \(String(describing: metrics)); native pageZoom=\(session.webView.pageZoom)")
            print("WUDCAR160 LIVE \(side): \(String(describing: metrics)); native bounds=\(session.webView.bounds); fit=\(session.webView.transform); pageZoom=\(session.webView.pageZoom)")
            record.name = "160-live-youtube-\(side)-metrics"; record.lifetime = .keepAlways; add(record)
            try await capture(session.webView, name: "160-live-youtube-\(side)")
            captureApp(controller.view, name: "160-live-app-browser-\(side)")
            guard desktop else { throw XCTSkip("Live YouTube did not expose its desktop document in Simulator (network/consent/site restriction); physical iPhone acceptance remains pending. Car phase is not attempted before phone succeeds.") }
            let width = try await evaluate("innerWidth", web: session.webView) as? Double ?? 0
            XCTAssertGreaterThanOrEqual(width, 1200)
            XCTAssertEqual(session.webView.pageZoom, 1, accuracy: 0.001)
            let mobile = try await evaluate("!!document.querySelector('ytm-app')", web: session.webView) as? Bool ?? true
            XCTAssertFalse(mobile)
            session.load(URL(string: "https://www.youtube.com/@NASA/videos")!)
            let channelStable = try await stableYouTube(session.webView, path: "/@NASA/videos")
            XCTAssertTrue(channelStable, "Desktop channel must remain stable after YouTube finishes loading")
            let channelWidth = try await evaluate("innerWidth", web: session.webView) as? Double ?? 0
            XCTAssertGreaterThanOrEqual(channelWidth, 1200, "Desktop viewport must survive real YouTube page navigation")
            try await capture(session.webView, name: "160-live-youtube-channel-\(side)")
            captureApp(controller.view, name: "160-live-app-channel-\(side)")
            XCTAssertTrue(session.webView.canGoBack)
            session.goBack()
            let backStable = try await stableYouTube(session.webView, path: "/results")
            XCTAssertTrue(backStable, "Desktop mode must remain stable after going back")
            print("WUDCAR160 STABLE \(side): channelWidth=\(channelWidth), channelStable=\(channelStable), backStable=\(backStable), pageZoom=\(session.webView.pageZoom)")
            XCTAssertEqual(session.webView.pageZoom, 1, accuracy: 0.001)
        }
    }

    func testChromePrimaryActivationAndExistingRemoteRoutingWithoutMenu() throws {
        let browser = CarBrowserViewController()
        browser.loadViewIfNeeded()
        display(browser, size: CGSize(width: 960, height: 480))
        let hotspot = try XCTUnwrap(find("car.browser.toolbar.hotspot", in: browser.view) as? UIButton)
        let reveal = try XCTUnwrap(find("car.browser.toolbar.reveal", in: browser.view) as? UIButton)
        let toolbar = try XCTUnwrap(find("car.browser.toolbar", in: browser.view))
        let title = try XCTUnwrap(find("car.browser.shortcuts.title", in: browser.view) as? UILabel)
        XCTAssertEqual(title.font.pointSize, 15)
        XCTAssertTrue(toolbar.isHidden)
        let edge = try XCTUnwrap(find("car.browser.toolbar.edge", in: browser.view) as? UIButton)
        XCTAssertTrue(browser.activateBrowserChrome(at: edge.convert(CGPoint(x: 1, y: edge.bounds.midY), to: browser.view)))
        XCTAssertFalse(reveal.isHidden)
        XCTAssertNil(reveal.menu)
        XCTAssertFalse(reveal.showsMenuAsPrimaryAction)
        XCTAssertTrue(browser.activateBrowserChrome(at: reveal.convert(CGPoint(x: reveal.bounds.midX, y: reveal.bounds.midY), to: browser.view)))
        XCTAssertFalse(toolbar.isHidden)
        XCTAssertTrue(reveal.isHidden)
        browser.view.layoutIfNeeded()
        XCTAssertEqual(toolbar.bounds.height, 20, accuracy: 1)
        let image = UIGraphicsImageRenderer(size: browser.view.bounds.size).image { browser.view.layer.render(in: $0.cgContext) }
        let attachment = XCTAttachment(image: image); attachment.name = "160-compact-toolbar"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
