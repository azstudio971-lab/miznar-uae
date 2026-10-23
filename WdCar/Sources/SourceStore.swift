import Foundation
import Combine
import CryptoKit

@MainActor final class SourceStore: ObservableObject {
    static let shared = SourceStore()
    @Published private(set) var sources: [MediaSource] = []
    @Published var error: String?
    @Published var progress: String?
    private let network: SourceNetwork
    private let customDirectory: URL?
    private var writable = true
    private var directory: URL { customDirectory ?? MediaLibrary.directory.appendingPathComponent("Sources", isDirectory: true) }
    private var index: URL { directory.appendingPathComponent("index.json") }
    init(network: SourceNetwork = SourceNetwork(), directory: URL? = nil) {
        self.network = network
        self.customDirectory = directory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: index.path) { sources = try JSONDecoder().decode([MediaSource].self, from: Data(contentsOf: index)) }
        } catch { writable = false; self.error = error.localizedDescription }
    }
    func credentials(_ source: MediaSource) -> SourceCredentials? {
        KeychainStore.get(source.secretKey).flatMap { $0.data(using: .utf8) }.flatMap { try? JSONDecoder().decode(SourceCredentials.self, from: $0) }
    }
    private func store(_ value: SourceCredentials, source: MediaSource) throws {
        let text = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        KeychainStore.set(text, for: source.secretKey)
        guard KeychainStore.get(source.secretKey) == text else { throw CocoaError(.fileWriteNoPermission) }
    }
    private func key(_ source: MediaSource, create: Bool) throws -> SymmetricKey {
        let name = source.secretKey + ".cacheKey"
        if let text = KeychainStore.get(name), let data = Data(base64Encoded: text), data.count == 32 { return SymmetricKey(data: data) }
        guard create else { throw CocoaError(.fileReadNoSuchFile) }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }; KeychainStore.set(data.base64EncodedString(), for: name)
        guard KeychainStore.get(name) == data.base64EncodedString() else { throw CocoaError(.fileWriteNoPermission) }; return key
    }
    private func cacheURL(_ source: MediaSource) -> URL { directory.appendingPathComponent(source.id.uuidString + ".sealed") }
    func cached(_ source: MediaSource) -> [SourceMedia] {
        do {
            let sealed = try AES.GCM.SealedBox(combined: Data(contentsOf: cacheURL(source)))
            let plain = try AES.GCM.open(sealed, using: key(source, create: false))
            return try JSONDecoder().decode([SourceMedia].self, from: plain)
        } catch { return [] }
    }
    private func saveCache(_ items: [SourceMedia], source: MediaSource) throws {
        let sealed = try AES.GCM.seal(JSONEncoder().encode(items), using: key(source, create: true))
        guard let data = sealed.combined else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: cacheURL(source), options: [.atomic, .completeFileProtection])
    }
    private func persist() throws {
        guard writable else { throw CocoaError(.fileWriteNoPermission) }
        try JSONEncoder().encode(sources).write(to: index, options: [.atomic, .completeFileProtection])
    }
    func add(name: String, kind: MediaSource.Kind, credentials: SourceCredentials) async throws -> MediaSource {
        guard writable else { throw CocoaError(.fileWriteNoPermission) }
        progress = tr("جارِ فحص القنوات…", "Checking channels…"); defer { progress = nil }
        var source = MediaSource(name: name.isEmpty ? kind.rawValue.capitalized : name, kind: kind)
        var secret = credentials
        if kind == .jellyfin || kind == .emby { secret = try await network.authenticate(kind, credentials: secret) }
        let items = try await load(source, secret: secret)
        guard !items.isEmpty else { throw SourceFailure.noItems }
        try store(secret, source: source)
        do {
            try saveCache(items, source: source)
            source.updated = Date(); source.count = items.count; sources.append(source); try persist()
            return source
        } catch {
            sources.removeAll { $0.id == source.id }; KeychainStore.delete(source.secretKey); KeychainStore.delete(source.secretKey + ".cacheKey"); try? FileManager.default.removeItem(at: cacheURL(source)); throw error
        }
    }
    func refresh(_ source: MediaSource) async throws {
        guard let secret = credentials(source) else { throw SourceFailure.authentication }
        progress = tr("جارِ فحص القنوات…", "Checking channels…"); defer { progress = nil }
        let items = try await load(source, secret: secret)
        try saveCache(items, source: source)
        if let index = sources.firstIndex(where: { $0.id == source.id }) { sources[index].updated = Date(); sources[index].count = items.count }; try persist()
    }
    func browse(_ source: MediaSource, parent: String? = nil) async throws -> [SourceMedia] {
        guard let secret = credentials(source) else { throw SourceFailure.authentication }
        if [.jellyfin, .emby, .plex].contains(source.kind) { return try await network.browse(source, credentials: secret, parent: parent) }
        return cached(source)
    }
    private func load(_ source: MediaSource, secret: SourceCredentials) async throws -> [SourceMedia] {
        switch source.kind {
        case .pasted: return try SourceInput.playlist(secret.text)
        case .config: throw SourceFailure.badResponse // Configs are expanded transaction-by-transaction by addConfig.
        case .stream:
            let url = try SourceInput.url(secret.address)
            let response = try await network.streamResponse(url)
            if ["text/html", "application/json"].contains(response.mimeType?.lowercased() ?? "") { throw SourceFailure.webPage }
            return [SourceMedia(id: url.absoluteString, title: source.name, url: url, isLive: url.pathExtension.lowercased() == "m3u8")]
        case .playlist:
            let url = try SourceInput.url(secret.address)
            let (data, response) = try await network.data(url)
            guard !(response.mimeType ?? "").lowercased().contains("text/html") else { throw SourceFailure.webPage }
            let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
            if text.contains("#EXT-X-TARGETDURATION") || text.contains("#EXT-X-STREAM-INF") { return [SourceMedia(id: url.absoluteString, title: source.name, url: url, isLive: true)] }
            return try SourceInput.playlist(text)
        case .jellyfin, .emby, .plex: return try await network.browse(source, credentials: secret)
        }
    }
    func addConfig(_ text: String, name: String) async -> (added: Int, failed: Int) {
        let urls = SourceInput.links(text)
        guard text.utf8.count <= 15 * 1024 * 1024, urls.count <= 100 else { error = SourceFailure.tooLarge.localizedDescription; return (0, max(1, urls.count)) }
        var added = 0; var failed = 0
        for (index, url) in urls.enumerated() {
            do {
                if sources.contains(where: { credentials($0)?.address == url.absoluteString }) { continue }
                let kind: MediaSource.Kind = SourceInput.smartKind(url.absoluteString)
                _ = try await add(name: name.isEmpty ? url.host ?? "Source" : "\(name) \(index + 1)", kind: kind, credentials: SourceCredentials(address: url.absoluteString)); added += 1
            } catch { failed += 1 }
        }
        return (added, failed)
    }
    func rename(_ source: MediaSource, name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let index = sources.firstIndex(where: { $0.id == source.id }) else { return }
        sources[index].name = name; do { try persist() } catch { self.error = error.localizedDescription }
    }
    func hide(_ source: MediaSource) {
        guard let index = sources.firstIndex(where: { $0.id == source.id }) else { return }; sources[index].hidden.toggle(); do { try persist() } catch { self.error = error.localizedDescription }
    }
    func remove(_ source: MediaSource) {
        do {
            if FileManager.default.fileExists(atPath: cacheURL(source).path) { try FileManager.default.removeItem(at: cacheURL(source)) }
            sources.removeAll { $0.id == source.id }; try persist()
            KeychainStore.delete(source.secretKey); KeychainStore.delete(source.secretKey + ".cacheKey")
            MediaLibrary.shared.removeCachedSource(source.id.uuidString)
        } catch { self.error = error.localizedDescription }
    }
    func play(_ media: SourceMedia, source: MediaSource, onPhone: Bool) {
        guard let url = media.url else { return }
        do {
            try MediaLibrary.shared.addRemote(title: media.title, url: url, isLive: media.isLive, sourceKey: source.id.uuidString)
            let saved = MediaLibrary.shared.items.first { $0.url == url }
            if let saved, saved.lastPlayed == nil, media.position > 0 { MediaLibrary.shared.record(url: url, position: media.position, duration: media.duration) }
            PlaybackManager.shared.playQueue([.init(title: media.title, subtitle: source.name, url: url, isLive: media.isLive, artworkURL: media.artwork, sourceKey: source.id.uuidString)], startingAt: url, presentOnPhone: onPhone)
        } catch { self.error = error.localizedDescription }
    }
}
