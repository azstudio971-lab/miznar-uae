import Foundation

struct MediaSource: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable { case playlist, pasted, config, stream, jellyfin, emby, plex }
    var id = UUID()
    var name: String
    var kind: Kind
    var updated: Date?
    var count = 0
    var hidden = false
    var secretKey: String { "wd.source." + id.uuidString }
}
struct SourceMedia: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var url: URL?
    var artwork: URL?
    var group: String = ""
    var folder = false
    var position: Double = 0
    var duration: Double = 0
    var isLive = false
}
struct SourceCredentials: Codable {
    var address = ""
    var username = ""
    var password = ""
    var token = ""
    var userID = ""
    var text = ""
}
enum SourceFailure: LocalizedError {
    case invalidURL, webPage, noItems, tooLarge, authentication, network, badResponse
    var errorDescription: String? {
        switch self {
        case .invalidURL: return tr("رابط غير صالح. استخدم HTTP أو HTTPS.", "Invalid URL. Use HTTP or HTTPS.")
        case .webPage: return tr("الرابط يعيد صفحة ويب وليس قائمة أو بثاً.", "The URL returns a web page, not a playlist or stream.")
        case .noItems: return tr("لا توجد قنوات أو وسائط صالحة.", "No valid channels or media were found.")
        case .tooLarge: return tr("القائمة كبيرة جداً؛ الحد 15 ميغابايت.", "The playlist exceeds the 15 MB limit.")
        case .authentication: return tr("اسم المستخدم أو كلمة المرور غير صحيحة، أو انتهت الجلسة.", "Incorrect username/password or an expired session.")
        case .network: return tr("الخادم لا يستجيب. تحقق من العنوان والاتصال وإذن الشبكة المحلية في الإعدادات.", "The server is unavailable. Check its address, your connection and Local Network permission in Settings.")
        case .badResponse: return tr("استجابة الخادم غير متوقعة.", "Unexpected server response.")
        }
    }
}
enum SourceInput {
    static func url(_ raw: String) throws -> URL {
        guard let u = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(u.scheme?.lowercased() ?? ""), let host = u.host, !host.isEmpty else { throw SourceFailure.invalidURL }
        return u
    }
    static func links(_ text: String) -> [URL] {
        guard let expression = try? NSRegularExpression(pattern: "https?://[^\\s\\\"<>\\[\\]{}]+", options: .caseInsensitive) else { return [] }
        var seen = Set<String>()
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            guard let range = Range($0.range, in: text), let url = try? url(String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: ",;"))), seen.insert(url.absoluteString).inserted else { return nil }; return url
        }
    }
    static func playlist(_ text: String) throws -> [SourceMedia] {
        guard text.utf8.count <= 15 * 1024 * 1024 else { throw SourceFailure.tooLarge }
        let lower = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.hasPrefix("<!doctype html"), !lower.hasPrefix("<html") else { throw SourceFailure.webPage }
        let entries = try M3UParser.parse(Data(text.utf8))
        var seen = Set<String>()
        let result = entries.filter { seen.insert($0.id).inserted }.map { SourceMedia(id: $0.id, title: $0.title, url: $0.url, artwork: $0.logo, group: $0.group, isLive: true) }
        guard !result.isEmpty else { throw SourceFailure.noItems }; return result
    }
    static func smartKind(_ text: String) -> MediaSource.Kind {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#EXTM3U") { return .pasted }
        let links = links(text)
        if links.count != 1 || (try? url(text)) == nil { return .config }
        return links[0].pathExtension.lowercased() == "m3u" || links[0].path.lowercased().contains("get.php") ? .playlist : .stream
    }
}
