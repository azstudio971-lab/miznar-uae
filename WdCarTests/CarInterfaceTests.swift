import XCTest
import UIKit
import WebKit
import SwiftUI
@testable import WdCar

@MainActor
final class CarInterfaceTests: XCTestCase {
    private var testWindow: UIWindow!

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
        welcomeAttachment.name = "wudcar-update8-home-preview"
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
        XCTAssertTrue(dashboard.children.contains { $0 is UIHostingController<XtreamHomeView> })

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
        for host in ["www.mp3quran.net", "m.soundcloud.com", "www.netflix.com", "pranx.com",
                     "tv2tv.com", "www.primevideo.com", "www.tod.tv", "www.crazygames.com"] {
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
        controller.view.addSubview(session.webView)
        CarUI.pin(session.webView, to: controller.view)
        controller.view.layoutIfNeeded()
        session.webView.loadHTMLString("<html><head><title>WudCar layout fixture</title><meta name='viewport' content='width=device-width, initial-scale=1'></head><body style='margin:0;background:#000'><div id='fill' style='width:100%;min-height:5000px;background:#e9b33f'><video controls width='640' height='360'></video></div></body></html>", baseURL: nil)
        try await waitForDocument(session.webView, marker: "WudCar layout fixture")
        for zoom in [0.5, 1.0, 1.5] {
            session.applyCarZoom(zoom)
            controller.view.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 300_000_000)
            let fillWidth = try await session.webView.evaluateJavaScript("document.getElementById('fill').getBoundingClientRect().width") as? Double ?? 0
            let viewportWidth = try await session.webView.evaluateJavaScript("window.visualViewport.width") as? Double ?? 0
            XCTAssertGreaterThan(fillWidth, 0)
            XCTAssertEqual(fillWidth, viewportWidth, accuracy: 1, "Page content must fill the visual viewport at every zoom level")
            XCTAssertEqual(session.webView.frame, controller.view.bounds)
            XCTAssertEqual(session.webView.transform, .identity)
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
        let found: Bool = await withCheckedContinuation { continuation in
            session.enterVideoFullscreen { continuation.resume(returning: $0) }
        }
        XCTAssertTrue(found)
        let entered = try await session.webView.evaluateJavaScript("document.documentElement.classList.contains('wd-fs')") as? Bool
        XCTAssertEqual(entered, true)
        session.exitVideoFullscreen()
        try await Task.sleep(nanoseconds: 300_000_000)
        let exited = try await session.webView.evaluateJavaScript("document.documentElement.classList.contains('wd-fs')") as? Bool
        XCTAssertEqual(exited, false)
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
