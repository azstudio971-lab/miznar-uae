import SwiftUI

// MARK: - Xtream and M3U lists

struct XtreamHomeView: View {
    var readOnly = false
    var presentPlaybackOnPhone = true
    @ObservedObject private var store = XtreamStore.shared
    @ObservedObject private var m3u = M3UStore.shared
    @State private var editing: XtreamAccount?
    @State private var showAdd = false
    @State private var editingM3U: M3UPlaylist?
    @State private var showAddM3U = false

    var body: some View {
        NavigationStack {
            List {
                Section(tr("حسابات Xtream Codes", "Xtream Codes accounts")) {
                    if store.accounts.isEmpty {
                        Text(tr("أضف حساب Xtream Codes لعرض القنوات والأفلام هنا وفي CarPlay.",
                                "Add an Xtream Codes account to browse channels and movies here and in CarPlay."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.accounts) { account in
                        NavigationLink(value: account) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.name).font(.headline)
                                Text("\(account.username) · \(account.displayHost)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions {
                            if !readOnly {
                                Button(role: .destructive) { store.remove(account.id) } label: {
                                    Label(tr("حذف", "Delete"), systemImage: "trash")
                                }
                                Button { editing = account } label: {
                                    Label(tr("تعديل", "Edit"), systemImage: "pencil")
                                }
                                .tint(.wdNavy)
                            }
                        }
                    }
                }

                Section(tr("قوائم M3U / M3U8", "M3U / M3U8 playlists")) {
                    if m3u.playlists.isEmpty {
                        Text(tr("أضف رابط قائمة M3U لعرض القنوات والمجموعات والمفضلة.",
                                "Add an M3U playlist URL to browse channels, groups, and favorites."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(m3u.playlists) { playlist in
                        NavigationLink(value: playlist) {
                            Label(playlist.name, systemImage: "list.bullet.rectangle")
                        }
                        .swipeActions {
                            if !readOnly {
                                Button(role: .destructive) { m3u.remove(playlist.id) } label: {
                                    Label(tr("حذف", "Delete"), systemImage: "trash")
                                }
                                Button { editingM3U = playlist } label: {
                                    Label(tr("تعديل", "Edit"), systemImage: "pencil")
                                }
                                .tint(.wdNavy)
                            }
                        }
                    }
                }
            }
            .navigationTitle("M3U IPTV Player")
            .navigationDestination(for: XtreamAccount.self) { XtreamAccountView(account: $0, presentPlaybackOnPhone: presentPlaybackOnPhone) }
            .navigationDestination(for: M3UPlaylist.self) { M3UEntriesView(playlist: $0, presentPlaybackOnPhone: presentPlaybackOnPhone) }
            .toolbar {
                if !readOnly {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(tr("إضافة حساب Xtream", "Add Xtream account"), systemImage: "plus") { showAdd = true }
                        Button(tr("إضافة قائمة M3U", "Add M3U playlist"), systemImage: "list.bullet.rectangle") { showAddM3U = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(tr("إضافة حساب أو قائمة", "Add account or playlist"))
                }
                }
            }
            .sheet(isPresented: $showAdd) { XtreamAccountEditor(account: nil) }
            .sheet(item: $editing) { XtreamAccountEditor(account: $0) }
            .sheet(isPresented: $showAddM3U) { M3UPlaylistEditor(playlist: nil) }
            .sheet(item: $editingM3U) { M3UPlaylistEditor(playlist: $0) }
        }
    }
}

struct M3UPlaylistEditor: View {
    @Environment(\.dismiss) private var dismiss
    let playlist: M3UPlaylist?
    @State private var name: String
    @State private var urlText: String
    @State private var error: String?

    init(playlist: M3UPlaylist?) {
        self.playlist = playlist
        _name = State(initialValue: playlist?.name ?? "")
        _urlText = State(initialValue: playlist?.playlistURL?.absoluteString ?? "")
    }

    private var resolvedURL: URL? {
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        return url
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(tr("اسم القائمة", "Playlist name"), text: $name)
                    TextField(tr("رابط M3U أو M3U8", "M3U or M3U8 URL"), text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text(tr("يُحفظ الرابط على هذا الجهاز في Keychain.", "The playlist URL is stored on this device in Keychain."))
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle(playlist == nil ? tr("إضافة قائمة M3U", "Add M3U playlist") : tr("تعديل قائمة M3U", "Edit M3U playlist"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("إلغاء", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("حفظ", "Save")) {
                        guard let url = resolvedURL else {
                            error = M3UError.invalidURL.localizedDescription
                            return
                        }
                        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !title.isEmpty else {
                            error = tr("أدخل اسم القائمة.", "Enter a playlist name.")
                            return
                        }
                        M3UStore.shared.save(M3UPlaylist(id: playlist?.id ?? UUID(), name: title), url: url)
                        dismiss()
                    }
                    .disabled(resolvedURL == nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct M3UEntriesView: View {
    let playlist: M3UPlaylist
    var presentPlaybackOnPhone = true
    @ObservedObject private var store = M3UStore.shared
    @State private var entries: [M3UEntry] = []
    @State private var query = ""
    @State private var loading = false
    @State private var error: String?

    private var filtered: [M3UEntry] {
        query.isEmpty ? entries : entries.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.group.localizedCaseInsensitiveContains(query)
        }
    }

    private var groups: [(String, [M3UEntry])] {
        Dictionary(grouping: filtered, by: { $0.group.isEmpty ? tr("قنوات أخرى", "Other channels") : $0.group })
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        List {
            if loading { HStack { Spacer(); ProgressView(); Spacer() } }
            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    Button(tr("إعادة المحاولة", "Retry")) { Task { await load() } }
                }
            } else if !store.favorites(in: playlist, entries: filtered).isEmpty {
                Section(tr("المفضلة", "Favorites")) {
                    ForEach(store.favorites(in: playlist, entries: filtered)) { entry in row(entry) }
                }
            }
            ForEach(groups.indices, id: \.self) { index in
                Section(groups[index].0) {
                    ForEach(groups[index].1) { entry in row(entry) }
                }
            }
        }
        .searchable(text: $query, prompt: tr("بحث في القنوات والمجموعات", "Search channels and groups"))
        .navigationTitle(playlist.name)
        .task(id: playlist.id) { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder private func row(_ entry: M3UEntry) -> some View {
        HStack(spacing: 10) {
            Button {
                PlaybackManager.shared.play(.init(title: entry.title,
                                                  subtitle: entry.group.isEmpty ? playlist.name : entry.group,
                                                  url: entry.url,
                                                  isLive: true,
                                                  artworkURL: entry.logo, sourceKey: "m3u-\(playlist.id)"),
                                            presentOnPhone: presentPlaybackOnPhone)
            } label: {
                HStack {
                    AsyncImage(url: entry.logo) { image in image.resizable().scaledToFit() } placeholder: {
                        Image(systemName: "play.tv").foregroundStyle(.secondary)
                    }
                    .frame(width: 42, height: 32)
                    VStack(alignment: .leading) {
                        Text(entry.title).foregroundStyle(.primary).lineLimit(2)
                        if !entry.group.isEmpty {
                            Text(entry.group).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .contextMenu { ChannelLibraryMenu(title: entry.title, url: entry.url, live: true, sourceKey: "m3u-\(playlist.id)") }
            Spacer(minLength: 4)
            Button {
                store.toggleFavorite(entry, in: playlist)
            } label: {
                Image(systemName: store.isFavorite(entry, in: playlist) ? "heart.fill" : "heart")
                    .foregroundColor(store.isFavorite(entry, in: playlist) ? .red : .secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(store.isFavorite(entry, in: playlist) ? tr("إزالة من المفضلة", "Remove favorite") : tr("إضافة للمفضلة", "Add to favorites"))
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do { entries = try await store.entries(for: playlist) }
        catch { self.error = error.localizedDescription }
    }
}

// MARK: - إضافة / تعديل حساب

struct XtreamAccountEditor: View {
    @Environment(\.dismiss) private var dismiss
    let account: XtreamAccount?

    @State private var name: String
    @State private var server: String
    @State private var username: String
    @State private var password = ""
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false

    init(account: XtreamAccount?) {
        self.account = account
        _name = State(initialValue: account?.name ?? "")
        _server = State(initialValue: account?.server ?? "")
        _username = State(initialValue: account?.username ?? "")
    }

    private var draft: XtreamAccount {
        XtreamAccount(id: account?.id ?? UUID(),
                      name: name.trimmingCharacters(in: .whitespaces).isEmpty ? (XtreamAccount.normalize(server)?.host ?? "IPTV") : name,
                      server: server.trimmingCharacters(in: .whitespacesAndNewlines),
                      username: username.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var effectivePassword: String? { password.isEmpty ? account?.password : password }

    private var canSave: Bool {
        XtreamAccount.normalize(server) != nil && !username.trimmingCharacters(in: .whitespaces).isEmpty
            && (effectivePassword?.isEmpty == false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(tr("اسم الحساب (اختياري)", "Account name (optional)"), text: $name)
                    TextField(tr("عنوان السيرفر مثل example.com:8080", "Server, e.g. example.com:8080"), text: $server)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField(tr("اسم المستخدم", "Username"), text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField(account == nil ? tr("كلمة المرور", "Password")
                                               : tr("كلمة المرور (اتركها فارغة للإبقاء)", "Password (leave empty to keep)"),
                                text: $password)
                } footer: {
                    Text(tr("كلمة المرور تُحفظ في Keychain على هذا الجهاز فقط.",
                            "The password is stored in the Keychain on this device only."))
                }

                Section {
                    Button {
                        Task { await test() }
                    } label: {
                        HStack {
                            Text(tr("اختبار الاتصال", "Test connection"))
                            Spacer()
                            if testing { ProgressView() }
                        }
                    }
                    .disabled(!canSave || testing)
                    if let testResult {
                        Label(testResult, systemImage: testOK ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(testOK ? .green : .red)
                    }
                }
            }
            .navigationTitle(account == nil ? tr("حساب جديد", "New account") : tr("تعديل الحساب", "Edit account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("إلغاء", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("حفظ", "Save")) {
                        XtreamStore.shared.save(draft, password: password.isEmpty ? nil : password)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func test() async {
        testing = true
        defer { testing = false }
        do {
            let info = try await XtreamClient(account: draft, password: effectivePassword).authenticate()
            testOK = true
            if let expiry = info.expiry {
                testResult = tr("متصل ✓ — ينتهي في ", "Connected ✓ — expires ") + expiry.formatted(date: .abbreviated, time: .omitted)
            } else {
                testResult = tr("متصل ✓", "Connected ✓")
            }
        } catch {
            testOK = false
            testResult = error.localizedDescription
        }
    }
}

// MARK: - أقسام الحساب

struct XtreamAccountView: View {
    let account: XtreamAccount
    var presentPlaybackOnPhone = true
    @State private var kind: XtreamKind = .live
    @State private var categories: [XtreamCategory] = []
    @State private var info: XtreamAccountInfo?
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        List {
            Section {
                Picker("", selection: $kind) {
                    ForEach(XtreamKind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if let info {
                    LabeledContent(tr("الحالة", "Status"), value: info.status)
                    if let expiry = info.expiry {
                        LabeledContent(tr("ينتهي", "Expires"), value: expiry.formatted(date: .abbreviated, time: .omitted))
                    }
                }
            }

            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    Button(tr("إعادة المحاولة", "Retry")) { Task { await load() } }
                }
            } else if loading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else {
                Section(kind.title) {
                    NavigationLink(tr("الكل", "All")) {
                        XtreamStreamsView(account: account, kind: kind, category: nil, presentPlaybackOnPhone: presentPlaybackOnPhone)
                    }
                    ForEach(categories) { category in
                        NavigationLink(category.name) {
                            XtreamStreamsView(account: account, kind: kind, category: category, presentPlaybackOnPhone: presentPlaybackOnPhone)
                        }
                    }
                }
            }
        }
        .navigationTitle(account.name)
        .task(id: kind) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        let client = XtreamClient(account: account)
        do {
            if info == nil { info = try await client.authenticate() }
            categories = try await client.categories(kind)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - القنوات / الأفلام

struct XtreamStreamsView: View {
    let account: XtreamAccount
    let kind: XtreamKind
    let category: XtreamCategory?
    var presentPlaybackOnPhone = true

    @ObservedObject private var playback = PlaybackManager.shared
    @State private var streams: [XtreamStream] = []
    @State private var query = ""
    @State private var loading = false
    @State private var error: String?

    private var filtered: [XtreamStream] {
        query.isEmpty ? streams : streams.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            if let error {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                Button(tr("إعادة المحاولة", "Retry")) { Task { await load() } }
            } else if loading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if filtered.isEmpty {
                Text(tr("لا يوجد محتوى.", "No content.")).foregroundStyle(.secondary)
            }
            ForEach(filtered) { stream in
                Button { play(stream) } label: {
                    HStack(spacing: 12) {
                        AsyncImage(url: stream.icon) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Image(systemName: kind.symbol).foregroundStyle(.secondary)
                        }
                        .frame(width: 54, height: 40)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
                        Text(stream.name).foregroundStyle(.primary).lineLimit(2)
                        Spacer()
                        if playback.current?.title == stream.name && playback.isPlaying {
                            Image(systemName: "speaker.wave.2.fill").foregroundStyle(Color.wdAccent)
                        }
                    }
                }.contextMenu {
                    if let url = XtreamClient(account: account).playbackURL(for: stream) {
                        ChannelLibraryMenu(title: stream.name, url: url, live: kind == .live, sourceKey: "xtream-\(account.id)")
                    }
                }
            }
        }
        .searchable(text: $query, prompt: tr("بحث", "Search"))
        .navigationTitle(category?.name ?? tr("الكل", "All"))
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            streams = try await XtreamClient(account: account).streams(kind, categoryID: category?.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func play(_ stream: XtreamStream) {
        guard let url = XtreamClient(account: account).playbackURL(for: stream) else {
            error = XtreamError.missingPassword.localizedDescription
            return
        }
        PlaybackManager.shared.play(.init(title: stream.name,
                                          subtitle: account.name,
                                          url: url,
                                          isLive: kind == .live,
                                          artworkURL: stream.icon, sourceKey: "xtream-\(account.id)"),
                                    presentOnPhone: presentPlaybackOnPhone)
    }
}
