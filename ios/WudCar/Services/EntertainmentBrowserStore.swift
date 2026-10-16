import Combine
import SwiftUI
import WebKit

@MainActor final class EntertainmentBrowserTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate {
    let id = UUID()
    let webView: WKWebView
    @Published private(set) var address = ""
    @Published private(set) var title = ""
    @Published private(set) var loading = false
    @Published private(set) var progress = 0.0
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published var error: String?
    @Published private(set) var showingHome = true
    @Published private(set) var desktop = false
    @Published private(set) var zoom = 1.0
    @Published private(set) var thumbnail: UIImage?
    private var observations: [NSKeyValueObservation] = []
    var createTab: ((WKWebViewConfiguration) -> EntertainmentBrowserTab?)?
    var closeTab: (() -> Void)?

    init(configuration: WKWebViewConfiguration? = nil) {
        let config = configuration ?? WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        // User-initiated playback; no hidden/background autoplay or provider bypass.
        config.mediaTypesRequiringUserActionForPlayback = .all
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        if configuration == nil { config.websiteDataStore = .default() }
        #if DEBUG
        if configuration == nil && AppConfiguration.browserUITesting {
            config.setURLSchemeHandler(BrowserTestFixtures(), forURLScheme: "wudcar-test")
        }
        #endif
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        observations = [
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
            webView.observe(\.title, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
            webView.observe(\.isLoading, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() }
        ]
    }

    private nonisolated func scheduleUpdate() {
        Task { @MainActor [weak self] in self?.update() }
    }

    private func update() {
        address = showingHome ? "" : (webView.url?.absoluteString ?? address)
        title = showingHome ? "" : (webView.title ?? "")
        loading = !showingHome && webView.isLoading
        progress = webView.estimatedProgress
        canGoBack = !showingHome && webView.canGoBack
        canGoForward = !showingHome && webView.canGoForward
    }

    func open(_ input: String) {
        guard let url = BrowserPolicy.destination(for: input) else {
            error = AppState.shared.text("أدخل رابط HTTPS صالحًا أو كلمات للبحث.", "Enter a valid HTTPS URL or search terms.")
            return
        }
        error = nil
        thumbnail = nil
        showingHome = false
        address = url.absoluteString
        webView.setAllMediaPlaybackSuspended(false, completionHandler: nil)
        webView.load(URLRequest(url: url))
    }

    #if DEBUG
    func openTestFixture() {
        guard AppConfiguration.browserUITesting else { return }
        showingHome = false
        webView.load(URLRequest(url: URL(string: "wudcar-test://fixture/one")!))
    }
    #endif

    private func permits(_ url: URL) -> Bool {
        #if DEBUG
        if AppConfiguration.browserUITesting && url.scheme == "wudcar-test" { return true }
        #endif
        return BrowserPolicy.websiteURL(url.absoluteString) != nil || url.absoluteString == "about:blank"
    }

    func home() {
        webView.stopLoading()
        suspend()
        showingHome = true
        error = nil
        thumbnail = nil
        update()
    }

    func suspend() {
        webView.pauseAllMediaPlayback(completionHandler: nil)
        webView.setAllMediaPlaybackSuspended(true, completionHandler: nil)
    }

    func activate() {
        if !showingHome { webView.setAllMediaPlaybackSuspended(false, completionHandler: nil) }
    }

    func reload() {
        error = nil
        if webView.url != nil { webView.reload() }
        else if !address.isEmpty { open(address) }
    }

    func setDesktop(_ enabled: Bool) {
        desktop = enabled
        if !showingHome { reload() }
    }

    func setZoom(_ value: Double) {
        zoom = BrowserPolicy.zoom(value)
        webView.pageZoom = zoom
    }

    func captureThumbnail() {
        guard !showingHome, !webView.bounds.isEmpty else { return }
        let config = WKSnapshotConfiguration()
        config.snapshotWidth = 320
        webView.takeSnapshot(with: config) { [weak self] image, _ in
            Task { @MainActor in self?.thumbnail = image }
        }
    }

    func dispose() {
        suspend()
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        observations.removeAll()
        createTab = nil
        closeTab = nil
        thumbnail = nil
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { update() }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { error = nil; update() }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { update() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error) }
    private func failed(_ failure: Error) {
        update()
        if (failure as NSError).code != NSURLErrorCancelled {
            // Do not put full URLs or website credentials into errors or logs.
            error = AppState.shared.text("تعذّر تحميل الصفحة. تحقق من الاتصال وأعد المحاولة.", "Could not load this page. Check your connection and try again.")
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        error = AppState.shared.text("توقفت الصفحة. اضغط إعادة المحاولة لإعادة تحميلها.", "The page stopped. Tap Retry to reload it.")
        update()
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        preferences.preferredContentMode = desktop ? .desktop : .mobile
        guard let url = action.request.url else { decisionHandler(.cancel, preferences); return }
        // about:blank is needed by WebKit popup windows. Subframe blob documents
        // are allowed; this does not extract, rewrite or download video streams.
        if permits(url) ||
            (action.targetFrame?.isMainFrame == false && url.scheme == "blob") {
            decisionHandler(.allow, preferences)
        } else {
            if action.targetFrame?.isMainFrame != false {
                error = AppState.shared.text("هذا الرابط لا يفتح داخل المتصفح. استخدم رابط الموقع الآمن.", "This link cannot open here. Use the secure website link.")
            }
            decisionHandler(.cancel, preferences)
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard action.targetFrame == nil, let url = action.request.url,
              permits(url) else { return nil }
        guard let tab = createTab?(configuration) else {
            error = AppState.shared.text("الحد الأقصى ٨ تبويبات. أغلق تبويبًا ثم أعد المحاولة.", "Maximum 8 tabs. Close one and try again.")
            return nil
        }
        tab.showingHome = false
        tab.desktop = desktop
        // WebKit performs the original request in the returned view, preserving POST and opener.
        return tab.webView
    }

    func webViewDidClose(_ webView: WKWebView) { closeTab?() }
}

@MainActor final class EntertainmentBrowserStore: ObservableObject {
    static let shared = EntertainmentBrowserStore()
    @Published private(set) var tabs: [EntertainmentBrowserTab] = []
    @Published private(set) var selectedID: UUID?
    var selected: EntertainmentBrowserTab { tabs.first { $0.id == selectedID } ?? tabs[0] }

    init() { _ = addTab() }

    @discardableResult func addTab(configuration: WKWebViewConfiguration? = nil) -> EntertainmentBrowserTab? {
        guard BrowserPolicy.canAddTab(count: tabs.count) else { return nil }
        let tab = EntertainmentBrowserTab(configuration: configuration)
        tab.createTab = { [weak self] config in self?.addTab(configuration: config) }
        tab.closeTab = { [weak self, weak tab] in if let tab { self?.close(tab.id) } }
        tabs.append(tab)
        select(tab.id)
        return tab
    }

    func select(_ id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        for tab in tabs where tab.id != id { tab.suspend() }
        selectedID = id
        selected.activate()
    }

    func close(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].dispose()
        tabs.remove(at: index)
        if tabs.isEmpty { _ = addTab() }
        else if selectedID == id { select(tabs[min(index, tabs.count - 1)].id) }
    }

    func suspendAll() { tabs.forEach { $0.suspend() } }

    func reset() {
        tabs.forEach { $0.dispose() }
        tabs = []
        selectedID = nil
        _ = addTab()
    }

    func clearWebsiteData() async {
        reset()
        await WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
    }
}
