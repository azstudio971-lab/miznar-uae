import XCTest
import UIKit
import CarPlay
@testable import WdCar

final class Car225Tests: XCTestCase {
    @MainActor func testReleaseManifestDeclaresOnlyPhoneAndNativeCarPlayScenes() throws {
        let manifest = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest") as? [String: Any])
        let scenes = try XCTUnwrap(manifest["UISceneConfigurations"] as? [String: Any])
        XCTAssertEqual(Set(scenes.keys), ["UIWindowSceneSessionRoleApplication", "CPTemplateApplicationSceneSessionRoleApplication"])
        let native = try XCTUnwrap((scenes["CPTemplateApplicationSceneSessionRoleApplication"] as? [[String: Any]])?.first)
        XCTAssertEqual(native["UISceneClassName"] as? String, "CPTemplateApplicationScene")
        XCTAssertTrue((native["UISceneDelegateClassName"] as? String)?.hasSuffix("CarSceneDelegate") == true)
    }
    @MainActor func testLaunchRootIsNativeNonemptyAndDescribesVideoAndAudio() throws {
        let old = WDSettings.carLanguage
        defer { WDSettings.carLanguage = old }
        for language in ["ar", "en"] {
            WDSettings.carLanguage = language
            let ui = CarTemplateUI(interfaceController: nil)
            let root = ui.makeLaunchTemplate()
            XCTAssertFalse(root.sections.flatMap(\.items).isEmpty)
            XCTAssertTrue(root.title?.contains(language == "ar" ? "مشغّل للفيديو والصوت" : "Video and audio player") == true)
            ui.prepareTemplates()
            let mediaRoot = try XCTUnwrap(ui.makeRootTemplate(maximumTabCount: 0) as? CPListTemplate)
            let rows = mediaRoot.sections.flatMap(\.items).compactMap { $0 as? CPListItem }
            XCTAssertEqual(rows.count, 5)
            XCTAssertTrue(rows.allSatisfy { $0.handler != nil })
        }
    }
    @MainActor func testBrowserEntryIsInsideFavorites() throws {
        let old = WDSettings.carLanguage
        defer { WDSettings.carLanguage = old }
        for language in ["ar", "en"] {
            WDSettings.carLanguage = language
            let ui = CarTemplateUI(interfaceController: nil)
            ui.prepareTemplates()
            XCTAssertTrue(ui.favoriteTitles.contains(language == "ar" ? "المتصفح" : "Browser"))
        }
        XCTAssertFalse(CarScreenLauncher.shared.browserRequested)
    }
    @MainActor func testConnectionDiagnosticsAreLocalAndBounded() throws {
        let name = "wd.test.225.\(UUID().uuidString)"
        let storage = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { storage.removePersistentDomain(forName: name) }
        let log = CarPlayLaunchDiagnostics(storage: storage)
        for index in 0..<25 { log.record("scene-\(index)") }
        XCTAssertEqual(log.events.count, 20)
        XCTAssertTrue(log.events.last?.hasSuffix("scene-24") == true)
        XCTAssertEqual(CarPlayLaunchDiagnostics(storage: storage).events, log.events)
    }
}
