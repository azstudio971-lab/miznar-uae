import Foundation
import AVFoundation
import UIKit
import Combine

struct LibraryMedia: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    // Network URLs stay in the existing Keychain, never in library metadata.
    var localFilename: String?
    var duration: Double?
    var isAudio = false
    var favorite = false
    var position: Double = 0
    var lastPlayed: Date?
    var added = Date()
    var isLive = false
    var sourceKey: String?

    var url: URL? {
        if let localFilename { return MediaLibrary.directory.appendingPathComponent(localFilename) }
        return KeychainStore.get("media-\(id.uuidString)").flatMap(URL.init(string:))
    }
    var playbackItem: PlaybackManager.Item? {
        guard let url else { return nil }
        return .init(title: title, subtitle: localFilename == nil ? tr("مصدر إنترنت", "Internet source") : tr("ملف مستورد", "Imported file"), url: url, isLive: isLive, artworkURL: localFilename == nil ? KeychainStore.get("media-art-\(id)").flatMap(URL.init(string:)) : MediaLibrary.shared.thumbnailURL(id), sourceKey: sourceKey)
    }
}

final class MediaLibrary: ObservableObject {
    static let shared = MediaLibrary()
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Media", isDirectory: true)
    }
    @Published private(set) var items: [LibraryMedia] = []
    @Published var error: String?
    @Published var importMessage: String?
    @Published private(set) var playlists: [MediaPlaylist] = []
    @Published var importProgress: Double?
    private var writable = true
    private var playlistsURL: URL { Self.directory.appendingPathComponent("playlists.json") }
    private var metadata: URL { Self.directory.appendingPathComponent("library.json") }

    private init() {
        do {
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: metadata.path) {
                items = try JSONDecoder().decode([LibraryMedia].self, from: Data(contentsOf: metadata))
            }
            if FileManager.default.fileExists(atPath: playlistsURL.path) {
                playlists = try JSONDecoder().decode([MediaPlaylist].self, from: Data(contentsOf: playlistsURL))
            }
        } catch {
            writable = false // Never overwrite unreadable user metadata with an empty library.
            self.error = error.localizedDescription
        }
    }

    func save() {
        guard writable else { return }
        do {
            try JSONEncoder().encode(items).write(to: metadata, options: .atomic)
            try JSONEncoder().encode(playlists).write(to: playlistsURL, options: .atomic)
        }
        catch { self.error = error.localizedDescription }
    }

    func addRemote(title: String, url: URL, isLive: Bool, sourceKey: String? = nil, artworkURL: URL? = nil) throws {
        guard writable, ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { throw M3UError.invalidURL }
        if let index = items.firstIndex(where: { $0.url == url }) {
            if let sourceKey, items[index].sourceKey != sourceKey { items[index].sourceKey = sourceKey; save() }
            if let artworkURL { KeychainStore.set(artworkURL.absoluteString, for: "media-art-\(items[index].id)") }
            return
        }
        let item = LibraryMedia(title: title.isEmpty ? url.lastPathComponent : title, isLive: isLive, sourceKey: sourceKey)
        KeychainStore.set(url.absoluteString, for: "media-\(item.id.uuidString)")
        if let artworkURL { KeychainStore.set(artworkURL.absoluteString, for: "media-art-\(item.id)") }
        items.append(item)
        save()
    }

    @MainActor func importFiles(_ urls: [URL]) async {
        guard writable, importProgress == nil else { return }
        error = nil
        importMessage = nil
        importProgress = 0
        defer { importProgress = nil }
        var failures: [String] = []
        let before = items.count
        for (index, url) in urls.enumerated() {
            do { try await importFile(url) }
            catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
            importProgress = Double(index + 1) / Double(max(1, urls.count))
        }
        importMessage = tr("تم استيراد \(items.count - before) عنصر", "Imported \(items.count - before) items")
        if !failures.isEmpty { error = tr("تعذّر استيراد هذه الملفات؛ تحقق من الصيغة ودعم النظام:\n", "Could not import these files; check format and system support:\n") + failures.joined(separator: "\n") }
    }

    @MainActor func importFile(_ url: URL) async throws {
        guard writable else { throw CocoaError(.fileWriteNoPermission) }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            let children = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            var failed: [String] = []
            for child in children {
                do { try await importFile(child) }
                catch { failed.append(child.lastPathComponent) }
            }
            if !failed.isEmpty { error = tr("ملفات غير مدعومة: ", "Unsupported files: ") + failed.joined(separator: ", ") }
            return
        }
        var item = LibraryMedia(title: url.deletingPathExtension().lastPathComponent)
        let filename = item.id.uuidString + "." + url.pathExtension
        let destination = Self.directory.appendingPathComponent(filename)
        // File copy is off the UI thread; picker originals are never modified.
        try await Task.detached(priority: .userInitiated) {
            try FileManager.default.copyItem(at: url, to: destination)
        }.value
        do {
            let asset = AVURLAsset(url: destination)
            guard try await asset.load(.isPlayable) else { throw CocoaError(.fileReadCorruptFile) }
            let duration = try await asset.load(.duration).seconds
            item.duration = duration.isFinite ? duration : nil
            item.isAudio = try await asset.loadTracks(withMediaType: .video).isEmpty
            item.localFilename = filename
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 320, height: 180)
            if let (cgImage, _) = try? await generator.image(at: .zero),
               let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.75) {
                try? data.write(to: thumbnailURL(item.id), options: .atomic)
            }
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var imported = destination
            try imported.setResourceValues(values)
            items.append(item)
            save()
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    func thumbnailURL(_ id: UUID) -> URL { Self.directory.appendingPathComponent(id.uuidString + ".jpg") }
    func setFavorite(url: URL, favorite: Bool) {
        guard let index = items.firstIndex(where: { $0.url == url }) else { return }
        items[index].favorite = favorite; save()
    }
    func toggleFavorite(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].favorite.toggle()
        save()
    }
    func record(url: URL, position: Double, duration: Double? = nil) {
        guard position.isFinite, let index = items.firstIndex(where: { $0.url == url }) else { return }
        items[index].position = max(0, position)
        if let duration, duration.isFinite, duration > 0 { items[index].duration = duration }
        items[index].lastPlayed = Date()
        save()
    }
    func remove(_ id: UUID) {
        guard writable, let item = items.first(where: { $0.id == id }) else { return }
        do {
            if PlaybackManager.shared.current?.url == item.url { PlaybackManager.shared.stop() }
            if let filename = item.localFilename {
                let url = Self.directory.appendingPathComponent(filename)
                if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            }
            try? FileManager.default.removeItem(at: thumbnailURL(id))
            KeychainStore.delete("media-\(id.uuidString)")
            KeychainStore.delete("media-art-\(id)")
            items.removeAll { $0.id == id }
            for index in playlists.indices { playlists[index].itemIDs.removeAll { $0 == id } }
            save()
        } catch { self.error = error.localizedDescription }
    }
    func removeCachedSource(_ sourceKey: String) {
        let ids = items.filter { $0.sourceKey == sourceKey }.map(\.id)
        for id in ids { remove(id) }
    }
    var continueWatching: [LibraryMedia] {
        items.filter { $0.lastPlayed != nil && ($0.isLive || $0.position > 0) }.sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
    }
    func createPlaylist(_ title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard writable, !title.isEmpty else { return }
        playlists.append(MediaPlaylist(title: title)); save()
    }
    func updatePlaylist(_ playlist: MediaPlaylist) {
        guard writable, let i = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[i] = playlist; save()
    }
    func removePlaylist(_ id: UUID) { guard writable else { return }; playlists.removeAll { $0.id == id }; save() }
    func contents(_ playlist: MediaPlaylist) -> [LibraryMedia] { playlist.itemIDs.compactMap { id in items.first { $0.id == id } } }
    func addToPlaylist(_ id: UUID, item: LibraryMedia) {
        guard var playlist = playlists.first(where: { $0.id == id }), !playlist.itemIDs.contains(item.id) else { return }
        playlist.itemIDs.append(item.id); updatePlaylist(playlist)
    }
    var importedBytes: Int64 {
        items.compactMap { $0.localFilename }.reduce(0) { sum, filename in
            let attributes = try? FileManager.default.attributesOfItem(atPath: Self.directory.appendingPathComponent(filename).path)
            return sum + ((attributes?[.size] as? NSNumber)?.int64Value ?? 0)
        }
    }
}

struct MediaPlaylist: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var itemIDs: [UUID] = []
    var favorite = false
}
