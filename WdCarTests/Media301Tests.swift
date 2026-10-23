import XCTest
import AVFoundation
import CoreMedia
import SwiftUI
@testable import WdCar

@MainActor
final class Media301Tests: XCTestCase {
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
        XCTAssertEqual(CarTemplateUI.tabOrder, ["library", "tv", "favorites", "settings"])
    }
}
