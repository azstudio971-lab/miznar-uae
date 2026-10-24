import XCTest
import SwiftUI
import AVFoundation
import CarPlay
@testable import WdCar

@MainActor final class Release142PlayerTests: XCTestCase {
    func testExternalDisplayUsesMediaPlayerTabsAndHomeSettings() async throws {
        let oldLanguage = WDSettings.carLanguage
        defer { WDSettings.carLanguage = oldLanguage }
        func find(_ id: String, _ view: UIView) -> UIView? {
            if view.accessibilityIdentifier == id { return view }
            return view.subviews.lazy.compactMap { find(id, $0) }.first
        }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        for language in ["ar", "en"] {
            WDSettings.carLanguage = language
            for size in [CGSize(width: 960, height: 480), CGSize(width: 640, height: 360)] {
                let dashboard = CarDashboardViewController()
                let window = UIWindow(windowScene: scene)
                window.rootViewController = dashboard; window.makeKeyAndVisible()
                defer { window.isHidden = true; window.rootViewController = nil }
                dashboard.view.frame = CGRect(origin: .zero, size: size)
                dashboard.view.layoutIfNeeded()
                let menu = try XCTUnwrap(find("car.navigation", dashboard.view) as? UISegmentedControl)
                XCTAssertEqual(menu.numberOfSegments, 4)
                XCTAssertEqual((0..<4).compactMap { menu.titleForSegment(at: $0) }, language == "ar"
                    ? ["الرئيسية", "مكتبة الفيديو", "M3U IPTV Player", "الترفيه"]
                    : ["Home", "Video Library", "M3U IPTV Player", "Entertainment"])
                XCTAssertEqual(menu.selectedSegmentIndex, 0)
                let settings = try XCTUnwrap(find("car.home.settings", dashboard.view) as? UIButton)
                settings.sendActions(for: .touchUpInside)
                XCTAssertEqual(menu.selectedSegmentIndex, 0)
                XCTAssertNotNil(find("car.settings", dashboard.view))
                let back = try XCTUnwrap(find("car.settings.back", dashboard.view) as? UIButton)
                back.sendActions(for: .touchUpInside)
                XCTAssertNotNil(find("car.home", dashboard.view))
                let attachment = XCTAttachment(image: UIGraphicsImageRenderer(size: size).image { dashboard.view.layer.render(in: $0.cgContext) })
                attachment.name = "142-16-external-dashboard-\(language)-\(Int(size.width))x\(Int(size.height))"
                attachment.lifetime = .keepAlways; add(attachment)
                CarMouseBridge.shared.send(.selectSection(.settings))
                try await Task.sleep(for: .milliseconds(200))
                XCTAssertEqual(menu.selectedSegmentIndex, 0)
                XCTAssertNotNil(find("car.settings", dashboard.view))
                CarMouseBridge.shared.send(.selectSection(.television))
                try await Task.sleep(for: .milliseconds(200))
                XCTAssertEqual(menu.selectedSegmentIndex, 2)
                CarMouseBridge.shared.send(.selectSection(.entertainment))
                try await Task.sleep(for: .milliseconds(200))
                XCTAssertEqual(menu.selectedSegmentIndex, 3)
            }
        }
    }

    func testExternalLibraryRendersSharedMediaAndPlaylists() async throws {
        let library = MediaLibrary.shared
        let url = URL(string: "https://example.com/test-\(UUID().uuidString).m3u8")!
        try library.addRemote(title: "Library display fixture", url: url, isLive: true)
        let item = try XCTUnwrap(library.items.first { $0.url == url })
        defer { library.remove(item.id) }
        library.createPlaylist("Car library fixture")
        let playlist = try XCTUnwrap(library.playlists.last)
        defer { library.removePlaylist(playlist.id) }
        library.addToPlaylist(playlist.id, item: item)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let controller = UIHostingController(rootView: CarMediaLibraryView())
        window.rootViewController = controller; window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.frame = CGRect(x: 0, y: 0, width: 960, height: 480)
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(300))
        let updated = try XCTUnwrap(library.playlists.first { $0.id == playlist.id })
        XCTAssertEqual(library.contents(updated).map(\.id), [item.id])
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(size: controller.view.bounds.size).image { controller.view.layer.render(in: $0.cgContext) })
        attachment.name = "142-16-external-library-shared-store"
        attachment.lifetime = .keepAlways; add(attachment)
    }

    func testDrivingDefaultAndExplicitPreference() {
        let old = UserDefaults.standard.object(forKey: WDKeys.lockVideoWhileDriving)
        defer { UserDefaults.standard.set(old, forKey: WDKeys.lockVideoWhileDriving) }
        UserDefaults.standard.removeObject(forKey: WDKeys.lockVideoWhileDriving)
        XCTAssertTrue(WDSettings.lockVideoWhileDriving)
        WDSettings.lockVideoWhileDriving = false
        XCTAssertFalse(WDSettings.lockVideoWhileDriving)
    }
    func testImportPlaylistReorderPositionAndRemoval() async throws {
        let library = MediaLibrary.shared
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
        buffer.frameLength = 44100
        for index in 0..<44100 { buffer.floatChannelData![0][index] = 0 }
        do { let file = try AVAudioFile(forWriting: url, settings: format.settings); try file.write(from: buffer) }
        defer { try? FileManager.default.removeItem(at: url) }
        try await library.importFile(url)
        let first = try XCTUnwrap(library.items.last)
        defer { library.remove(first.id) }
        XCTAssertTrue(first.isAudio)
        XCTAssertNotEqual(first.url, url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.url!.path))
        XCTAssertGreaterThan(first.duration ?? 0, 0)
        library.record(url: first.url!, position: 0.5)
        XCTAssertEqual(library.items.first { $0.id == first.id }?.position, 0.5)
        XCTAssertTrue(library.continueWatching.contains { $0.id == first.id })
        library.createPlaylist("Test-" + UUID().uuidString)
        var playlist = try XCTUnwrap(library.playlists.last)
        defer { library.removePlaylist(playlist.id) }
        library.addToPlaylist(playlist.id, item: first)
        try await library.importFile(url)
        let second = try XCTUnwrap(library.items.last)
        defer { library.remove(second.id) }
        library.addToPlaylist(playlist.id, item: second)
        playlist = try XCTUnwrap(library.playlists.first { $0.id == playlist.id })
        playlist.itemIDs.reverse(); playlist.title = "Renamed"; playlist.favorite = true
        library.updatePlaylist(playlist)
        XCTAssertEqual(library.contents(playlist).map(\.id), [second.id, first.id])
        library.remove(first.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.url!.path))
        XCTAssertFalse(library.playlists.first { $0.id == playlist.id }!.itemIDs.contains(first.id))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
    func testSubtitleParsingAndSkipPreference() {
        let key = "wd.media.skip", old = UserDefaults.standard.object(forKey: "wd.media.skip")
        defer { UserDefaults.standard.set(old, forKey: key) }
        for value in [10,15,30] { UserDefaults.standard.set(value, forKey: key); XCTAssertEqual(PlayerPreferences.skip, value) }
        UserDefaults.standard.set(99, forKey: key); XCTAssertEqual(PlayerPreferences.skip, 15)
        let cues = SubtitleParser.parse("1\n00:00:01,000 --> 00:00:02,500\nHello\n\n")
        XCTAssertEqual(cues, [SubtitleCue(start: 1, end: 2.5, text: "Hello")])
    }
    func testPlayerScreenshots() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; window.rootViewController = nil }
        for (name, screen) in [("home", AnyView(HomeView(selectTab: { _ in }).environmentObject(AppState.shared))), ("library", AnyView(LibraryView())), ("iptv", AnyView(XtreamHomeView())), ("player-settings", AnyView(NavigationStack { MediaSettingsView() }))] {
            for (width, height) in [(1320,2868),(1284,2778)] {
                let controller = UIHostingController(rootView: screen)
                window.rootViewController = controller; window.makeKeyAndVisible()
                controller.view.frame = CGRect(x: 0, y: 0, width: CGFloat(width)/3, height: CGFloat(height)/3)
                controller.view.layoutIfNeeded()
                try await Task.sleep(nanoseconds: 300_000_000)
                let format = UIGraphicsImageRendererFormat(); format.scale = 3
                let image = UIGraphicsImageRenderer(size: controller.view.bounds.size, format: format).image { controller.view.layer.render(in: $0.cgContext) }
                let attachment = XCTAttachment(image: image); attachment.name = "142-\(name)-\(width)x\(height)"; attachment.lifetime = .keepAlways; add(attachment)
            }
        }
    }
}
