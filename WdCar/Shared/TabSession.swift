import UIKit
import WebKit
import Combine

/// جلسة تصفح لتبويب واحد: تملك الـ WKWebView وتنقل حالته للواجهة.
final class TabSession: NSObject, ObservableObject {
    let tabID: UUID
    let side: BrowserSide
    let webView: WKWebView

    @Published private(set) var canGoBack = false
    @Published private(set) var isLoading = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var isVideoFullscreen = false
    @Published private(set) var videoStatus = VideoStatus()
    @Published private(set) var isDesktopMode: Bool
    @Published private(set) var navigationError: String?

    /// المستخدم ضغط على حقل كتابة في صفحة السيارة
    let focusEvents = PassthroughSubject<FocusInfo, Never>()

    private var observations: [NSKeyValueObservation] = []
    private var didTryYouTubeDesktopRedirect = false
    private var store: TabStore { TabStore.of(side) }

    init(tabID: UUID, side: BrowserSide, initialURL: URL?) {
        self.tabID = tabID
        self.side = side
        let desktop = (side == .car) ? WDSettings.carDesktopMode : WDSettings.phoneDesktopMode
        self._isDesktopMode = Published(initialValue: desktop)

        let configuration = WebEngine.makeConfiguration(for: side)
        self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 480), configuration: configuration)
        super.init()

        webView.configuration.userContentController.add(WeakScriptHandler(self), name: WebEngine.messageName)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = desktop ? WebEngine.desktopUserAgent : nil
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        if side == .car {
            // Use the single app-owned pair on the left, without WebKit scroll indicators.
            webView.scrollView.showsVerticalScrollIndicator = false
            webView.scrollView.showsHorizontalScrollIndicator = false
        }
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        if side == .car { webView.pageZoom = CGFloat(WDSettings.carZoom) }

        observe()
        if let initialURL { load(initialURL) }
    }

    // MARK: التنقل

    func load(_ url: URL) {
        navigationError = nil
        didTryYouTubeDesktopRedirect = false
        webView.load(URLRequest(url: requestedURL(url)))
    }

    private func requestedURL(_ url: URL) -> URL {
        guard let host = url.host?.lowercased(),
              ["youtube.com", "www.youtube.com", "m.youtube.com"].contains(host),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.host = isDesktopMode ? "www.youtube.com" : "m.youtube.com"
        var query = (components.queryItems ?? []).filter { !["app", "persist_app"].contains($0.name) }
        if isDesktopMode {
            query += [URLQueryItem(name: "app", value: "desktop"), URLQueryItem(name: "persist_app", value: "1")]
        }
        components.queryItems = query.isEmpty ? nil : query
        return components.url ?? url
    }
    func reload() { webView.reload() }
    func stopLoading() { webView.stopLoading() }
    func goBack() { webView.goBack() }

    func adjustZoom(by delta: CGFloat) {
        webView.pageZoom = min(2.0, max(0.5, webView.pageZoom + delta))
    }

    func resetZoom() { webView.pageZoom = 1.0 }

    func applyCarZoom(_ zoom: Double) {
        let clamped = min(1.5, max(0.5, zoom))
        if side == .car { WDSettings.carZoom = clamped }
        webView.pageZoom = CGFloat(clamped)
        applyCarLayout()
    }

    func applyCarLayout() {
        guard side == .car else { return }
        run("window.__wdNativePageZoom = \(Double(webView.pageZoom)); window.__wdApplyCarLayout && window.__wdApplyCarLayout();")
    }

    func setDesktopMode(_ on: Bool) {
        isDesktopMode = on
        webView.customUserAgent = on ? WebEngine.desktopUserAgent : nil
        webView.configuration.defaultWebpagePreferences.preferredContentMode = on ? .desktop : .mobile
        if let url = webView.url { load(url) } else { webView.reload() }
    }

    // MARK: جسر الكتابة (السيارة)

    func setInputText(_ text: String) {
        run("window.__wdSetText && window.__wdSetText(\(WebEngine.jsLiteral(text)));")
    }

    func submitInput() { run("window.__wdSubmit && window.__wdSubmit();") }
    func blurInput() { run("window.__wdBlur && window.__wdBlur();") }

    /// Used only by WudCar's phone-side touchpad for its own WebView.
    func runMouseJavaScript(_ script: String) { run(script) }

    // MARK: الفيديو (السيارة)

    func enterVideoFullscreen(completion: @escaping (Bool) -> Void) {
        webView.evaluateJavaScript("window.__wdEnterFS ? window.__wdEnterFS() : false") { result, _ in
            completion((result as? Bool) ?? false)
        }
    }

    func exitVideoFullscreen() { run("window.__wdExitFS && window.__wdExitFS();") }
    func setVideoFit(_ fit: VideoFit) { run("window.__wdSetFit && window.__wdSetFit('\(fit.rawValue)');") }
    func togglePlay() { run("window.__wdTogglePlay && window.__wdTogglePlay();") }
    func seek(by seconds: Double) { run("window.__wdSeek && window.__wdSeek(\(seconds));") }
    func seek(toFraction fraction: Double) { run("window.__wdSeekTo && window.__wdSeekTo(\(fraction));") }
    func pauseMedia() { webView.pauseAllMediaPlayback(completionHandler: nil) }

    // MARK: الصورة المصغرة للتبويب

    func takeSnapshot() {
        guard webView.window != nil, webView.bounds.width > 1, webView.bounds.height > 1 else { return }
        let configuration = WKSnapshotConfiguration()
        configuration.snapshotWidth = 480
        webView.takeSnapshot(with: configuration) { [weak self] image, _ in
            guard let self, let image else { return }
            self.store.setSnapshot(image, for: self.tabID)
        }
    }

    func tearDown() {
        observations.removeAll()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: WebEngine.messageName)
        webView.stopLoading()
        webView.pauseAllMediaPlayback(completionHandler: nil)
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.removeFromSuperview()
    }

    // MARK: - داخلي

    private func run(_ js: String) {
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func onMain(_ block: @escaping (TabSession) -> Void) {
        if Thread.isMainThread {
            block(self)
        } else {
            DispatchQueue.main.async { [weak self] in
                if let self { block(self) }
            }
        }
    }

    private func observe() {
        observations = [
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] web, _ in
                self?.onMain { $0.canGoBack = web.canGoBack }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] web, _ in
                self?.onMain { $0.isLoading = web.isLoading }
            },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] web, _ in
                self?.onMain { $0.progress = web.estimatedProgress }
            },
            webView.observe(\.url, options: [.new]) { [weak self] web, _ in
                guard let url = web.url else { return }
                self?.onMain { $0.store.update($0.tabID, url: url, title: nil) }
            },
            webView.observe(\.title, options: [.new]) { [weak self] web, _ in
                let title = web.title
                self?.onMain { $0.store.update($0.tabID, url: nil, title: title) }
            }
        ]
    }
}

// MARK: - رسائل JavaScript

extension TabSession: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "fullscreen":
            isVideoFullscreen = (body["on"] as? Bool) ?? false
            if !isVideoFullscreen { videoStatus = VideoStatus() }
        case "time":
            videoStatus = VideoStatus(
                current: (body["t"] as? NSNumber)?.doubleValue ?? 0,
                duration: (body["d"] as? NSNumber)?.doubleValue ?? 0,
                playing: (body["p"] as? Bool) ?? false
            )
        case "mediaError":
            navigationError = carTr("تعذّر تشغيل هذا الفيديو داخل المتصفح المضمّن. قد يتطلب اشتراكاً أو تطبيق الموقع الرسمي، أو يستخدم صيغة غير مدعومة.",
                                    "This video could not play in the embedded browser. It may require a subscription or the official app, or use an unsupported format.")
        case "focus":
            focusEvents.send(FocusInfo(
                value: body["value"] as? String ?? "",
                placeholder: body["placeholder"] as? String ?? ""
            ))
        default:
            break
        }
    }
}

// MARK: - التنقل والنوافذ المنبثقة

extension TabSession: WKNavigationDelegate, WKUIDelegate {

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 preferences: WKWebpagePreferences,
                 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        preferences.preferredContentMode = isDesktopMode ? .desktop : .mobile

        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else {
            decisionHandler(.allow, preferences)
            return
        }
        if isDesktopMode, navigationAction.targetFrame?.isMainFrame == true, url.host?.lowercased() == "m.youtube.com",
           !didTryYouTubeDesktopRedirect {
            didTryYouTubeDesktopRedirect = true
            decisionHandler(.cancel, preferences)
            webView.load(URLRequest(url: requestedURL(url)))
            return
        }
        let webSchemes: Set<String> = ["http", "https", "about", "blob", "data", "file", "javascript"]
        if webSchemes.contains(scheme) {
            decisionHandler(.allow, preferences)
        } else {
            // روابط التطبيقات (itms-apps, intent ...) تفتح على الهاتف فقط
            decisionHandler(.cancel, preferences)
            if side == .phone { UIApplication.shared.open(url) }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationError = nil
        if side == .car { applyCarLayout() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.takeSnapshot()
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        navigationError = carTr("تعذّر تحميل هذا الموقع. قد يمنع الموقع التصفح المضمّن أو يتطلب تسجيل الدخول. جرّب فتحه في Safari أو تطبيقه الرسمي.",
                                "This site could not load. It may block embedded browsing or require sign-in. Try Safari or its official app.")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationError = carTr("توقف تحميل الصفحة. تحقق من الاتصال أو افتح الموقع في Safari أو تطبيقه الرسمي.",
                                "The page stopped loading. Check the connection, or try Safari or its official app.")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        navigationError = carTr("توقف الموقع عن الاستجابة. أعد تحميل الصفحة.", "The website stopped responding. Reload the page.")
        webView.reload()
    }

    /// الروابط التي تفتح نافذة جديدة (target=_blank) تفتح في نفس التبويب
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == false {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
}
