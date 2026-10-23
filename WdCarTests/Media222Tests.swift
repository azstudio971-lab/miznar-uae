import XCTest
import SwiftUI
import UIKit
import StoreKitTest
@testable import WdCar

final class Media222Tests: XCTestCase {
    @MainActor func testLibraryAndSettingsRender() throws {
        for language in ["ar", "en"] {
            let old = UserDefaults.standard.object(forKey: WDKeys.language)
            UserDefaults.standard.set(language, forKey: WDKeys.language)
            defer {
                if let old { UserDefaults.standard.set(old, forKey: WDKeys.language) }
                else { UserDefaults.standard.removeObject(forKey: WDKeys.language) }
            }
            for dark in [false, true] {
                for (name, view) in [("library", AnyView(MediaLibraryView())), ("player-settings", AnyView(NavigationStack { MediaSettingsView() }))] {
                    let controller = UIHostingController(rootView: view.environment(\.layoutDirection, language == "ar" ? .rightToLeft : .leftToRight))
                    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
                    let window = UIWindow(windowScene: scene)
                    window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
                    window.overrideUserInterfaceStyle = dark ? .dark : .light
                    window.rootViewController = controller
                    window.makeKeyAndVisible()
                    controller.view.layoutIfNeeded()
                    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
                    let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                        XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
                    }
                    XCTAssertEqual(image.size.width, 390)
                    let pixels = try XCTUnwrap(image.cgImage?.dataProvider?.data)
                    let bytes = try XCTUnwrap(CFDataGetBytePtr(pixels))
                    let samples = stride(from: 0, to: CFDataGetLength(pixels), by: 97).map { bytes[$0] }
                    XCTAssertGreaterThan(Set(samples).count, 8, "A blank rendering is not a valid screenshot")
                    let attachment = XCTAttachment(image: image)
                    attachment.name = "222-\(name)-\(language)-\(dark ? "dark" : "light")"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                    window.isHidden = true
                }
            }
        }
    }

    @MainActor func testImportOfflinePlaybackQueueAndRemovalKeepsOriginal() async throws {
        let config = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "WudCar", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: config)
        session.disableDialogs = true
        session.clearTransactions()
        _ = try await session.buyProduct(identifier: SubscriptionStore.productID)
        await SubscriptionStore.shared.refresh()
        XCTAssertTrue(SubscriptionStore.shared.hasAccess)
        let source = try XCTUnwrap(Bundle.main.url(forResource: "intro_night", withExtension: "mp4"))
        let library = MediaLibrary.shared
        let before = Set(library.items.map(\.id))
        defer {
            PlaybackManager.shared.stop()
            for item in library.items where !before.contains(item.id) { library.remove(item.id) }
        }
        await library.importFiles([source, source])
        let imported = library.items.filter { !before.contains($0.id) }
        XCTAssertEqual(imported.count, 2)
        let first = try XCTUnwrap(imported.first)
        let firstURL = try XCTUnwrap(first.url)
        XCTAssertTrue(firstURL.isFileURL)
        XCTAssertNotEqual(firstURL, source)
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))
        library.toggleFavorite(first.id)
        XCTAssertTrue(library.items.first(where: { $0.id == first.id })?.favorite == true)
        let playback = PlaybackManager.shared
        playback.playQueue(imported.compactMap(\.playbackItem), startingAt: firstURL, presentOnPhone: false)
        let deadline = Date().addingTimeInterval(15)
        while playback.player.currentItem?.status != .readyToPlay && Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(playback.player.currentItem?.status, .readyToPlay)
        playback.savePosition()
        XCTAssertNotNil(library.items.first(where: { $0.id == first.id })?.lastPlayed)
        playback.next()
        XCTAssertEqual(playback.current?.url, imported[1].url)
        playback.previous()
        XCTAssertEqual(playback.current?.url, firstURL)
        playback.stop()
        library.remove(first.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testSRTMultilineAndCommaTimes() {
        let cues = SubtitleParser.parse("1\n00:00:01,250 --> 00:00:03,500\nمرحبا\nWelcome\n\n2\n00:00:04,000 --> 00:00:06,000\nNext\n")
        XCTAssertEqual(cues.count, 2)
        XCTAssertEqual(cues[0].start, 1.25)
        XCTAssertEqual(cues[0].text, "مرحبا\nWelcome")
    }
    func testVTTSettingsAndInvalidCues() {
        let cues = SubtitleParser.parse("WEBVTT\n\n00:01.000 --> 00:02.000 align:center\n<b>Caption</b>\n\n00:03.000 --> 00:02.000\nInvalid\n")
        XCTAssertEqual(cues, [.init(start: 1, end: 2, text: "Caption")])
        XCTAssertNil(SubtitleParser.timestamp("00:99:01"))
        XCTAssertNil(SubtitleParser.timestamp("NaN"))
    }
    func testLibraryMetadataDoesNotPersistNetworkSecrets() throws {
        let item = LibraryMedia(title: "Example", localFilename: nil, favorite: true, position: 12)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(LibraryMedia.self, from: data)
        XCTAssertEqual(decoded, item)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(object["url"])
        XCTAssertNil(object["password"])
    }
    func testExistingM3UParserKeepsGroupsAndRejectsNonHTTPEntries() throws {
        let text = "#EXTM3U\n#EXTINF:-1 group-title=\"News\",Channel\nhttps://example.test/live.m3u8\nfile:///etc/passwd\n"
        let entries = try M3UParser.parse(Data(text.utf8))
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].group, "News")
    }
}
