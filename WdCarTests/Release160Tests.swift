import XCTest
import UIKit
import WebKit
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
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let w = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: CGRect(origin: .zero, size: size))
        let vc = UIViewController()
        vc.view = view
        w.rootViewController = vc
        w.makeKeyAndVisible()
        window = w
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutIfNeeded()
    }
    private func find(_ id: String, in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == id { return view }
        return view.subviews.lazy.compactMap { self.find(id, in: $0) }.first
    }
    private func evaluate(_ js: String, web: WKWebView) async throws -> Any {
        try await withCheckedThrowingContinuation { continuation in
            web.evaluateJavaScript(js) { value, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: value ?? NSNull()) }
            }
        }
    }
    private func ready(_ web: WKWebView, marker: String = "document.readyState === 'complete'") async throws {
        for _ in 0..<150 {
            if (try? await evaluate(marker, web: web)) as? Bool == true { return }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        XCTFail("WKWebView did not finish the requested document")
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
        <h1>WudCar desktop viewport fixture</h1><input placeholder="Search"><main><article>Video 1</article><article>Video 2</article><article>Video 3</article></main><a href="#second">Next page</a><div style="height:2000px">Scroll</div><div id="second">Second page</div>
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
            session.setDesktopMode(false)
            host.setNeedsLayout(); host.layoutIfNeeded()
            XCTAssertEqual(session.webView.bounds.width, sizes.last!.width, accuracy: 1)
        }
    }
    /// A network probe on real WKWebView in Simulator, never a claim of physical-device acceptance.
    func testLiveYouTubePhoneBeforeCarProbe() async throws {
        let phone = WDSettings.phoneDesktopMode, car = WDSettings.carDesktopMode, zoom = WDSettings.carZoom
        defer { WDSettings.phoneDesktopMode = phone; WDSettings.carDesktopMode = car; WDSettings.carZoom = zoom }
        WDSettings.phoneDesktopMode = true; WDSettings.carDesktopMode = true; WDSettings.carZoom = 1
        for side in [BrowserSide.phone, .car] {
            let session = TabSession(tabID: UUID(), side: side, initialURL: nil)
            defer { session.tearDown() }
            let host = DesktopViewportView(session: session)
            display(host, size: side == .phone ? CGSize(width: 390, height: 700) : CGSize(width: 960, height: 480))
            session.load(URL(string: "https://www.youtube.com/results?search_query=NASA&app=desktop")!)
            var desktop = false
            for _ in 0..<150 {
                if (try? await evaluate("!!document.querySelector('ytd-app') && document.readyState === 'complete'", web: session.webView)) as? Bool == true { desktop = true; break }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let metrics = try? await evaluate("JSON.stringify({url:location.href,title:document.title,width:innerWidth,desktop:!!document.querySelector('ytd-app'),mobile:!!document.querySelector('ytm-app'),videos:document.querySelectorAll('a[href*=watch]').length})", web: session.webView)
            let record = XCTAttachment(string: "SIMULATOR ONLY \(side): \(String(describing: metrics)); native pageZoom=\(session.webView.pageZoom)")
            record.name = "160-live-youtube-\(side)-metrics"; record.lifetime = .keepAlways; add(record)
            try await capture(session.webView, name: "160-live-youtube-\(side)")
            guard desktop else { throw XCTSkip("Live YouTube did not expose its desktop document in Simulator (network/consent/site restriction); physical iPhone acceptance remains pending. Car phase is not attempted before phone succeeds.") }
            let width = try await evaluate("innerWidth", web: session.webView) as? Double ?? 0
            XCTAssertGreaterThanOrEqual(width, 1200)
            XCTAssertEqual(session.webView.pageZoom, 1, accuracy: 0.001)
            let mobile = try await evaluate("!!document.querySelector('ytm-app')", web: session.webView) as? Bool ?? true
            XCTAssertFalse(mobile)
        }
    }

    func testChromePrimaryActivationAndExistingRemoteRoutingWithoutMenu() throws {
        let browser = CarBrowserViewController()
        browser.loadViewIfNeeded()
        display(browser.view, size: CGSize(width: 960, height: 480))
        let hotspot = try XCTUnwrap(find("car.browser.toolbar.hotspot", in: browser.view) as? UIButton)
        let reveal = try XCTUnwrap(find("car.browser.toolbar.reveal", in: browser.view) as? UIButton)
        let toolbar = try XCTUnwrap(find("car.browser.toolbar", in: browser.view))
        XCTAssertTrue(toolbar.isHidden)
        XCTAssertTrue(browser.activateBrowserChrome(at: hotspot.convert(CGPoint(x: 1, y: 10), to: browser.view)))
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
