import SwiftUI
import AVKit
import WebKit

struct MediaView: View {
    @EnvironmentObject private var state: AppState
    @State private var browserSource: MediaSource?
    @State private var editing: MediaSource?
    @State private var input = ""
    @AppStorage("wudcar.v3.shortcuts.seeded") private var seeded = false
    private var shortcuts: [MediaSource] { state.sources.filter { $0.type == "website" } }
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    TextField(state.text("رابط أو بحث", "URL or search"), text: $input)
                        .keyboardType(.webSearch).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder).submitLabel(.go).onSubmit { browse() }
                    Button { browse() } label: { Image(systemName: "arrow.right.circle.fill") }
                        .accessibilityLabel(state.text("فتح", "Go"))
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 20) {
                    ForEach(shortcuts) { source in
                        Button { browserSource = source } label: {
                            VStack(spacing: 10) {
                                WebsiteShortcutIcon(source: source).frame(width: 64, height: 64)
                                Text(source.name).lineLimit(2).foregroundStyle(.primary)
                            }.frame(maxWidth: .infinity, minHeight: 100)
                        }.buttonStyle(.plain)
                        .contextMenu {
                            Button(state.text("تعديل", "Edit")) { editing = source }
                            Button(state.text("حذف", "Delete"), role: .destructive) {
                                state.sources.removeAll { $0.id == source.id }
                            }
                        }
                    }
                }
                Button {
                    editing = MediaSource(name: "", url: "", type: "website", mediaKind: "video")
                } label: { Label(state.text("إضافة موقع", "Add website"), systemImage: "plus") }
                    .buttonStyle(.borderedProminent)
            }.padding()
        }
        .navigationTitle(state.text("الترفيه", "Entertainment"))
        .fullScreenCover(item: $browserSource) { source in EntertainmentBrowser(initialURL: source.url) }
        .sheet(item: $editing) { source in WebsiteShortcutEditor(source: source) }
        .onAppear {
            guard !seeded else { return }
            for source in [
                MediaSource(id: "wudcar-youtube", name: "YouTube", url: "https://www.youtube.com", type: "website", mediaKind: "video"),
                MediaSource(id: "wudcar-shahid", name: "Shahid", url: "https://shahid.mbc.net", type: "website", mediaKind: "video")
            ] where !shortcuts.contains(where: { URL(string: $0.url)?.host == URL(string: source.url)?.host }) {
                state.sources.append(source)
            }
            seeded = true
        }
    }
    private func browse() {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        browserSource = MediaSource(name: "", url: value, type: "website", mediaKind: "video")
    }
}

struct WebsiteShortcutIcon: View {
    let source: MediaSource
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.04, green: 0.30, blue: 0.36))
            if let value = source.iconURL, let url = WudDomain.validURL(value) {
                AsyncImage(url: url) { image in image.resizable().scaledToFit() }
                    placeholder: { Image(systemName: "globe").font(.title).foregroundStyle(.white) }
                    .padding(8)
            } else {
                Text(String(source.name.prefix(2))).font(.title2.bold()).foregroundStyle(.white)
            }
        }.clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct WebsiteShortcutEditor: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State var source: MediaSource
    @State private var icon = ""
    var body: some View {
        NavigationStack {
            Form {
                TextField(state.text("الاسم", "Name"), text: $source.name)
                TextField("https://", text: $source.url)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField(state.text("رابط صورة الأيقونة — اختياري", "Icon image URL — optional"), text: $icon)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text(state.text("استخدم رابط HTTPS مباشرًا لصورة الأيقونة.",
                                "Use a direct HTTPS image URL for your icon."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle(state.text("اختصار موقع", "Website shortcut"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(state.text("إلغاء", "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(state.text("حفظ", "Save")) {
                        guard let url = WudDomain.validURL(source.url) else { return }
                        source.name = String(source.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
                        source.url = url.absoluteString
                        source.iconURL = icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : WudDomain.validURL(icon)?.absoluteString
                        if let index = state.sources.firstIndex(where: { $0.id == source.id }) { state.sources[index] = source }
                        else { state.sources.append(source) }
                        dismiss()
                    }.disabled(source.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                               WudDomain.validURL(source.url) == nil ||
                               (!icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && WudDomain.validURL(icon) == nil))
                }
            }
            .onAppear { icon = source.iconURL ?? "" }
        }
    }
}

// This browser is an iPhone/iPad view. It does not grant a CarPlay browser entitlement.
@MainActor final class EntertainmentWebSession: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    @Published var address = ""
    @Published var title = ""
    @Published var loading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var error: String?
    @Published var showingHome = true

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
    }

    func open(_ text: String) {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        let url: URL?
        if input.contains("://") {
            url = WudDomain.validURL(input)
        } else if !input.contains(where: { $0.isWhitespace }), input.contains(".") {
            url = WudDomain.validURL("https://" + input)
        } else {
            var components = URLComponents(string: "https://www.google.com/search")
            components?.queryItems = [URLQueryItem(name: "q", value: input)]
            url = components?.url
        }
        guard let url else { error = AppState.shared.text("أدخل رابط HTTPS صالحًا.", "Enter a valid HTTPS URL."); return }
        error = nil
        showingHome = false
        webView.load(URLRequest(url: url))
    }

    private func update() {
        address = webView.url?.absoluteString ?? address
        title = webView.title ?? ""
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        loading = webView.isLoading
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { error = nil; update() }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { update() }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { update() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error) }
    private func failed(_ value: Error) {
        update()
        if (value as NSError).code != NSURLErrorCancelled { error = value.localizedDescription }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if url.absoluteString == "about:blank" || WudDomain.validURL(url.absoluteString) != nil {
            decisionHandler(.allow)
        } else {
            error = AppState.shared.text("هذا الرابط غير مدعوم داخل المتصفح. استخدم رابط HTTPS.", "This link is unsupported in the browser. Use an HTTPS URL.")
            decisionHandler(.cancel)
        }
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url, WudDomain.validURL(url.absoluteString) != nil {
            showingHome = false
            webView.load(navigationAction.request)
        }
        return nil
    }
    func close() {
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
    }
}

struct EntertainmentWebSurface: UIViewRepresentable {
    let session: EntertainmentWebSession
    func makeUIView(context: Context) -> WKWebView { session.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct EntertainmentBrowser: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session = EntertainmentWebSession()
    @State private var input = ""
    @State private var saving = false
    @State private var bookmarkName = ""
    @State private var bookmarkURL = ""
    @FocusState private var addressFocused: Bool
    let initialURL: String

    private var shortcuts: [MediaSource] { state.sources.filter { $0.type == "website" } }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    TextField(state.text("رابط أو بحث", "URL or search"), text: $input)
                        .keyboardType(.webSearch).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder).submitLabel(.go).focused($addressFocused)
                        .onSubmit { navigate(input) }
                    Button { navigate(input) } label: { Image(systemName: "arrow.right.circle.fill") }
                        .accessibilityLabel(state.text("فتح", "Go"))
                }.padding()
                if session.loading { ProgressView().padding(.bottom, 8) }
                if let error = session.error {
                    HStack {
                        Text(error).font(.caption).foregroundStyle(.red)
                        Button(state.text("إعادة المحاولة", "Retry")) { navigate(session.address.isEmpty ? input : session.address) }
                    }.padding()
                }
                ZStack {
                    EntertainmentWebSurface(session: session)
                        .opacity(session.showingHome ? 0 : 1)
                        .allowsHitTesting(!session.showingHome)
                    if session.showingHome {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                Text(state.text("اختصارات المواقع", "Website shortcuts")).font(.title2.bold())
                                links(shortcuts)
                            }.padding()
                        }.background(Color(uiColor: .systemBackground))
                    }
                }
                HStack(spacing: 28) {
                    Button { session.webView.goBack() } label: { Image(systemName: "chevron.backward") }.disabled(!session.canGoBack)
                        .accessibilityLabel(state.text("رجوع", "Back"))
                    Button { session.webView.goForward() } label: { Image(systemName: "chevron.forward") }.disabled(!session.canGoForward)
                        .accessibilityLabel(state.text("تقدم", "Forward"))
                    Button { session.webView.stopLoading(); session.showingHome = true; addressFocused = false } label: { Image(systemName: "house") }
                        .accessibilityLabel(state.text("اختصارات المواقع", "Website shortcuts"))
                    Button { session.webView.reload() } label: { Image(systemName: "arrow.clockwise") }.disabled(session.showingHome)
                        .accessibilityLabel(state.text("تحديث", "Reload"))
                    Button {
                        guard let url = session.webView.url, WudDomain.validURL(url.absoluteString) != nil else { return }
                        bookmarkName = session.title.isEmpty ? (url.host ?? "") : session.title
                        bookmarkURL = url.absoluteString
                        saving = true
                    } label: { Image(systemName: "star") }.disabled(session.showingHome || session.webView.url == nil)
                        .accessibilityLabel(state.text("حفظ الاختصار", "Save shortcut"))
                }.padding()
            }
            .navigationTitle(state.text("متصفح الترفيه", "Entertainment browser"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(state.text("إغلاق", "Close")) { session.close(); dismiss() } } }
            .sheet(isPresented: $saving) {
                NavigationStack {
                    Form {
                        TextField(state.text("الاسم", "Name"), text: $bookmarkName)
                        TextField("https://", text: $bookmarkURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button(state.text("حفظ", "Save")) { saveBookmark() }
                            .disabled(bookmarkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || WudDomain.validURL(bookmarkURL) == nil)
                    }.navigationTitle(state.text("إضافة اختصار", "Add shortcut"))
                        .toolbar { Button(state.text("إلغاء", "Cancel")) { saving = false } }
                }
            }
            .onAppear { navigate(initialURL) }
            .onChange(of: session.address) { _, value in if !addressFocused { input = value } }
            .onDisappear { session.close() }
        }
    }
    private func navigate(_ value: String) { addressFocused = false; session.open(value) }
    private func links(_ items: [MediaSource]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
            ForEach(items) { source in
                Button { navigate(source.url) } label: {
                    VStack(spacing: 8) {
                        WebsiteShortcutIcon(source: source).frame(width: 56, height: 56)
                        Text(source.name).lineLimit(2)
                    }.frame(maxWidth: .infinity, minHeight: 80).padding(8)
                }.buttonStyle(.bordered)
            }
        }
    }
    private func saveBookmark() {
        guard let url = WudDomain.validURL(bookmarkURL) else { return }
        if let index = state.sources.firstIndex(where: { $0.url == url.absoluteString && $0.type == "website" }) {
            state.sources[index].name = String(bookmarkName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
            state.sources[index].favorite = true
        } else {
            state.sources.append(MediaSource(name: String(bookmarkName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)), url: url.absoluteString, type: "website", mediaKind: "video", favorite: true))
        }
        saving = false
    }
}
