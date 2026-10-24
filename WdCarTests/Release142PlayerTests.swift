import XCTest
import SwiftUI
import AVFoundation
import CarPlay
@testable import WdCar

@MainActor final class Release142PlayerTests: XCTestCase {
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
