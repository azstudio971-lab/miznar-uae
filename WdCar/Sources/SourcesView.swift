import SwiftUI
import UniformTypeIdentifiers

struct SourcesView: View {
    @ObservedObject private var store = SourceStore.shared
    @ObservedObject private var m3u = M3UStore.shared
    @ObservedObject private var xtream = XtreamStore.shared
    @State private var adding = false
    @State private var renaming: MediaSource?
    @State private var name = ""
    var body: some View {
        List {
            Section {
                Text(tr("ما هو المصدر؟", "What is a source?")).font(.headline)
                Text(tr("المصدر رابط قائمة أو خادم الوسائط الخاص بك. احصل عليه من مزود تملك حق استخدام محتواه، أو استخدم ملفاتك وخادمك الشخصي.", "A source is your playlist URL or media server. Obtain it from a provider whose content you are entitled to use, or use your own files and server."))
                Text(tr("WudCar مشغّل فقط ولا يأتي بأي قنوات. أضف فقط مصادر تملكها أو يحق لك استخدامها.", "WudCar is a player and includes no channels. Add only sources you own or are entitled to use.")).font(.footnote)
            }
            Section(tr("مصادري", "My sources")) {
                ForEach(store.sources) { source in
                    NavigationLink { SourceBrowserView(source: source) } label: {
                        VStack(alignment: .leading) {
                            Label(source.name, systemImage: source.hidden ? "eye.slash" : "server.rack")
                            Text("\(source.count) " + tr("عنصر", "items")).font(.caption).foregroundStyle(.secondary)
                            if let updated = source.updated { Text(updated, style: .relative).font(.caption).foregroundStyle(.secondary) }
                        }
                    }.contextMenu {
                        Button(tr("تحديث المصدر", "Refresh source")) { Task { do { try await store.refresh(source) } catch { store.error = error.localizedDescription } } }
                        Button(tr("إعادة تسمية", "Rename")) { name = source.name; renaming = source }
                        Button(source.hidden ? tr("إظهار في الرئيسية", "Show on Home") : tr("إخفاء من الرئيسية", "Hide from Home")) { store.hide(source) }
                        if ![.pasted,.config].contains(source.kind) { Button(tr("نسخ رابط المصدر", "Copy source URL")) { UIPasteboard.general.string = store.credentials(source)?.address } }
                        Button(tr("حذف", "Delete"), role: .destructive) { store.remove(source) }
                    }
                }
                if store.sources.isEmpty { Text(tr("أضف مصدرك الأول", "Add your first source")).foregroundStyle(.secondary) }
            }
            if !m3u.playlists.isEmpty || !xtream.accounts.isEmpty {
                Section(tr("مصادرك المحفوظة سابقاً", "Existing sources")) {
                    NavigationLink(tr("قوائم M3U وحسابات Xtream", "M3U playlists and Xtream accounts")) { XtreamHomeView() }
                }
            }
            if let progress = store.progress { ProgressView(progress) }
            Section { Text(tr("تُحفظ بياناتك على هذا الجهاز فقط وتُستخدم للاتصال بخادمك فقط.", "Your credentials stay on this device and are used only to connect to your server.")).font(.footnote) }
        }.navigationTitle(tr("مصادري", "My sources"))
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $adding) { NavigationStack { AddSourceView() } }
            .alert(tr("إعادة تسمية", "Rename"), isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField(tr("الاسم", "Name"), text: $name)
                Button(tr("حفظ", "Save")) { if let source = renaming { store.rename(source, name: name) }; renaming = nil }
                Button(tr("إلغاء", "Cancel"), role: .cancel) { renaming = nil }
            }
            .alert(tr("تعذّر الاتصال بالمصدر", "Source connection failed"), isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button(tr("فتح الإعدادات", "Open Settings")) { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                Button("OK") { store.error = nil }
            } message: { Text(store.error ?? "") }
    }
}
struct AddSourceView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SourceStore.shared
    @State private var kind = MediaSource.Kind.playlist
    @State private var name = ""
    @State private var address = ""
    @State private var username = ""
    @State private var password = ""
    @State private var text = ""
    @State private var busy = false
    @State private var error: String?
    @State private var result: String?
    @State private var scanning = false
    @State private var photoQR = false
    @State private var importing = false
    @State private var pin: Int?
    @State private var code = ""
    @State private var servers: [SourceNetwork.PlexServer] = []
    private func title(_ kind: MediaSource.Kind) -> String {
        switch kind {
        case .playlist: return "M3U / M3U8"
        case .pasted: return tr("نص M3U", "M3U text")
        case .config: return tr("ملف إعداد / عدة روابط", "Config / multiple URLs")
        case .stream: return tr("بث واحد", "Single stream")
        case .jellyfin: return "Jellyfin"
        case .emby: return "Emby"
        case .plex: return "Plex"
        }
    }
    var body: some View {
        Form {
            Section {
                Picker(tr("نوع المصدر", "Source type"), selection: $kind) { ForEach(MediaSource.Kind.allCases, id: \.self) { Text(title($0)).tag($0) } }
                TextField(tr("اسم المصدر", "Source name"), text: $name)
                if kind == .pasted || kind == .config {
                    TextEditor(text: $text).frame(minHeight: 160).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button(tr("استيراد ملف نصي", "Import text file")) { importing = true }
                } else if kind != .plex {
                    TextField("https://", text: $address).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                if kind == .jellyfin || kind == .emby {
                    TextField(tr("اسم المستخدم", "Username"), text: $username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField(tr("كلمة المرور", "Password"), text: $password)
                }
            }
            if kind == .plex {
                Section("Plex") {
                    if code.isEmpty { Button(tr("الحصول على كود تسجيل الدخول", "Get sign-in code")) { Task { await beginPlex() } } }
                    else {
                        Text(code).font(.largeTitle.monospaced())
                        Link("plex.tv/link", destination: URL(string: "https://plex.tv/link")!)
                        Button(tr("أكملت تسجيل الدخول — تحقق", "Signed in — check")) { Task { await checkPlex() } }
                    }
                    ForEach(servers) { server in
                        Button(server.name + " — " + (server.url.host ?? "")) {
                            Task { await savePlex(server) }
                        }
                    }
                }
            } else {
                Section(tr("إضافة سريعة", "Quick add")) {
                    PasteButton(payloadType: String.self) { strings in if let value = strings.first { applyInput(value) } }
                    Button(tr("مسح QR بالكاميرا", "Scan QR with camera")) { scanning = true }
                    Button(tr("QR من صورة", "QR from a photo")) { photoQR = true }
                }
                Button(tr("فحص وإضافة المصدر", "Check and add source")) { Task { await save() } }.disabled(busy)
            }
            if busy { ProgressView(store.progress ?? tr("جارِ الاتصال…", "Connecting…")) }
            if let result { Text(result).foregroundStyle(.green) }
            if let error { Text(error).foregroundStyle(.red) }
            Text(tr("تُحفظ بياناتك على هذا الجهاز فقط وتُستخدم للاتصال بخادمك فقط.", "Your credentials stay on this device and are used only to connect to your server.")).font(.footnote)
        }.navigationTitle(tr("إضافة مصدر", "Add source"))
            .toolbar { Button(tr("إغلاق", "Close")) { dismiss() } }
            .disabled(busy)
            .sheet(isPresented: $scanning) { QRScannerView { value in scanning = false; applyInput(value) } }
            .sheet(isPresented: $photoQR) { QRPhotoPicker { value in photoQR = false; if let value { applyInput(value) } else { error = tr("لم يُعثر على رمز QR صالح.", "No valid QR code was found.") } } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText, .json, .data]) { outcome in
                do {
                    let url = try outcome.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 15 * 1024 * 1024 else { throw SourceFailure.tooLarge }
                    applyInput(try String(contentsOf: url, encoding: .utf8))
                } catch { self.error = error.localizedDescription }
            }
    }
    private func applyInput(_ value: String) {
        kind = SourceInput.smartKind(value)
        if kind == .config || kind == .pasted { text = value } else { address = value }
    }
    private func save() async {
        busy = true; error = nil; result = nil; defer { busy = false }
        do {
            if kind == .config {
                let counts = await store.addConfig(text, name: name)
                result = tr("أُضيف \(counts.added)، وفشل \(counts.failed)", "Added \(counts.added), failed \(counts.failed)")
            } else {
                let source = try await store.add(name: name, kind: kind, credentials: SourceCredentials(address: address, username: username, password: password, text: text))
                result = tr("تم العثور على \(source.count) عنصر", "Found \(source.count) items")
            }
        } catch { self.error = error.localizedDescription }
    }
    private func beginPlex() async {
        busy = true; defer { busy = false }
        do { let value = try await SourceNetwork().plexPIN(); pin = value.0; code = value.1 } catch { self.error = error.localizedDescription }
    }
    private func checkPlex() async {
        guard let pin else { return }; busy = true; defer { busy = false }
        do {
            guard let token = try await SourceNetwork().plexToken(pin: pin) else { error = tr("الكود لم يُعتمد بعد أو انتهى. حاول مجدداً.", "The code is not authorized or has expired. Try again."); return }
            servers = try await SourceNetwork().plexServers(token: token)
            if servers.isEmpty { error = tr("لم يُعثر على خادم تملكه.", "No server owned by your account was found.") }
        } catch { self.error = error.localizedDescription }
    }
    private func savePlex(_ server: SourceNetwork.PlexServer) async {
        busy = true; defer { busy = false }
        do { _ = try await store.add(name: name.isEmpty ? server.name : name, kind: .plex, credentials: SourceCredentials(address: server.url.absoluteString, token: server.token)); dismiss() } catch { self.error = error.localizedDescription }
    }
}
struct SourceBrowserView: View {
    let source: MediaSource
    var parent: String? = nil
    var title: String? = nil
    @ObservedObject private var store = SourceStore.shared
    @State private var items: [SourceMedia] = []
    @State private var query = ""
    @State private var error: String?
    @State private var loading = false
    private var visible: [SourceMedia] { query.isEmpty ? items : items.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.group.localizedCaseInsensitiveContains(query) } }
    var body: some View {
        List {
            if loading { ProgressView() }
            if let error { Text(error).foregroundStyle(.red); Button(tr("إعادة المحاولة", "Retry")) { Task { await load() } } }
            ForEach(visible) { item in
                if item.folder {
                    NavigationLink { SourceBrowserView(source: source, parent: item.id, title: item.title) } label: { row(item) }
                } else {
                    Button { store.play(item, source: source, onPhone: true) } label: { row(item) }
                        .contextMenu {
                            Button(tr("إضافة للمفضلة", "Add to favorites")) { favorite(item) }
                            Button(tr("إضافة للرئيسية", "Add to Home")) { favorite(item) }
                        }
                }
            }
        }.navigationTitle(title ?? source.name).searchable(text: $query)
            .task(id: parent) { await load() }
            .refreshable { await load() }
    }
    @ViewBuilder private func row(_ item: SourceMedia) -> some View {
        HStack {
            if let artwork = item.artwork {
                AsyncImage(url: artwork) { image in image.resizable().scaledToFit() } placeholder: { Image(systemName: item.folder ? "folder" : "play.rectangle") }.frame(width: 64, height: 50)
            } else { Image(systemName: item.folder ? "folder" : "play.rectangle").frame(width: 40) }
            VStack(alignment: .leading) {
                Text(item.title)
                if !item.group.isEmpty { Text(item.group).font(.caption).foregroundStyle(.secondary) }
                if item.position > 0 { Text(tr("شوهد حتى ", "Watched to ") + "\(Int(item.position) / 60):\(String(format: "%02d", Int(item.position) % 60))").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
    private func favorite(_ item: SourceMedia) {
        guard let url = item.url else { return }
        do {
            try MediaLibrary.shared.addRemote(title: item.title, url: url, isLive: item.isLive, sourceKey: source.id.uuidString)
            if let media = MediaLibrary.shared.items.first(where: { $0.url == url }), !media.favorite { MediaLibrary.shared.toggleFavorite(media.id) }
        } catch { store.error = error.localizedDescription }
    }
    private func load() async {
        loading = true; error = nil; defer { loading = false }
        do { items = try await store.browse(source, parent: parent) } catch { self.error = error.localizedDescription }
    }
}
