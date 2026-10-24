import Foundation
import Security
import Combine

// MARK: - Keychain (كلمات مرور Xtream)

enum KeychainStore {
    private static let service = "app.wudcar.xtream"

    private static func baseQuery(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    static func set(_ value: String, for key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
        var add = baseQuery(key)
        add[kSecValueData as String] = Data(value.utf8)
        // متاح بعد أول فتح للقفل: CarPlay يقدر يشغّل القنوات والهاتف مقفل
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
    }
}

// MARK: - الحساب

struct XtreamAccount: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var server: String
    var username: String

    var password: String? { KeychainStore.get(id.uuidString) }

    /// يقبل: example.com:8080 أو http://example.com:8080/ أو رابط ينتهي بـ player_api.php
    var baseURL: URL? { Self.normalize(server) }

    var displayHost: String { baseURL?.host ?? server }

    static func normalize(_ raw: String) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.lowercased().hasPrefix("http://") && !text.lowercased().hasPrefix("https://") {
            text = "http://" + text
        }
        if let range = text.range(of: "/player_api.php") { text = String(text[..<range.lowerBound]) }
        while text.hasSuffix("/") { text.removeLast() }
        guard let url = URL(string: text), url.host != nil else { return nil }
        return url
    }
}

// MARK: - تخزين الحسابات (البيانات بدون كلمة المرور في UserDefaults، وكلمة المرور في Keychain)

final class XtreamStore: ObservableObject {
    static let shared = XtreamStore()

    @Published private(set) var accounts: [XtreamAccount] = []
    private let storageKey = "wd.xtream.accounts.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([XtreamAccount].self, from: data) {
            accounts = saved
        }
    }

    func save(_ account: XtreamAccount, password: String?) {
        if let password, !password.isEmpty {
            KeychainStore.set(password, for: account.id.uuidString)
        }
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
        } else {
            accounts.append(account)
        }
        persist()
    }

    func remove(_ id: UUID) {
        MediaLibrary.shared.removeCachedSource("xtream-\(id)")
        KeychainStore.delete(id.uuidString)
        accounts.removeAll { $0.id == id }
        persist()
    }

    func removeAll() {
        accounts.forEach { MediaLibrary.shared.removeCachedSource("xtream-\($0.id)"); KeychainStore.delete($0.id.uuidString) }
        accounts = []
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - المحتوى

enum XtreamKind: String, CaseIterable, Identifiable {
    case live, movies
    var id: String { rawValue }
    var title: String { self == .live ? tr("البث المباشر", "Live TV") : tr("الأفلام", "Movies") }
    var symbol: String { self == .live ? "dot.radiowaves.left.and.right" : "film" }
}

struct XtreamCategory: Identifiable, Hashable {
    let id: String
    let name: String
}

struct XtreamStream: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: URL?
    let containerExtension: String?
    let kind: XtreamKind
}

struct XtreamAccountInfo {
    let status: String
    let expiry: Date?
    let maxConnections: String?
}

enum XtreamError: LocalizedError {
    case invalidServer, missingPassword, unauthorized, expired, badResponse, network(String)

    var errorDescription: String? {
        switch self {
        case .invalidServer: return tr("عنوان السيرفر غير صحيح.", "The server address is not valid.")
        case .missingPassword: return tr("كلمة المرور غير محفوظة. عدّل الحساب وأدخلها.", "Password is missing. Edit the account and enter it.")
        case .unauthorized: return tr("اسم المستخدم أو كلمة المرور غير صحيحة.", "Wrong username or password.")
        case .expired: return tr("الاشتراك منتهي أو موقوف.", "The subscription is expired or disabled.")
        case .badResponse: return tr("رد غير متوقع من السيرفر.", "Unexpected response from the server.")
        case .network(let message): return tr("تعذّر الاتصال بالسيرفر: ", "Could not reach the server: ") + message
        }
    }
}
