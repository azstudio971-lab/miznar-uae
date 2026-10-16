import UIKit
import Combine

/// علامات التبويب لمتصفح واحد (الهاتف أو السيارة) — حد أقصى 8 مثل CarTV.
final class TabStore: ObservableObject {
    static let phone = TabStore(side: .phone)
    static let car = TabStore(side: .car)
    static func of(_ side: BrowserSide) -> TabStore { side == .phone ? phone : car }
    static let maxTabs = 8

    let side: BrowserSide
    @Published private(set) var tabs: [BrowserTab] = []
    @Published private(set) var activeID: UUID?
    @Published private(set) var snapshots: [UUID: UIImage] = [:]

    /// طلب تحميل رابط في تبويب موجود
    let loadRequests = PassthroughSubject<(UUID, URL), Never>()
    /// تبويب أُغلق أو رجع للرئيسية: يجب التخلص من الـ WebView الخاص به
    let discardedSessions = PassthroughSubject<UUID, Never>()

    private var storageKey: String { "wd.tabs.\(side.rawValue).v1" }

    private init(side: BrowserSide) {
        self.side = side
        load()
        if tabs.isEmpty {
            let tab = BrowserTab()
            tabs = [tab]
            activeID = tab.id
        }
        if activeID == nil || !tabs.contains(where: { $0.id == activeID }) {
            activeID = tabs.first?.id
        }
    }

    var activeTab: BrowserTab? { tabs.first { $0.id == activeID } }
    var isFull: Bool { tabs.count >= Self.maxTabs }
    var countText: String { "\(tabs.count) / \(Self.maxTabs)" }

    /// يفتح تبويب جديد. إذا وصلنا للحد الأقصى يُستخدم التبويب الحالي.
    @discardableResult
    func newTab(url: URL? = nil) -> UUID {
        if isFull, let current = activeTab {
            if let url { navigate(current.id, to: url) }
            return current.id
        }
        let tab = BrowserTab(url: url)
        tabs.append(tab)
        activeID = tab.id
        save()
        return tab.id
    }

    func open(_ url: URL, inNewTab: Bool) {
        if inNewTab || activeID == nil {
            newTab(url: url)
        } else if let id = activeID {
            navigate(id, to: url)
        }
    }

    func navigate(_ id: UUID, to url: URL) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].url = url
        tabs[index].title = ""
        activeID = id
        save()
        loadRequests.send((id, url))
    }

    func select(_ id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeID = id
        save()
    }

    func close(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)
        snapshots[id] = nil
        discardedSessions.send(id)
        if tabs.isEmpty { tabs = [BrowserTab()] }
        if activeID == id || !tabs.contains(where: { $0.id == activeID }) {
            activeID = tabs[min(index, tabs.count - 1)].id
        }
        save()
    }

    /// يرجع التبويب لصفحة الاختصارات
    func clear(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].url = nil
        tabs[index].title = ""
        snapshots[id] = nil
        discardedSessions.send(id)
        save()
    }

    func update(_ id: UUID, url: URL?, title: String?) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        var changed = false
        if let url, tabs[index].url != url { tabs[index].url = url; changed = true }
        if let title, !title.isEmpty, tabs[index].title != title { tabs[index].title = title; changed = true }
        if changed { save() }
    }

    func setSnapshot(_ image: UIImage, for id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        snapshots[id] = image
    }

    // MARK: الحفظ

    private struct Persisted: Codable {
        var tabs: [BrowserTab]
        var activeID: UUID?
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Persisted(tabs: tabs, activeID: activeID)) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode(Persisted.self, from: data) else { return }
        tabs = Array(saved.tabs.prefix(Self.maxTabs))
        activeID = saved.activeID
    }
}
