import XCTest
import UIKit
import WebKit
@testable import WdCar

/// Independent of the StoreKit purchase fixture so UI/resource regressions can run on current runtimes.
@MainActor
final class Release150Tests: XCTestCase {
    private var testWindow: UIWindow?
    override func tearDown() {
        testWindow?.isHidden = true
        testWindow?.rootViewController = nil
        testWindow = nil
        super.tearDown()
    }
    private func display(_ controller: UIViewController) {
        controller.loadViewIfNeeded()
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: CGRect(x: 0, y: 0, width: 960, height: 480))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        testWindow = window
        controller.view.frame = CGRect(x: 0, y: 0, width: 960, height: 480)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }
    private func find(_ identifier: String, in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == identifier { return view }
        for child in view.subviews { if let match = find(identifier, in: child) { return match } }
        return nil
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
        let png = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512)).image { _ in UIColor.red.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 512, height: 512)) }.pngData()
        XCTAssertNotNil(SeasonalLogo.validatedImage(data: png, response: ok))
        XCTAssertNil(SeasonalLogo.validatedImage(data: png, response: missing))
        XCTAssertNil(SeasonalLogo.validatedImage(data: png, response: html))
        XCTAssertNil(SeasonalLogo.validatedImage(data: nil, response: nil))
        XCTAssertNil(SeasonalLogo.validatedImage(data: Data("broken".utf8), response: ok))
    }

    func test150EntertainmentLayoutSnapshots() throws {
        for size in [CGSize(width: 640, height: 360), CGSize(width: 960, height: 480), CGSize(width: 1280, height: 480)] {
            let controller = UIViewController()
            let shortcuts = CarShortcutsView(frame: .zero)
            controller.view = shortcuts
            display(controller)
            controller.view.frame = CGRect(origin: .zero, size: size)
            controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
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
        XCTAssertEqual(reveal.menu?.children.count, 2)
    }

}
