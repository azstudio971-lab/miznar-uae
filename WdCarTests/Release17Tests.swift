import XCTest
import UIKit
@testable import WdCar

@MainActor
final class Release17Tests: XCTestCase {
    private var window: UIWindow?
    override func tearDown() { window?.isHidden = true; window?.rootViewController = nil; window = nil; super.tearDown() }
    private func show(_ controller: UIViewController, size: CGSize) {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let w = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: CGRect(origin: .zero, size: size))
        w.rootViewController = controller; w.makeKeyAndVisible(); window = w
        controller.view.frame = CGRect(origin: .zero, size: size); controller.view.layoutIfNeeded()
    }
    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants($0) } }
    private func snapshot(_ view: UIView, name: String) {
        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { view.layer.render(in: $0.cgContext) }
        let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testCatalogOrderAndLosslessLegacyUpgrade() throws {
        let expected = ["YouTube", "YouTube Music", "YouTube Kids", "Google Search", "Alawi TV", "MP3Quran", "Shahid", "TikTok", "Instagram", "TOD", "SoundCloud", "UAE Weather", "Spotify", "Apple TV", "Radio Garden", "Dailymotion", "Vimeo", "Twitch", "STARZPLAY", "Dubai+", "Awaan", "Filmzie", "Spacetoon GO", "PBS Kids", "CrazyGames", "Windows XP Simulator", "Outlook", "Gmail", "ChatGPT"]
        XCTAssertEqual(ShortcutCatalog.defaults.map(\.name), expected)
        XCTAssertEqual(Set(ShortcutCatalog.defaults.map { ShortcutCatalog.identity($0.url) }).count, 29)
        let legacy = ShortcutCatalog.legacy.map { SiteShortcut(name: $0.0, url: URL(string: $0.1)!, colorHex: $0.2) }
        let custom = SiteShortcut(name: "My Netflix", url: URL(string: "https://netflix.com/my-list")!, colorHex: "#123456", iconURL: URL(string: "https://example.com/custom.png"))
        let edited = SiteShortcut(name: "My YouTube", url: URL(string: "https://www.youtube.com")!, colorHex: "#AB1234")
        let saved = legacy.filter { !$0.url.absoluteString.contains("youtube.com") } + [custom, edited]
        let upgraded = ShortcutCatalog.upgrade(saved)
        XCTAssertEqual(upgraded.count, 30)
        XCTAssertEqual(upgraded.first, edited)
        XCTAssertEqual(upgraded.last, custom)
        XCTAssertFalse(upgraded.contains { $0.name == "Netflix – نتفليكس" || $0.name == "Prime Video – برايم فيديو" })
        for index in [4, 9, 10, 25, 26] {
            let seed = ShortcutCatalog.defaults[index]
            let previous = try XCTUnwrap(legacy.first { ShortcutCatalog.identity($0.url) == ShortcutCatalog.identity(seed.url) })
            XCTAssertEqual(upgraded[index].id, previous.id)
            XCTAssertEqual(upgraded[index].url, previous.url)
        }
        let specialLink = SiteShortcut(name: "My channel", url: URL(string: "https://www.tod.tv/ar/custom")!, colorHex: "#123456")
        let preserved = ShortcutCatalog.upgrade([specialLink])
        XCTAssertEqual(preserved[9], specialLink)
        XCTAssertEqual(preserved.count, 29)
        XCTAssertEqual(try JSONDecoder().decode([SiteShortcut].self, from: JSONEncoder().encode(upgraded)), upgraded)
    }
    func testGridCardsScrollAndCustomCardMatchesAtAllSizes() async throws {
        let saved = UserDefaults.standard.data(forKey: "wd.shortcuts.v1")
        let migration = UserDefaults.standard.object(forKey: "wd.shortcuts.catalog17")
        defer {
            UserDefaults.standard.set(saved, forKey: "wd.shortcuts.v1")
            UserDefaults.standard.set(migration, forKey: "wd.shortcuts.catalog17")
        }
        let store = ShortcutStore.shared
        let customURL = URL(string: "https://example.com/build17/\(UUID())")!
        XCTAssertTrue(store.add(name: "Custom favorite", url: customURL, colorHex: "#133A50"))
        let custom = try XCTUnwrap(store.shortcuts.first { $0.url == customURL })
        defer { store.remove(custom.id) }
        for size in [CGSize(width: 1280, height: 480), CGSize(width: 960, height: 480), CGSize(width: 640, height: 640), CGSize(width: 640, height: 360), CGSize(width: 320, height: 240)] {
            let vc = UIViewController(); let grid = CarShortcutsView(frame: .zero); vc.view = grid
            show(vc, size: size)
            try await Task.sleep(nanoseconds: 600_000_000)
            grid.layoutIfNeeded()
            let collection = try XCTUnwrap(descendants(grid).compactMap { $0 as? UICollectionView }.first)
            collection.layoutIfNeeded()
            let metrics = CarShortcutsView.gridMetrics(for: size)
            if size.width >= 960 { XCTAssertEqual(metrics.columns, 8) }
            if size.width == 640 { XCTAssertEqual(metrics.columns, 5) }
            XCTAssertGreaterThan(metrics.item.width, metrics.item.height)
            XCTAssertLessThanOrEqual(collection.contentSize.width, collection.bounds.width + 1)
            for cell in collection.visibleCells {
                XCTAssertFalse(cell.hasAmbiguousLayout)
                XCTAssertEqual(cell.bounds.width / cell.bounds.height, 1.55, accuracy: 0.01)
                for image in descendants(cell).compactMap({ $0 as? UIImageView }) { XCTAssertEqual(image.contentMode, .scaleAspectFit) }
            }
            snapshot(grid, name: "17-grid-\(Int(size.width))x\(Int(size.height))")
            let index = try XCTUnwrap(store.shortcuts.firstIndex { $0.id == custom.id })
            collection.scrollToItem(at: IndexPath(item: index, section: 0), at: .bottom, animated: false)
            collection.layoutIfNeeded()
            let cell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: index, section: 0)))
            XCTAssertEqual(cell.bounds.size, metrics.item)
            snapshot(grid, name: "17-grid-custom-\(Int(size.width))")
            var selected: SiteShortcut?
            grid.onSelect = { selected = $0 }
            let point = grid.convert(cell.center, from: collection)
            XCTAssertTrue(grid.activateShortcut(at: point)); XCTAssertEqual(selected?.id, custom.id)
        }
    }
    func testToolbarSymbolsFitInArabicAndEnglishAtAllSizes() async throws {
        for direction in [UISemanticContentAttribute.forceRightToLeft, .forceLeftToRight] {
            for size in [CGSize(width: 320, height: 240), CGSize(width: 640, height: 360), CGSize(width: 960, height: 480), CGSize(width: 640, height: 640)] {
                let vc = CarBrowserViewController(); show(vc, size: size)
                vc.view.semanticContentAttribute = direction
                let views = descendants(vc.view)
                let hotspot = try XCTUnwrap(views.first { $0.accessibilityIdentifier == "car.browser.toolbar.hotspot" } as? UIButton)
                hotspot.sendActions(for: .primaryActionTriggered)
                let reveal = try XCTUnwrap(views.first { $0.accessibilityIdentifier == "car.browser.toolbar.reveal" } as? UIButton)
                reveal.sendActions(for: .primaryActionTriggered)
                vc.view.setNeedsLayout(); vc.view.layoutIfNeeded()
                let toolbar = try XCTUnwrap(views.first { $0.accessibilityIdentifier == "car.browser.toolbar" } as? UIStackView)
                XCTAssertFalse(toolbar.isHidden)
                XCTAssertEqual(toolbar.bounds.height, 20)
                let buttons = toolbar.arrangedSubviews.compactMap { $0 as? CompactToolbarButton }
                XCTAssertEqual(buttons.count, 5)
                for button in buttons {
                    button.layoutIfNeeded()
                    let symbol = button.symbolView
                    XCTAssertEqual(symbol.bounds.size, CGSize(width: 12, height: 12))
                    let frame = button.convert(symbol.bounds, from: symbol)
                    XCTAssertTrue(button.bounds.insetBy(dx: 3, dy: 2).contains(frame), "Symbol must fit inside visible capsule")
                    XCTAssertEqual(frame.midY, button.bounds.midY, accuracy: 0.5)
                    XCTAssertGreaterThanOrEqual(button.bounds.width, 44)
                    XCTAssertTrue(toolbar.bounds.contains(button.frame))
                }
                try await Task.sleep(nanoseconds: 250_000_000)
                snapshot(vc.view, name: "17-toolbar-\(direction.rawValue)-\(Int(size.width))x\(Int(size.height))")
            }
        }
    }
}
