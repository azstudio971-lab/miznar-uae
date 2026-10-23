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
        return .init(title: title, subtitle: localFilename == nil ? tr("مصدر إنترنت", "Internet source") : tr("ملف مستورد", "Imported file"), url: url, isLive: isLive, artworkURL: localFilename == nil ? nil : MediaLibrary.shared.thumbnailURL(id), sourceKey: sourceKey)
    }
}

final class MediaLibrary: ObservableObject {
    static let shared = MediaLibrary()
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Media", isDirectory: true)
    }
    @Published private(set) var items: [LibraryMedia] = []
    @Published private(set) var playlists: [MediaPlaylist] = []
    @Published var error: String?
    @Published var importSummary: String?
    @Published var importProgress: Double?
    private var writable = true
    private var metadata: URL { Self.directory.appendingPathComponent("library.json") }

    private init() {
        do {
            let legacy = Self.directory.deletingLastPathComponent().appendingPathComponent("MediaLibrary", isDirectory: true)
            if !FileManager.default.fileExists(atPath: Self.directory.path), FileManager.default.fileExists(atPath: legacy.path) {
                // Copy once; retain the old library unchanged for rollback.
                try FileManager.default.copyItem(at: legacy, to: Self.directory)
            }
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: metadata.path) {
                items = try JSONDecoder().decode([LibraryMedia].self, from: Data(contentsOf: metadata))
            }
            let lists = Self.directory.appendingPathComponent("playlists.json")
            if FileManager.default.fileExists(atPath: lists.path) { playlists = try JSONDecoder().decode([MediaPlaylist].self, from: Data(contentsOf: lists)) }
        } catch {
            writable = false // Never overwrite unreadable user metadata with an empty library.
            self.error = error.localizedDescription
        }
    }

    func updatePlaylists(_ update: (inout [MediaPlaylist]) -> Void) {
        guard writable else { return }; update(&playlists); save()
    }

    func save() {
        guard writable else { return }
        do {
            try JSONEncoder().encode(items).write(to: metadata, options: .atomic)
            try JSONEncoder().encode(playlists).write(to: Self.directory.appendingPathComponent("playlists.json"), options: .atomic)
        }
        catch { self.error = error.localizedDescription }
    }

    func addRemote(title: String, url: URL, isLive: Bool, sourceKey: String? = nil) throws {
        guard writable, ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { throw M3UError.invalidURL }
        if items.contains(where: { $0.url == url }) { return }
        let item = LibraryMedia(title: title.isEmpty ? url.lastPathComponent : title, isLive: isLive, sourceKey: sourceKey)
        KeychainStore.set(url.absoluteString, for: "media-\(item.id.uuidString)")
        items.append(item)
        save()
    }

    @MainActor func importFiles(_ urls: [URL]) async {
        guard writable, importProgress == nil else { return }
        importProgress = 0
        defer { importProgress = nil }
        var failures: [String] = []
        var success = 0
        importSummary = nil
        for (index, url) in urls.enumerated() {
            do { try await importFile(url); success += 1 }
            catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
            importProgress = Double(index + 1) / Double(max(1, urls.count))
        }
        importSummary = tr("تم استيراد \(success) ملف وسائط", "Imported \(success) media files")
        if !failures.isEmpty { error = failures.joined(separator: "\n") }
    }

    @MainActor func importFolders(_ roots: [URL]) async {
        guard importProgress == nil else { return }
        var urls: [URL] = []
        for root in roots {
            let access = root.startAccessingSecurityScopedResource()
            defer { if access { root.stopAccessingSecurityScopedResource() } }
            let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            urls = enumerator.compactMap { $0 as? URL }.filter { url in
                let values = try? url.resourceValues(forKeys: Set(keys))
                return values?.isRegularFile == true && values?.isSymbolicLink != true && ["mp4", "mov", "m4v", "mp3", "m4a", "aac", "wav", "aiff", "mkv", "avi", "webm", "flac", "ogg", "ac3", "dts", "ts"].contains(url.pathExtension.lowercased())
            }.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            let before = Set(items.map(\.id))
            await importFiles(urls)
            let imported = items.filter { !before.contains($0.id) }.map(\.id)
            if !imported.isEmpty {
                MediaFolders.shared.create(root.lastPathComponent)
                if let folder = MediaFolders.shared.folders.last { MediaFolders.shared.setMembers(imported, in: folder.id) }
                createPlaylist(root.lastPathComponent)
                if let list = playlists.last { setMembers(imported, in: list.id) }
            }
        }
    }

    @MainActor func importFile(_ url: URL) async throws {
        guard writable else { throw CocoaError(.fileWriteNoPermission) }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        var item = LibraryMedia(title: url.deletingPathExtension().lastPathComponent)
        let filename = item.id.uuidString + "." + url.pathExtension
        let destination = Self.directory.appendingPathComponent(filename)
        let required = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let free = (try? Self.directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage) ?? Int64.max
        guard Int64(required) < free else { throw CocoaError(.fileWriteOutOfSpace) }
        // File copy is off the UI thread; picker originals are never modified.
        try await Task.detached(priority: .userInitiated) {
            try FileManager.default.copyItem(at: url, to: destination)
        }.value
        do {
            let asset = AVURLAsset(url: destination)
            let nativePlayable = (try? await asset.load(.isPlayable)) == true
            let softwareFormat = ["mkv", "avi", "webm", "flac", "ogg", "ac3", "dts", "ts"].contains(url.pathExtension.lowercased())
            guard nativePlayable || (softwareFormat && PlayerPreferences.text("softwareDecoding", "auto") != "never") else { throw MediaImportError.unsupported }
            item.localFilename = filename
            if nativePlayable {
                let duration = try await asset.load(.duration).seconds
                item.duration = duration.isFinite ? duration : nil
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 320, height: 180)
                if let (cgImage, _) = try? await generator.image(at: .zero), let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.75) {
                    try? data.write(to: thumbnailURL(item.id), options: .atomic)
                }
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
    func toggleFavorite(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].favorite.toggle()
        save()
    }
    func record(url: URL, position: Double, duration: Double? = nil) {
        guard position.isFinite, let index = items.firstIndex(where: { $0.url == url }) else { return }
        if let duration, duration.isFinite, duration > 0 { items[index].duration = duration }
        items[index].position = max(0, position)
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
            for index in playlists.indices { playlists[index].itemIDs.removeAll { $0 == id } }
            items.removeAll { $0.id == id }
            save()
        } catch { self.error = error.localizedDescription }
    }
    func removeCachedSource(_ sourceKey: String) {
        let ids = items.filter { $0.sourceKey == sourceKey }.map(\.id)
        for id in ids { remove(id) }
    }
    var importedBytes: Int64 {
        items.compactMap { $0.localFilename }.reduce(0) { sum, filename in
            let attributes = try? FileManager.default.attributesOfItem(atPath: Self.directory.appendingPathComponent(filename).path)
            return sum + ((attributes?[.size] as? NSNumber)?.int64Value ?? 0)
        }
    }
}
