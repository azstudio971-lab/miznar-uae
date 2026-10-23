import XCTest
import UIKit
import CarPlay
import SwiftUI
@testable import WdCar

final class Car224Tests: XCTestCase {
    @MainActor func testNativeNavigationIncludesAllMediaDestinationsInBothLanguages() throws {
        let previous = WDSettings.carLanguage
        defer { WDSettings.carLanguage = previous }
        for (language, titles) in [
            ("ar", ["المكتبة", "المفضلة", "الملفات والبث", "الترفيه", "الإعدادات"]),
            ("en", ["Library", "Favorites", "Files & AirPlay", "Entertainment", "Settings"])
        ] {
            WDSettings.carLanguage = language
            let ui = CarTemplateUI(interfaceController: nil)
            ui.prepareTemplates()
            // A limited template entitlement must keep every destination reachable.
            let grouped = try XCTUnwrap(ui.makeRootTemplate(maximumTabCount: 1) as? CPListTemplate)
            XCTAssertEqual(grouped.sections.flatMap(\.items).compactMap { ($0 as? CPListItem)?.text }, titles)
            let root = ui.makeRootTemplate(maximumTabCount: CPTabBarTemplate.maximumTabCount)
            if CPTabBarTemplate.maximumTabCount >= 5 {
                let tabs = try XCTUnwrap(root as? CPTabBarTemplate)
                XCTAssertEqual(tabs.templates.map(\.tabTitle), titles.map(Optional.some))
                let library = try XCTUnwrap(tabs.templates.first as? CPListTemplate)
                XCTAssertTrue(library.title?.contains(language == "ar" ? "مشغّل للفيديو والصوت" : "Video and audio player") == true)
                XCTAssertTrue(library.sections.flatMap(\.items).contains { ($0 as? CPListItem)?.text?.contains("M3U / Xtream") == true })
                let files = try XCTUnwrap(tabs.templates[2] as? CPListTemplate)
                XCTAssertEqual(files.sections.flatMap(\.items).count, 3)
            } else { XCTAssertTrue(root is CPListTemplate) }
        }
    }

    @MainActor func testCarPlayFavoritesUseTheSameMediaAsPhone() throws {
        let library = MediaLibrary.shared
        let originalIDs = Set(library.items.map(\.id))
        let language = WDSettings.carLanguage
        WDSettings.carLanguage = "en"
        defer {
            for item in library.items where !originalIDs.contains(item.id) { library.remove(item.id) }
            WDSettings.carLanguage = language
        }
        try library.addRemote(title: "224 favorite fixture", url: URL(string: "https://example.test/224-\(UUID().uuidString).m3u8")!, isLive: false)
        let item = try XCTUnwrap(library.items.first { !originalIDs.contains($0.id) })
        library.toggleFavorite(item.id)
        let ui = CarTemplateUI(interfaceController: nil)
        ui.prepareTemplates()
        // Inspect the same destination template the grouped and tab roots use.
        XCTAssertTrue(ui.favoriteTitles.contains(item.title))
        library.toggleFavorite(item.id)
        ui.prepareTemplates()
        XCTAssertFalse(ui.favoriteTitles.contains(item.title))
    }

    @MainActor func testExternalSceneDoesNotMountLegacyDashboardOnConnection() throws {
        CarScreenLauncher.shared.closeBrowser()
        PlaybackManager.shared.stop()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let delegate = CarExternalDisplaySceneDelegate()
        delegate.connect(to: scene, interactive: false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertNil(delegate.window, "Connecting an external surface must not cover the native CarPlay media root")
        delegate.sceneDidDisconnect(scene)
    }

    @MainActor func testPolicyAndCastPageRenderInBothLanguages() throws {
        let old = UserDefaults.standard.object(forKey: WDKeys.language)
        defer {
            if let old { UserDefaults.standard.set(old, forKey: WDKeys.language) }
            else { UserDefaults.standard.removeObject(forKey: WDKeys.language) }
        }
        for language in ["ar", "en"] {
            UserDefaults.standard.set(language, forKey: WDKeys.language)
            let privacy = LegalTextView(kind: .privacy)
            let terms = LegalTextView(kind: .terms)
            XCTAssertTrue(privacy.privacy.contains(language == "ar" ? "مشغّل للفيديو والصوت" : "video and audio player"))
            XCTAssertTrue(terms.terms.contains(language == "ar" ? "لا يوفر التطبيق المحتوى" : "does not provide or host content"))
            for (name, view) in [("cast", AnyView(NavigationStack { MediaCastingView() })), ("privacy", AnyView(NavigationStack { privacy }))] {
                let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
                window.overrideUserInterfaceStyle = .dark
                window.rootViewController = UIHostingController(rootView: view.environment(\.layoutDirection, language == "ar" ? .rightToLeft : .leftToRight))
                window.makeKeyAndVisible()
                window.rootViewController?.view.layoutIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.3))
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
                }
                let data = try XCTUnwrap(image.cgImage?.dataProvider?.data)
                let bytes = try XCTUnwrap(CFDataGetBytePtr(data))
                XCTAssertGreaterThan(Set(stride(from: 0, to: CFDataGetLength(data), by: 97).map { bytes[$0] }).count, 8)
                let attachment = XCTAttachment(image: image)
                attachment.name = "224-\(name)-\(language)"
                attachment.lifetime = .keepAlways
                add(attachment)
                window.isHidden = true
            }
        }
    }
}
