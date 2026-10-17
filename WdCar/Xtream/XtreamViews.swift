import SwiftUI

// MARK: - قائمة الحسابات

struct XtreamHomeView: View {
    @Environment(\.isCarDisplay) private var isCarDisplay
    @ObservedObject private var store = XtreamStore.shared
    @State private var editing: XtreamAccount?
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if store.accounts.isEmpty {
                    ContentUnavailableView {
                        Label(tr("لا توجد حسابات", "No accounts"), systemImage: "antenna.radiowaves.left.and.right")
                    } description: {
                        Text(tr("أضف حساب Xtream Codes لعرض القنوات والأفلام هنا وفي CarPlay.",
                                "Add an Xtream Codes account to browse channels and movies here and in CarPlay."))
                    } actions: {
                        if !isCarDisplay {
                            Button(tr("إضافة حساب", "Add account")) { showAdd = true }.buttonStyle(.borderedProminent)
                        } else { Text(carTr("أضف الاشتراك من تطبيق الآيفون", "Add your subscription on iPhone")) }
                    }
                } else {
                    List {
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
            }
            .navigationTitle("Xtream Codes")
            .navigationDestination(for: XtreamAccount.self) { XtreamAccountView(account: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !isCarDisplay { Button { showAdd = true } label: { Image(systemName: "plus") } }
                }
            }
            .sheet(isPresented: $showAdd) { XtreamAccountEditor(account: nil) }
            .sheet(item: $editing) { XtreamAccountEditor(account: $0) }
        }
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
                        XtreamStreamsView(account: account, kind: kind, category: nil)
                    }
                    ForEach(categories) { category in
                        NavigationLink(category.name) {
                            XtreamStreamsView(account: account, kind: kind, category: category)
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
    @Environment(\.isCarDisplay) private var isCarDisplay
    let account: XtreamAccount
    let kind: XtreamKind
    let category: XtreamCategory?

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
        if isCarDisplay && WDSettings.lockVideoWhileDriving && DrivingMonitor.shared.isMoving { return }
        PlaybackManager.shared.play(.init(title: stream.name,
                                          subtitle: account.name,
                                          url: url,
                                          isLive: kind == .live,
                                          artworkURL: stream.icon),
                                    presentOnPhone: !isCarDisplay)
        if isCarDisplay { NotificationCenter.default.post(name: .wdCarPlayXtream, object: nil) }
    }
}
