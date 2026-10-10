import SwiftUI
import AVKit
import WebKit

struct MediaView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openURL) private var openURL
    @ObservedObject private var player = PlayerService.shared
    @State private var browserSource: MediaSource?
    @State private var editingID: String?
    @State private var section = "website"
    @State private var adding = false
    @State private var showingPlayer = false
    @State private var name = ""
    @State private var address = ""
    @State private var query = ""
    private var entries: [MediaSource] {
        let official = state.library.map { MediaSource(id: $0.id, name: $0.name(state.preferences.language), url: $0.url, type: $0.kind == "website" ? "website" : "stream", mediaKind: "video", favorite: state.preferences.favoriteIDs.contains($0.id)) }
        return (official + state.sources).filter { (section == "website" ? $0.type == "website" : $0.type != "website") && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Picker(state.text("المكتبة", "Library"), selection: $section) { Text(state.text("المواقع", "Websites")).tag("website"); Text(state.text("البث المباشر", "Live streams")).tag("live") }.pickerStyle(.segmented)
                TextField(state.text("ابحث في مكتبتك", "Search your library"), text: $query).textFieldStyle(.roundedBorder)
                grid(entries)
                Text(state.text("المفضلة", "Favorites")).font(.title3.bold())
                if entries.contains(where: \.favorite) { grid(entries.filter(\.favorite)) } else { Text(state.text("اضغط النجمة لحفظ رابطك المفضل.", "Tap a star to save a favorite.")).font(.caption).foregroundStyle(.secondary) }
                Button { editingID = nil; name = ""; address = ""; adding = true } label: { Label(state.text("إضافة رابط", "Add a link"), systemImage: "plus").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                if section == "live" && entries.isEmpty { ContentUnavailableView(state.text("أضف أول بث مباشر", "Add your first live stream"), systemImage: "dot.radiowaves.left.and.right") }
                if !state.tracks.isEmpty && state.theme.music_mode != "none" {
                    Text(state.text("قائمة الثيم", "Theme playlist")).font(.title3.bold())
                    ForEach(state.themeTracks) { track in
                        Button(state.text(track.name_ar, track.name_en)) { player.playPlaylist(state.themeTracks, startingAt: track.id); showingPlayer = true }
                    }
                }
            }.padding()
        }.navigationTitle(state.text("الترفيه", "Entertainment"))
        .fullScreenCover(item: $browserSource) { source in EntertainmentBrowser(initialURL: source.url) }
        .onChange(of: state.sources) { _, _ in Task { do { try await CloudClient.shared.saveLibrary() } catch { state.notice = error.localizedDescription } } }
        .sheet(isPresented: $showingPlayer) { VStack { Text(player.title).font(.headline); VideoPlayer(player: player.player); AirPlayButton().frame(width: 44, height: 44); if let error = player.error { Text(error).foregroundStyle(.red) }; Button(state.text("إغلاق", "Close")) { player.stop(); showingPlayer = false } }.padding() }
        .sheet(isPresented: $adding) { NavigationStack { Form {
            TextField(state.text("الاسم", "Name"), text: $name)
            TextField("https://", text: $address).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
            Text(state.text("المواقع تفتح داخل التطبيق. البث يحتاج رابط فيديو مباشر مثل HLS.", "Websites open inside the app. Live streams need a direct video URL, such as HLS.")).font(.caption)
            Button(state.text("حفظ في المفضلة", "Save to favorites")) { guard let url = WudDomain.validURL(address) else { return }; if let editingID, let index = state.sources.firstIndex(where: { $0.id == editingID }) { state.sources[index].name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)); state.sources[index].url = url.absoluteString } else { state.sources.append(MediaSource(name: String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)), url: url.absoluteString, type: section == "website" ? "website" : "stream", mediaKind: "video", favorite: true)) }; editingID = nil; adding = false; name = ""; address = "" }.disabled(WudDomain.validURL(address) == nil || name.trimmingCharacters(in: .whitespaces).isEmpty)
        }.navigationTitle(state.text("إضافة رابط", "Add a link")).toolbar { Button(state.text("إلغاء", "Cancel")) { adding = false } } } }
    }
    private func grid(_ sources: [MediaSource]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 22) {
            ForEach(sources) { source in VStack(spacing: 9) {
                Button { open(source) } label: { VStack(spacing: 10) {
                    ZStack { RoundedRectangle(cornerRadius: 18).fill(Color(red: 0.04, green: 0.32, blue: 0.38)); Text(String(source.name.prefix(2))).font(.title2.bold()).foregroundStyle(.white) }.frame(width: 66, height: 66)
                    Text(source.name).font(.caption).lineLimit(1)
                } }.buttonStyle(.plain)
                Button { favorite(source) } label: { Image(systemName: source.favorite ? "star.fill" : "star").foregroundStyle(source.favorite ? Color.orange : Color.secondary) }.accessibilityLabel(state.text("المفضلة", "Favorite") + " " + source.name)
            }.contextMenu { if state.sources.contains(where: { $0.id == source.id }) { Button(state.text("تعديل الرابط", "Edit link")) { editingID = source.id; name = source.name; address = source.url; adding = true }; Button(state.text("حذف", "Delete"), role: .destructive) { state.sources.removeAll { $0.id == source.id } } } } }
        }
    }
    private func favorite(_ source: MediaSource) {
        if let i = state.sources.firstIndex(where: { $0.id == source.id }) { state.sources[i].favorite.toggle() }
        else if state.preferences.favoriteIDs.contains(source.id) { state.preferences.favoriteIDs.removeAll { $0 == source.id } }
        else { state.preferences.favoriteIDs.append(source.id) }
        Task { await state.sync(); do { try await CloudClient.shared.saveLibrary() } catch { state.notice = error.localizedDescription } }
    }
    private func open(_ source: MediaSource) {
        guard let url = WudDomain.validURL(source.url) else { return }
        if source.type == "website" { browserSource = source }
        else { player.play(url: url, name: source.name); showingPlayer = true }
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

    private var favorites: [MediaSource] {
        let catalog = state.library.filter { $0.kind == "website" && state.preferences.favoriteIDs.contains($0.id) }
            .map { MediaSource(id: $0.id, name: $0.name(state.preferences.language), url: $0.url, type: "website", mediaKind: "video", favorite: true) }
        return catalog + state.sources.filter { $0.type == "website" && $0.favorite }
    }
    private var shortcuts: [MediaSource] {
        var items = state.library.filter { $0.kind == "website" }
            .map { MediaSource(id: $0.id, name: $0.name(state.preferences.language), url: $0.url, type: "website", mediaKind: "video") }
        if !items.contains(where: { URL(string: $0.url)?.host?.contains("youtube.com") == true }) {
            items.insert(MediaSource(id: "youtube-shortcut", name: "YouTube", url: "https://www.youtube.com", type: "website", mediaKind: "video"), at: 0)
        }
        return items + state.sources.filter { $0.type == "website" && !$0.favorite }
    }
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
                                Text(state.text("المفضلة", "Favorites")).font(.title2.bold())
                                if favorites.isEmpty {
                                    Text(state.text("افتح موقعًا ثم اضغط النجمة لإضافته هنا.", "Open a website and tap the star to save it here.")).foregroundStyle(.secondary)
                                }
                                links(favorites)
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
                        .accessibilityLabel(state.text("المفضلة والاختصارات", "Favorites and shortcuts"))
                    Button { session.webView.reload() } label: { Image(systemName: "arrow.clockwise") }.disabled(session.showingHome)
                        .accessibilityLabel(state.text("تحديث", "Reload"))
                    Button {
                        guard let url = session.webView.url, WudDomain.validURL(url.absoluteString) != nil else { return }
                        bookmarkName = session.title.isEmpty ? (url.host ?? "") : session.title
                        bookmarkURL = url.absoluteString
                        saving = true
                    } label: { Image(systemName: "star") }.disabled(session.showingHome || session.webView.url == nil)
                        .accessibilityLabel(state.text("حفظ في المفضلة", "Save to favorites"))
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
                    }.navigationTitle(state.text("إضافة للمفضلة", "Add favorite"))
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
                        Image(systemName: "globe").font(.title)
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
        Task { do { try await CloudClient.shared.saveLibrary() } catch { state.notice = error.localizedDescription } }
    }
}
