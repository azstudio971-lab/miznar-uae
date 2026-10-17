import Foundation
import Combine

/// M3U playlist metadata stays in UserDefaults; signed URLs and access tokens stay in Keychain.
struct M3UPlaylist: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String

    var playlistURL: URL? {
        guard let raw = KeychainStore.get("m3u-\(id.uuidString)") else { return nil }
        return URL(string: raw)
    }
}

struct M3UEntry: Identifiable, Hashable {
    var id: String { url.absoluteString }
    let title: String
    let url: URL
    let group: String
    let logo: URL?
}

/// Small, bounded Extended M3U parser. Supports EXTINF titles, tvg-logo and group-title.
enum M3UParser {
    static func parse(_ data: Data) throws -> [M3UEntry] {
        guard data.count <= 15 * 1024 * 1024 else { throw M3UError.tooLarge }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw M3UError.invalidText
        }
        var title: String?
        var group = ""
        var logo: URL?
        var entries: [M3UEntry] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("#EXTINF:") {
                let metadata = String(line.dropFirst(8))
                if let comma = metadata.firstIndex(of: ",") {
                    let head = String(metadata[..<comma])
                    let name = String(metadata[metadata.index(after: comma)...]).trimmingCharacters(in: .whitespaces)
                    title = name.isEmpty ? nil : name
                    group = attribute("group-title", in: head) ?? ""
                    logo = attribute("tvg-logo", in: head).flatMap(URL.init(string:))
                } else {
                    title = nil
                    group = ""
                    logo = nil
                }
            } else if line.hasPrefix("#EXTGRP:") {
                group = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
            } else if !line.isEmpty, !line.hasPrefix("#"), let url = URL(string: line),
                      let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil {
                entries.append(M3UEntry(title: title ?? url.lastPathComponent, url: url, group: group, logo: logo))
                title = nil
                group = ""
                logo = nil
            }
            if entries.count >= 3000 { break }
        }
        return entries
    }

    private static func attribute(_ name: String, in text: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: "(?:^|\\s)\(NSRegularExpression.escapedPattern(for: name))=\"([^\"]*)\""),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
}

enum M3UError: LocalizedError {
    case invalidURL, badResponse, invalidText, tooLarge

    var errorDescription: String? {
        switch self {
        case .invalidURL: return tr("رابط قائمة M3U غير صحيح.", "The M3U playlist URL is invalid.")
        case .badResponse: return tr("تعذّر تحميل قائمة M3U. تحقق من الرابط والاتصال.", "Could not load the M3U playlist. Check the URL and connection.")
        case .invalidText: return tr("صيغة القائمة غير مقروءة.", "The playlist format could not be read.")
        case .tooLarge: return tr("القائمة أكبر من الحد المسموح (15 ميغابايت).", "The playlist is larger than the 15 MB limit.")
        }
    }
}

final class M3UStore: ObservableObject {
    static let shared = M3UStore()
    @Published private(set) var playlists: [M3UPlaylist] = []
    private let storageKey = "wd.m3u.playlists.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([M3UPlaylist].self, from: data) {
            playlists = decoded
        }
    }

    func save(_ playlist: M3UPlaylist, url: URL) {
        KeychainStore.set(url.absoluteString, for: "m3u-\(playlist.id.uuidString)")
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            playlists[index] = playlist
        } else {
            playlists.append(playlist)
        }
        persist()
    }

    func remove(_ id: UUID) {
        KeychainStore.delete("m3u-\(id.uuidString)")
        UserDefaults.standard.removeObject(forKey: favoriteKey(id))
        playlists.removeAll { $0.id == id }
        persist()
    }

    func entries(for playlist: M3UPlaylist) async throws -> [M3UEntry] {
        guard let url = playlist.playlistURL,
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil else { throw M3UError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("WudCar/1.4.2", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw M3UError.badResponse
        }
        return try M3UParser.parse(data)
    }

    func isFavorite(_ entry: M3UEntry, in playlist: M3UPlaylist) -> Bool {
        favorites(for: playlist.id).contains(entry.id)
    }

    func toggleFavorite(_ entry: M3UEntry, in playlist: M3UPlaylist) {
        var values = favorites(for: playlist.id)
        if values.contains(entry.id) { values.remove(entry.id) } else { values.insert(entry.id) }
        UserDefaults.standard.set(Array(values), forKey: favoriteKey(playlist.id))
        objectWillChange.send()
    }

    func favorites(in playlist: M3UPlaylist, entries: [M3UEntry]) -> [M3UEntry] {
        let saved = favorites(for: playlist.id)
        return entries.filter { saved.contains($0.id) }
    }

    private func favorites(for id: UUID) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: favoriteKey(id)) ?? [])
    }

    private func favoriteKey(_ id: UUID) -> String { "wd.m3u.favorites.\(id.uuidString)" }

    private func persist() {
        if let data = try? JSONEncoder().encode(playlists) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
