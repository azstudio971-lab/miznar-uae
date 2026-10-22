import Foundation
import Combine

/// اختصارات المواقع: مشتركة بين الهاتف والسيارة.
/// (تحسين على CarTV: تقدر تضيف أي موقع من الهاتف ويظهر في السيارة مباشرة)
final class ShortcutStore: ObservableObject {
    static let shared = ShortcutStore()

    @Published private(set) var shortcuts: [SiteShortcut] = []
    private let storageKey = "wd.shortcuts.v1"

    private init() {
        let saved = UserDefaults.standard.data(forKey: storageKey)
            .flatMap { try? JSONDecoder().decode([SiteShortcut].self, from: $0) }
        if UserDefaults.standard.bool(forKey: "wd.shortcuts.catalog17") {
            shortcuts = saved ?? ShortcutCatalog.defaults
        } else {
            if let data = UserDefaults.standard.data(forKey: storageKey) {
                UserDefaults.standard.set(data, forKey: "wd.shortcuts.pre17")
            }
            shortcuts = ShortcutCatalog.upgrade(saved ?? [])
            save()
            UserDefaults.standard.set(true, forKey: "wd.shortcuts.catalog17")
        }
    }

    /// يرجع false إذا كان الموقع موجوداً مسبقاً
    @discardableResult
    func add(name: String, url: URL, colorHex: String? = nil, iconURL: URL? = nil) -> Bool {
        let exists = shortcuts.contains { Self.identity($0.url) == Self.identity(url) }
        guard !exists else { return false }
        shortcuts.append(SiteShortcut(name: name, url: url, colorHex: colorHex ?? Self.palette.randomElement() ?? "#2E7D32", iconURL: iconURL))
        save()
        return true
    }

    func update(_ shortcut: SiteShortcut) {
        guard let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }),
              !shortcuts.enumerated().contains(where: { $0.offset != index && Self.identity($0.element.url) == Self.identity(shortcut.url) }) else { return }
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

    private static func identity(_ url: URL) -> String {
        var host = (url.host ?? "").lowercased()
        if host.hasPrefix("www.") { host.removeFirst(4) }
        if host.hasPrefix("m.") { host.removeFirst(2) }
        let path = url.path == "/" ? "" : url.path.lowercased()
        return host + path
    }

    static let palette = ["#2E7D32", "#1565C0", "#6A1B9A", "#C62828", "#EF6C00", "#00838F", "#37474F", "#AD1457"]

    private static var defaults: [SiteShortcut] { ShortcutCatalog.defaults }
}
