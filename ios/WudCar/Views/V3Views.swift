import SwiftUI
import Security

struct V3HomeView: View {
    @EnvironmentObject private var state: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image("BrandIcon").resizable().scaledToFit().frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                Text("WudCar — وُد كار").font(.largeTitle.bold())
                Text(state.text("رفيق مشاويرك", "Your journey companion")).font(.title2)
                Text(state.text("مرحبًا بكم في تطبيق ود كار — الحل الأمثل للاستمتاع والترفيه في السيارة",
                                "Welcome to WudCar — entertainment for your journeys."))
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                Text("AZ PIXEL Digital Solutions").font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity).padding(28)
        }.navigationTitle(state.text("الرئيسية", "Home"))
    }
}

struct V3SettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var showingAccount = false
    @ObservedObject private var cloud = CloudClient.shared
    @State private var deletingAccount = false
    @State private var deleting = false
    @State private var clearingBrowser = false
    @State private var confirmClearBrowser = false
    var body: some View {
        Form {
            Section {
                Picker(state.text("اللغة", "Language"), selection: $state.preferences.language) {
                    Text("العربية").tag("ar"); Text("English").tag("en")
                }
                Picker(state.text("المظهر", "Appearance"), selection: $state.preferences.appearance) {
                    Text(state.text("تلقائي", "System")).tag("system")
                    Text(state.text("نهاري", "Light")).tag("light")
                    Text(state.text("ليلي", "Dark")).tag("dark")
                }
            }
            Section {
                NavigationLink(state.text("سياسة الخصوصية", "Privacy policy")) { PolicyView(kind: "privacy") }
                NavigationLink(state.text("الشروط والأحكام", "Terms and conditions")) { PolicyView(kind: "terms") }
            }
            Section(state.text("اشتراك ود كار", "WudCar subscription")) {
                Text(state.text("سيتم عرض الباقات والأسعار عند اعتمادها.",
                                "Plans and prices will appear when they are finalized."))
                Text(state.text("اشتراك ود كار منفصل عن اشتراكات IPTV التي تضيفها.",
                                "Your WudCar subscription is separate from your IPTV subscriptions."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(state.text("حساب ود كار", "WudCar account")) {
                if cloud.session != nil {
                    Button(state.text("تسجيل الخروج", "Sign out")) { Task { await cloud.signOut() } }
                    Button(state.text("حذف حساب ود كار", "Delete WudCar account"), role: .destructive) { deletingAccount = true }
                        .disabled(deleting)
                } else {
                    Button(state.text("تسجيل الدخول", "Sign in")) { showingAccount = true }
                        .disabled(!AppConfiguration.configured)
                }
            }
            Section(state.text("المتصفح", "Browser")) {
                Button(state.text("مسح بيانات المواقع والتبويبات", "Clear website data and tabs"), role: .destructive) { confirmClearBrowser = true }
                    .disabled(clearingBrowser)
                Text(state.text("يسجّل خروجك من المواقع. تبقى اختصاراتك محفوظة.", "Signs you out of websites. Your shortcuts are kept."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section { Text("WudCar · AZ PIXEL Digital Solutions").font(.caption) }
        }
        .navigationTitle(state.text("الإعدادات", "Settings"))
        .sheet(isPresented: $showingAccount) { AuthView() }
        .confirmationDialog(state.text("مسح بيانات المواقع؟", "Clear website data?"), isPresented: $confirmClearBrowser, titleVisibility: .visible) {
            Button(state.text("مسح", "Clear"), role: .destructive) {
                clearingBrowser = true
                Task { await EntertainmentBrowserStore.shared.clearWebsiteData(); clearingBrowser = false }
            }
        }
        .confirmationDialog(state.text("حذف حساب ود كار وبياناته السحابية؟ اشتراكات Apple لا تُلغى تلقائيًا.",
                                        "Delete your WudCar account and cloud data? Apple subscriptions are not canceled automatically."),
                            isPresented: $deletingAccount, titleVisibility: .visible) {
            Button(state.text("حذف نهائي", "Delete permanently"), role: .destructive) {
                deleting = true
                Task {
                    defer { deleting = false }
                    do { try await cloud.deleteAccount(); state.clearPersonalData() }
                    catch { state.notice = state.text("تعذّر حذف الحساب. أعد المحاولة.", "Could not delete your account. Try again.") }
                }
            }
        }
    }
}

// Entire IPTV account records remain in this device's Keychain, never in sources.json,
// cloud library requests, logs, analytics or UserDefaults.
struct XtreamAccount: Codable, Identifiable {
    var id = UUID().uuidString
    var name: String
    var server: String
    var username: String
    var password: String
}

@MainActor final class XtreamAccountStore: ObservableObject {
    static let shared = XtreamAccountStore()
    @Published private(set) var accounts: [XtreamAccount] = []
    @Published private(set) var unavailable = false
    private let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.azpixel.wudcar.xtream",
        kSecAttrAccount as String: "accounts"
    ]

    init() { reload() }

    func reload() {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { accounts = []; unavailable = false; return }
        guard status == errSecSuccess, let data = result as? Data,
              let decoded = try? JSONDecoder().decode([XtreamAccount].self, from: data) else {
            accounts = []; unavailable = true; return
        }
        accounts = decoded; unavailable = false
    }

    static func serverURL(_ input: String) -> URL? {
        guard let url = WudDomain.validURL(input),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.query == nil, components.fragment == nil else { return nil }
        return url
    }

    func save(_ account: XtreamAccount) throws {
        guard !unavailable, Self.serverURL(account.server) != nil,
              !account.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !account.username.isEmpty, !account.password.isEmpty else { throw StoreError.invalid }
        var updated = accounts
        if let index = updated.firstIndex(where: { $0.id == account.id }) { updated[index] = account }
        else { updated.append(account) }
        try persist(updated)
    }

    func delete(_ id: String) throws {
        guard !unavailable else { throw StoreError.unavailable }
        try persist(accounts.filter { $0.id != id })
    }

    // Update first: a failed write must not delete previously saved credentials.
    private func persist(_ updated: [XtreamAccount]) throws {
        let data = try JSONEncoder().encode(updated)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            attributes.forEach { item[$0.key] = $0.value }
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw StoreError.unavailable }
        accounts = updated
    }

    enum StoreError: Error { case invalid, unavailable }
}

struct XtreamAccountsView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var store = XtreamAccountStore.shared
    @Environment(\.scenePhase) private var phase
    @State private var editing: XtreamAccount?
    @State private var pendingDelete: XtreamAccount?
    @State private var failure = false
    var body: some View {
        List {
            if store.unavailable {
                Section {
                    Text(state.text("تعذّر فتح الحسابات المحفوظة بأمان. افتح قفل الجهاز وأعد المحاولة.",
                                    "Saved accounts are unavailable. Unlock the device and retry."))
                    Button(state.text("إعادة المحاولة", "Retry")) { store.reload() }
                }
            } else {
                if store.accounts.isEmpty {
                    Text(state.text("أضف حساب IPTV الخاص بك للبدء.", "Add your IPTV account to get started."))
                        .foregroundStyle(.secondary)
                }
                ForEach(store.accounts) { account in
                    Button { editing = account } label: {
                        Label(account.name, systemImage: "tv").foregroundStyle(.primary)
                    }
                    .swipeActions {
                        Button(state.text("حذف", "Delete"), role: .destructive) { pendingDelete = account }
                    }
                }
                Button { editing = XtreamAccount(name: "", server: "", username: "", password: "") } label: {
                    Label(state.text("إضافة حساب", "Add account"), systemImage: "plus")
                }
            }
        }
        .navigationTitle(state.text("اكستريم كود", "Xtream Codes"))
        .sheet(item: $editing) { account in XtreamAccountEditor(account: account) }
        .confirmationDialog(state.text("حذف هذا الحساب؟", "Delete this account?"),
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button(state.text("حذف", "Delete"), role: .destructive) {
                if let account = pendingDelete {
                    do { try store.delete(account.id) } catch { failure = true }
                }
                pendingDelete = nil
            }
        }
        .alert(state.text("تعذّر حذف الحساب بأمان. أعد المحاولة.", "Could not securely delete the account. Try again."),
               isPresented: $failure) { Button(state.text("حسنًا", "OK"), role: .cancel) {} }
        .onAppear { store.reload() }
        .onChange(of: phase) { _, value in if value == .active { store.reload() } }
    }
}

struct XtreamAccountEditor: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State var account: XtreamAccount
    @State private var failed = false
    var body: some View {
        NavigationStack {
            Form {
                TextField(state.text("اسم الاشتراك", "Subscription name"), text: $account.name)
                TextField(state.text("عنوان الخادم HTTPS", "HTTPS server address"), text: $account.server)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField(state.text("اسم المستخدم", "Username"), text: $account.username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField(state.text("كلمة المرور", "Password"), text: $account.password)
                Text(state.text("تُحفظ بيانات الحساب في سلسلة مفاتيح هذا الجهاز. حفظ الحساب لا يتحقق من الاشتراك أو تشغيل القنوات.",
                                "Account details stay in this device's Keychain. Saving does not verify your subscription or channel playback."))
                    .font(.caption).foregroundStyle(.secondary)
                if failed { Text(state.text("تعذّر حفظ الحساب بأمان. أعد المحاولة.", "Could not securely save the account. Try again.")).foregroundStyle(.red) }
            }
            .navigationTitle(state.text("حساب IPTV", "IPTV account"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(state.text("إلغاء", "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(state.text("حفظ", "Save")) {
                        account.name = String(account.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
                        account.server = account.server.trimmingCharacters(in: .whitespacesAndNewlines)
                        do { try XtreamAccountStore.shared.save(account); dismiss() } catch { failed = true }
                    }.disabled(account.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                               XtreamAccountStore.serverURL(account.server) == nil ||
                               account.username.isEmpty || account.password.isEmpty)
                }
            }
        }
    }
}
