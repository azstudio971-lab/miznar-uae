import XCTest
import AVFoundation
import SwiftUI
import VLCKit
@testable import WdCar

@MainActor final class MediaEnhancementTests: XCTestCase {
    func testSoftwareDecoderActuallyPlaysMKVAndStops() async throws {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "software-sample", withExtension: "mkv"))
        let decoder = SoftwareDecoder()
        var elapsed: Double = 0
        var failed = false
        decoder.progress = { at, _, _ in elapsed = at }
        decoder.failure = { failed = true }
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        decoder.player.drawable = view
        defer { decoder.stop() }
        decoder.play(fixture, position: 0)
        for _ in 0..<200 where elapsed < 0.2 && !failed { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertFalse(failed); XCTAssertGreaterThan(elapsed, 0.1, "Decoder time must actually advance for the MKV fixture")
        decoder.stop(); XCTAssertFalse(decoder.player.isPlaying)
        XCTAssertTrue(PlaybackManager.permitsSoftwareDecoding(preference: "auto", external: false, airPlay: false))
        XCTAssertFalse(PlaybackManager.permitsSoftwareDecoding(preference: "never", external: false, airPlay: false))
        XCTAssertFalse(PlaybackManager.permitsSoftwareDecoding(preference: "always", external: true, airPlay: false))
        XCTAssertFalse(PlaybackManager.permitsSoftwareDecoding(preference: "always", external: false, airPlay: true))
    }
    func testFolderImportOrderAndOriginalsRetained() async throws {
        let library = MediaLibrary.shared
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let original = try XCTUnwrap(Bundle.main.url(forResource: "intro_day", withExtension: "mp4"))
        for name in ["B.mp4", "A.mp4"] { try FileManager.default.copyItem(at: original, to: folder.appendingPathComponent(name)) }
        let before = Set(library.items.map(\.id)); let lists = Set(library.playlists.map(\.id))
        defer {
            for media in library.items where !before.contains(media.id) { library.remove(media.id) }
            for list in library.playlists where !lists.contains(list.id) { library.deletePlaylist(list.id) }
        }
        await library.importFolders([folder])
        let imported = library.items.filter { !before.contains($0.id) }
        XCTAssertEqual(imported.map(\.title), ["A", "B"])
        XCTAssertEqual(library.playlists.last?.itemIDs, imported.map(\.id))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("A.mp4").path))
        XCTAssertNotNil(library.importSummary)
    }
    func testQualityParsingAndSubtitleResume() throws {
        let values = HLSQuality.parse("#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1920x1080\nhigh.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=854x480\nlow.m3u8")
        XCTAssertEqual(values.map(\.title), ["480p", "1080p"])
        let media = URL(fileURLWithPath: "/translation-test-" + UUID().uuidString + ".mp4")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".vtt")
        try "WEBVTT\n\n00:01.000 --> 00:03.000\nHello\n".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        let subtitles = ExternalSubtitles.shared
        try subtitles.load(file, for: media)
        let original = subtitles.cues
        subtitles.replaceTranslation([SubtitleCue(start: 1, end: 3, text: "مرحبا")], for: media, original: original)
        subtitles.restore(for: media)
        XCTAssertEqual(subtitles.text(at: 2, mediaURL: media), "مرحبا")
        let item = AVPlayerItem(url: media)
        item.preferredPeakBitRate = values[0].bandwidth
        XCTAssertEqual(item.preferredPeakBitRate, 800000)
    }
    func testNativeHLSPlaybackAdvances() async throws {
        let player = AVPlayer(url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8")!)
        defer { player.pause(); player.replaceCurrentItem(with: nil) }
        player.play()
        for _ in 0..<450 where player.currentTime().seconds < 0.2 && player.currentItem?.status != .failed { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertEqual(player.currentItem?.status, .readyToPlay)
        XCTAssertGreaterThan(player.currentTime().seconds, 0.1)
    }
    func testUnchangedSubscriptionProductAndTrial() throws {
        let file = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "WudCar", withExtension: "storekit"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        let groups = try XCTUnwrap(json["subscriptionGroups"] as? [[String: Any]])
        let products = try XCTUnwrap(groups[0]["subscriptions"] as? [[String: Any]])
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products[0]["productID"] as? String, SubscriptionStore.productID)
        XCTAssertEqual(products[0]["displayPrice"] as? String, "24")
        XCTAssertEqual((products[0]["introductoryOffer"] as? [String: Any])?["subscriptionPeriod"] as? String, "P3D")
    }
    func testNativeSourcesAndCastScreenshots() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let views: [(String, AnyView)] = [("303-sources", AnyView(NavigationStack { SourcesView() })), ("303-add-source", AnyView(NavigationStack { AddSourceView() })), ("303-cast", AnyView(CastView())), ("303-player-settings", AnyView(NavigationStack { PlayerOptionsView() }))]
        for (name, view) in views {
            let host = UIHostingController(rootView: view.environmentObject(AppState.shared))
            let window = UIWindow(windowScene: scene); window.rootViewController = host; window.makeKeyAndVisible()
            host.view.layoutIfNeeded(); try await Task.sleep(for: .milliseconds(400))
            let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true) }
            let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            window.isHidden = true; window.rootViewController = nil
        }
    }
}
