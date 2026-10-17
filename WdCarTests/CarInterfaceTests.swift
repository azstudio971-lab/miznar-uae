import XCTest
import UIKit
import WebKit
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
        XCTAssertNotNil(find("car.home", in: dashboard.view))
        menu.selectedSegmentIndex = 2
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
        menu.selectedSegmentIndex = 1
        menu.sendActions(for: .valueChanged)
        XCTAssertTrue(dashboard.children.contains { $0 is CarBrowserViewController })
        menu.selectedSegmentIndex = 0
        menu.sendActions(for: .valueChanged)
        XCTAssertNotNil(find("car.home", in: dashboard.view))
    }

    private func waitForDocument(_ web: WKWebView, marker: String? = nil) async throws {
        for _ in 0..<300 {
            if !web.isLoading,
               let ready = try? await web.evaluateJavaScript("document.readyState") as? String,
               ready == "complete" {
                if marker == nil { return }
                if let title = try? await web.evaluateJavaScript("document.title") as? String, title == marker { return }
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw NSError(domain: "WudCarTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Web document did not finish loading"])
    }

    func testFullFrameAtAllZoomLevelsAndVideoExit() async throws {
        let session = TabSession(tabID: UUID(), side: .car, initialURL: nil)
        defer { session.tearDown() }
        let controller = UIViewController()
        display(controller)
        controller.view.addSubview(session.webView)
        CarUI.pin(session.webView, to: controller.view)
        controller.view.layoutIfNeeded()
        session.webView.loadHTMLString("<html><head><title>WudCar layout fixture</title><meta name='viewport' content='width=device-width, initial-scale=1'></head><body style='margin:0;background:#e9b33f'><div style='width:100%;height:100vh'><video controls width='640' height='360'></video></div></body></html>", baseURL: nil)
        try await waitForDocument(session.webView, marker: "WudCar layout fixture")
        for zoom in [0.5, 1.0, 1.5] {
            session.webView.pageZoom = CGFloat(zoom)
            controller.view.layoutIfNeeded()
            XCTAssertEqual(session.webView.frame, controller.view.bounds)
            XCTAssertEqual(session.webView.transform, .identity)
            XCTAssertEqual(Double(session.webView.pageZoom), zoom, accuracy: 0.001)
            let metrics = try await session.webView.evaluateJavaScript("JSON.stringify({viewport:innerWidth,document:document.documentElement.clientWidth,zoom:document.documentElement.style.zoom})")
            print("WUDCAR ZOOM \(zoom): \(metrics)")
        }
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

    func testLiveDesktopSitesAtThreeZoomLevels() async throws {
        let session = TabSession(tabID: UUID(), side: .car, initialURL: nil)
        defer { session.tearDown() }
        session.setDesktopMode(true)
        let controller = UIViewController()
        display(controller)
        controller.view.addSubview(session.webView)
        CarUI.pin(session.webView, to: controller.view)
        controller.view.layoutIfNeeded()
        for address in ["https://www.youtube.com/", "https://example.com/"] {
            session.load(URL(string: address)!)
            try await waitForDocument(session.webView)
            let title = try await session.webView.evaluateJavaScript("document.title") as? String ?? ""
            XCTAssertFalse(title.isEmpty)
            for zoom in [0.5, 1.0, 1.5] {
                session.webView.pageZoom = CGFloat(zoom)
                try await Task.sleep(nanoseconds: 300_000_000)
                XCTAssertEqual(session.webView.frame, controller.view.bounds)
                let report = try await session.webView.evaluateJavaScript("JSON.stringify({title:document.title,url:location.href,viewport:innerWidth,document:document.documentElement.clientWidth,ua:navigator.userAgent})")
                print("WUDCAR LIVE \(address) \(zoom): \(report)")
            }
        }
    }
}
