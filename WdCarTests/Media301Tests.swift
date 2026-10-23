import XCTest
import AVFoundation
import CoreMedia
import CarPlay
import SwiftUI
import StoreKitTest
@testable import WdCar

@MainActor
final class Media301Tests: XCTestCase {
    func testStoreScreenshotsFromActualViews() async throws {
        let config = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "WudCar", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: config)
        session.disableDialogs = true
        _ = try await session.buyProduct(identifier: SubscriptionStore.productID)
        await SubscriptionStore.shared.refresh()
        XCTAssertTrue(SubscriptionStore.shared.hasAccess)
        let library = MediaLibrary.shared
        let source = try XCTUnwrap(Bundle.main.url(forResource: "intro_day", withExtension: "mp4"))
        let ids = Set(library.items.map(\.id))
        try await library.importFile(source)
        let imported = try XCTUnwrap(library.items.first { !ids.contains($0.id) })
        defer { library.remove(imported.id); PlaybackManager.shared.stop() }
        library.createPlaylist("WudCar demo")
        let list = try XCTUnwrap(library.playlists.last)
        library.setMembers([imported.id], in: list.id)
        defer { library.deletePlaylist(list.id) }
        for (label, size) in [("6.9", CGSize(width: 440, height: 956)), ("6.5", CGSize(width: 428, height: 926))] {
            let item = try XCTUnwrap(imported.playbackItem)
            PlaybackManager.shared.playQueue([item], startingAt: item.url, presentOnPhone: false)
            for _ in 0..<100 where PlaybackManager.shared.player.currentItem?.status != .readyToPlay { try await Task.sleep(for: .milliseconds(50)) }
            XCTAssertEqual(PlaybackManager.shared.player.currentItem?.status, .readyToPlay)
            let views: [(String, AnyView)] = [
                ("01-player", AnyView(PlayerHomeView())),
                ("02-library", AnyView(MediaLibraryView())),
                ("03-tv", AnyView(XtreamHomeView())),
                ("04-subtitles", AnyView(NavigationStack { PlayerOptionsView() })),
                ("05-cast", AnyView(CastView()))
            ]
            for (name, view) in views {
                let host = UIHostingController(rootView: view.environmentObject(AppState.shared))
                let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
                let window = UIWindow(windowScene: scene)
                window.rootViewController = host; window.makeKeyAndVisible()
                host.view.frame = CGRect(origin: .zero, size: size)
                host.view.layoutIfNeeded()
                try await Task.sleep(for: .milliseconds(350))
                let format = UIGraphicsImageRendererFormat(); format.scale = 3
                let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true) }
                XCTAssertEqual(image.cgImage?.width, Int(size.width * 3)); XCTAssertEqual(image.cgImage?.height, Int(size.height * 3))
                let attachment = XCTAttachment(image: image)
                attachment.name = "301-\(label)-\(name)"; attachment.lifetime = .keepAlways; add(attachment)
                window.isHidden = true; window.rootViewController = nil
            }
        }
    }

    func testPublicAppleHLSPlayback() async throws {
        let config = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "WudCar", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: config)
        session.disableDialogs = true
        _ = try await session.buyProduct(identifier: SubscriptionStore.productID)
        await SubscriptionStore.shared.refresh()
        XCTAssertTrue(SubscriptionStore.shared.hasAccess)
        let url = try XCTUnwrap(URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8"))
        let manager = PlaybackManager.shared
        let old = Set(MediaLibrary.shared.items.map(\.id))
        defer {
            manager.stop()
            for item in MediaLibrary.shared.items where !old.contains(item.id) { MediaLibrary.shared.remove(item.id) }
        }
        manager.playQueue([.init(title: "Apple HLS sample", subtitle: "Legal streaming fixture", url: url, isLive: true, artworkURL: nil)], startingAt: url, presentOnPhone: false)
        for _ in 0..<450 where manager.player.currentItem?.status != .readyToPlay && manager.errorMessage == nil { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertEqual(manager.player.currentItem?.status, .readyToPlay, manager.errorMessage ?? "HLS did not become playable")
        for _ in 0..<150 where manager.player.currentTime().seconds < 0.2 { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertGreaterThan(manager.player.currentTime().seconds, 0.1, "Native HLS playback time must actually advance")
    }

    func testImportPlaylistOrderResumeAndRemoval() async throws {
        let library = MediaLibrary.shared
        let original = try XCTUnwrap(Bundle.main.url(forResource: "intro_day", withExtension: "mp4"))
        let previousIDs = Set(library.items.map(\.id))
        try await library.importFile(original)
        try await library.importFile(original)
        let imported = library.items.filter { !previousIDs.contains($0.id) }
        XCTAssertEqual(imported.count, 2)
        defer { for item in imported { library.remove(item.id) } }
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(imported.first?.url).path))
        XCTAssertGreaterThan(try XCTUnwrap(imported.first?.duration), 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: library.thumbnailURL(imported[0].id).path))
        library.createPlaylist("301-test-" + UUID().uuidString)
        let list = try XCTUnwrap(library.playlists.last)
        defer { library.deletePlaylist(list.id) }
        library.setMembers(imported.map(\.id), in: list.id)
        XCTAssertEqual(library.members(list.id).map(\.id), imported.map(\.id))
        library.setMembers(imported.reversed().map(\.id), in: list.id)
        XCTAssertEqual(library.members(list.id).map(\.id), imported.reversed().map(\.id))
        library.renamePlaylist(list.id, name: "renamed")
        library.favoritePlaylist(list.id)
        XCTAssertEqual(library.playlists.first { $0.id == list.id }?.name, "renamed")
        XCTAssertEqual(library.playlists.first { $0.id == list.id }?.favorite, true)
        let url = try XCTUnwrap(imported[0].url)
        library.record(url: url, position: 2.5)
        XCTAssertEqual(library.items.first { $0.id == imported[0].id }?.position, 2.5)
        let data = try Data(contentsOf: MediaLibrary.directory.appendingPathComponent("library.json"))
        let restored = try JSONDecoder().decode([LibraryMedia].self, from: data)
        XCTAssertEqual(restored.first { $0.id == imported[0].id }?.position, 2.5)
        library.remove(imported[0].id)
        XCTAssertFalse(library.members(list.id).contains { $0.id == imported[0].id })
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path), "Original resource must remain untouched")
    }
    func testInvalidImportRollsBack() async throws {
        let bad = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        try Data("invalid movie".utf8).write(to: bad)
        defer { try? FileManager.default.removeItem(at: bad) }
        let before = MediaLibrary.shared.items
        do { try await MediaLibrary.shared.importFile(bad); XCTFail("Unsupported data accepted") } catch {}
        XCTAssertEqual(MediaLibrary.shared.items, before)
    }
    func testSubtitleParsingEncodingAndAppliedPreferences() throws {
        let defaults = UserDefaults.standard
        let keys = ["wd.media.subtitleEncoding", "wd.media.subtitleSize"]
        let previous = keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(keys, previous) { if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) } } }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".srt")
        try "1\n00:00:01,000 --> 00:00:03,000\nHello\n".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        let media = URL(fileURLWithPath: "/test.mp4")
        defaults.set("utf8", forKey: keys[0])
        try ExternalSubtitles.shared.load(file, for: media)
        XCTAssertEqual(ExternalSubtitles.shared.text(at: 2, mediaURL: media), "Hello")
        XCTAssertEqual(ExternalSubtitles.shared.text(at: 4, mediaURL: media), "")
        XCTAssertEqual(ExternalSubtitles.shared.text(at: 2, mediaURL: URL(fileURLWithPath: "/other.mp4")), "")
        defaults.set(125.0, forKey: keys[1])
        let item = AVPlayerItem(url: media)
        let manager = PlaybackManager.shared
        manager.player.replaceCurrentItem(with: item)
        defer { manager.player.replaceCurrentItem(with: nil) }
        manager.applyPreferences()
        XCTAssertFalse(item.textStyleRules?.isEmpty ?? true)
        XCTAssertEqual(item.textStyleRules?.first?.textMarkupAttributes[kCMTextMarkupAttribute_RelativeFontSize as String] as? Double, 125)
    }
    func testSafetyDefaultAndCarTabOrder() {
        let old = UserDefaults.standard.object(forKey: WDKeys.lockVideoWhileDriving)
        defer { if let old { UserDefaults.standard.set(old, forKey: WDKeys.lockVideoWhileDriving) } else { UserDefaults.standard.removeObject(forKey: WDKeys.lockVideoWhileDriving) } }
        UserDefaults.standard.removeObject(forKey: WDKeys.lockVideoWhileDriving)
        XCTAssertTrue(WDSettings.lockVideoWhileDriving)
        let library = CPListTemplate(title: "library", sections: [])
        let tv = CPListTemplate(title: "tv", sections: [])
        let favorites = CPListTemplate(title: "favorites", sections: [])
        let settings = CPListTemplate(title: "settings", sections: [])
        let tabs = CarTemplateUI.makeTabBar(library: library, tv: tv, favorites: favorites, settings: settings)
        XCTAssertTrue(tabs.templates[0] === library)
        XCTAssertTrue(tabs.templates[1] === tv)
        XCTAssertTrue(tabs.templates[2] === favorites)
        XCTAssertTrue(tabs.templates[3] === settings)
    }
}
