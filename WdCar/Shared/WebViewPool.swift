import Foundation
import Combine

/// يحتفظ بجلسة WebView لكل تبويب، لكل جهة (الهاتف/السيارة) على حدة.
final class WebViewPool {
    static let phone = WebViewPool(side: .phone)
    static let car = WebViewPool(side: .car)
    static func of(_ side: BrowserSide) -> WebViewPool { side == .phone ? phone : car }

    let side: BrowserSide
    private var sessions: [UUID: TabSession] = [:]
    private var bag = Set<AnyCancellable>()

    private init(side: BrowserSide) {
        self.side = side
        let store = TabStore.of(side)
        // إذا كانت الجلسة غير موجودة بعد، ستُحمّل الرابط عند إنشائها
        store.loadRequests
            .sink { [weak self] id, url in self?.sessions[id]?.load(url) }
            .store(in: &bag)
        store.discardedSessions
            .sink { [weak self] id in self?.discard(id) }
            .store(in: &bag)
    }

    func session(for id: UUID) -> TabSession {
        if let existing = sessions[id] { return existing }
        let tab = TabStore.of(side).tabs.first { $0.id == id }
        let session = TabSession(tabID: id, side: side, initialURL: tab?.url)
        sessions[id] = session
        return session
    }

    func existingSession(for id: UUID) -> TabSession? { sessions[id] }

    func discard(_ id: UUID) {
        sessions[id]?.tearDown()
        sessions[id] = nil
    }

    func pauseAllMedia() {
        sessions.values.forEach { $0.pauseMedia() }
    }

    func applyZoom(_ zoom: Double) {
        sessions.values.forEach { $0.webView.pageZoom = CGFloat(min(1.5, max(0.5, zoom))) }
    }

    func applyDesktopMode(_ enabled: Bool) {
        sessions.values.forEach { $0.setDesktopMode(enabled) }
    }
}
