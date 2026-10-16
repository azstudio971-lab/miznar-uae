import Foundation
import Combine

/// اختصارات المواقع: مشتركة بين الهاتف والسيارة.
/// (تحسين على CarTV: تقدر تضيف أي موقع من الهاتف ويظهر في السيارة مباشرة)
final class ShortcutStore: ObservableObject {
    static let shared = ShortcutStore()

    @Published private(set) var shortcuts: [SiteShortcut] = []
    private let storageKey = "wd.shortcuts.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([SiteShortcut].self, from: data) {
            shortcuts = saved
        } else {
            shortcuts = Self.defaults
        }
    }

    /// يرجع false إذا كان الموقع موجوداً مسبقاً
    @discardableResult
    func add(name: String, url: URL, colorHex: String? = nil) -> Bool {
        let exists = shortcuts.contains { $0.url.host == url.host && $0.url.path == url.path }
        guard !exists else { return false }
        shortcuts.append(SiteShortcut(name: name, url: url, colorHex: colorHex ?? Self.palette.randomElement() ?? "#2E7D32"))
        save()
        return true
    }

    func update(_ shortcut: SiteShortcut) {
        guard let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else { return }
        shortcuts[index] = shortcut
        save()
    }

    func remove(_ id: UUID) {
        shortcuts.removeAll { $0.id == id }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        let moving = source.map { shortcuts[$0] }
        var remaining = shortcuts.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let insertAt = destination - source.filter { $0 < destination }.count
        remaining.insert(contentsOf: moving, at: max(0, min(insertAt, remaining.count)))
        shortcuts = remaining
        save()
    }

    func resetToDefaults() {
        shortcuts = Self.defaults
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    static let palette = ["#2E7D32", "#1565C0", "#6A1B9A", "#C62828", "#EF6C00", "#00838F", "#37474F", "#AD1457"]

    private static var defaults: [SiteShortcut] {
        let list: [(String, String, String)] = [
            ("YouTube", "https://www.youtube.com", "#FF0000"),
            ("TikTok", "https://www.tiktok.com", "#111111"),
            ("Google", "https://www.google.com", "#FFFFFF"),
            ("شاهد", "https://shahid.mbc.net", "#1E1E1E"),
            ("Instagram", "https://www.instagram.com", "#E1306C"),
            ("Twitch", "https://www.twitch.tv", "#9146FF"),
            ("Vimeo", "https://vimeo.com", "#1AB7EA"),
            ("Dailymotion", "https://www.dailymotion.com", "#0066DC"),
            ("Pluto TV", "https://pluto.tv", "#2D2D8F"),
            ("Tubi", "https://tubitv.com", "#7408FF"),
            ("Plex", "https://app.plex.tv", "#E5A00D"),
            ("Crunchyroll", "https://www.crunchyroll.com", "#F47521")
        ]
        return list.compactMap { name, link, color in
            URL(string: link).map { SiteShortcut(name: name, url: $0, colorHex: color) }
        }
    }
}
