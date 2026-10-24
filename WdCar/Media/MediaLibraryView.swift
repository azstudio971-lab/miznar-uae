import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject private var library = MediaLibrary.shared
    @State private var picker: Int?
    @State private var newPlaylist = false
    @State private var title = ""
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Menu {
                        Button(tr("من الصور", "From Photos")) { picker = 0 }
                        Button(tr("من الملفات", "From Files")) { picker = 1 }
                        Button(tr("مجلد كامل", "Entire folder")) { picker = 2 }
                    } label: { Label(tr("إضافة وسائط", "Add media"), systemImage: "plus") }
                    .disabled(library.importProgress != nil)
                    if let progress = library.importProgress { ProgressView(value: progress) }
                    if let message = library.importMessage { Text(message).font(.footnote) }
                }
                mediaSection(tr("متابعة المشاهدة", "Continue watching"), library.continueWatching)
                Section(tr("قوائم التشغيل", "Playlists")) {
                    ForEach(library.playlists) { playlist in
                        NavigationLink { MediaPlaylistView(id: playlist.id) } label: {
                            Label(playlist.title, systemImage: playlist.favorite ? "star.fill" : "list.bullet")
                        }
                    }.onDelete { offsets in for i in offsets { library.removePlaylist(library.playlists[i].id) } }
                    Button(tr("إنشاء قائمة تشغيل", "Create playlist")) { title = ""; newPlaylist = true }
                }
                mediaSection(tr("الفيديوهات", "Videos"), library.items.filter { $0.localFilename != nil && !$0.isAudio })
                mediaSection(tr("الصوتيات", "Audio"), library.items.filter { $0.localFilename != nil && $0.isAudio })
                Section(tr("القنوات", "Channels")) {
                    NavigationLink(tr("القنوات المفضلة", "Favorite channels")) { MediaItemsList(title: tr("القنوات المفضلة", "Favorite channels"), items: library.items.filter { $0.localFilename == nil && $0.favorite }) }
                    NavigationLink("M3U IPTV Player") { XtreamHomeView() }
                }
                mediaSection(tr("المضافة حديثاً", "Recently added"), Array(library.items.sorted { $0.added > $1.added }.prefix(20)))
            }
            .navigationTitle(tr("المكتبة", "Library"))
            .sheet(isPresented: Binding(get: { picker != nil }, set: { if !$0 { picker = nil } })) {
                if picker == 0 { LibraryPhotoPicker { picker = nil } }
                else { LibraryDocumentPicker(folder: picker == 2) { urls in picker = nil; Task { await library.importFiles(urls) } } }
            }
            .alert(tr("قائمة جديدة", "New playlist"), isPresented: $newPlaylist) {
                TextField(tr("الاسم", "Name"), text: $title)
                Button(tr("إنشاء", "Create")) { library.createPlaylist(title) }
                Button(tr("إلغاء", "Cancel"), role: .cancel) {}
            }
            .alert(tr("تعذّر الاستيراد", "Import failed"), isPresented: Binding(get: { library.error != nil }, set: { if !$0 { library.error = nil } })) {
                Button(tr("حسناً", "OK")) { library.error = nil }
            } message: { Text(library.error ?? "") }
        }
    }
    @ViewBuilder private func mediaSection(_ title: String, _ items: [LibraryMedia]) -> some View {
        if !items.isEmpty { Section(title) { ForEach(items) { MediaLibraryRow(item: $0, queue: items) } } }
    }
}

struct MediaItemsList: View {
    let title: String
    let items: [LibraryMedia]
    var body: some View { List(items) { MediaLibraryRow(item: $0, queue: items) }.navigationTitle(title) }
}

struct MediaLibraryRow: View {
    let item: LibraryMedia
    let queue: [LibraryMedia]
    @ObservedObject private var library = MediaLibrary.shared
    var body: some View {
        Button { play(true) } label: {
            HStack {
                if let image = UIImage(contentsOfFile: library.thumbnailURL(item.id).path) {
                    Image(uiImage: image).resizable().scaledToFit().frame(width: 64, height: 42)
                } else { Image(systemName: item.isAudio ? "waveform" : "play.rectangle").frame(width: 64) }
                VStack(alignment: .leading) {
                    Text(item.title).foregroundStyle(.primary)
                    if let duration = item.duration, duration > 0 {
                        Text(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond))).font(.caption).foregroundStyle(.secondary)
                        if item.position > 0 { ProgressView(value: min(1, item.position / duration)) }
                    }
                }
                if item.favorite { Image(systemName: "star.fill") }
            }
        }.contextMenu {
            Button(tr("تشغيل على الهاتف", "Play on iPhone")) { play(true) }
            Button(tr("تشغيل على شاشة السيارة", "Play on car display")) { play(false) }
            Button(tr("المفضلة", "Favorite")) { library.toggleFavorite(item.id) }
            Menu(tr("إضافة إلى قائمة", "Add to playlist")) {
                ForEach(library.playlists) { playlist in Button(playlist.title) { library.addToPlaylist(playlist.id, item: item) } }
            }
            Button(tr("حذف من المكتبة", "Delete from library"), role: .destructive) { library.remove(item.id) }
        }
    }
    private func play(_ phone: Bool) { PlaybackManager.shared.playQueue(queue.compactMap(\.playbackItem), startingAt: item.url, presentOnPhone: phone) }
}

struct MediaPlaylistView: View {
    let id: UUID
    @ObservedObject private var library = MediaLibrary.shared
    @State private var rename = false
    @State private var title = ""
    private var playlist: MediaPlaylist? { library.playlists.first { $0.id == id } }
    var body: some View {
        List {
            if let playlist {
                Section {
                    ForEach(library.contents(playlist)) { MediaLibraryRow(item: $0, queue: library.contents(playlist)) }
                        .onMove { source, destination in var value = playlist; value.itemIDs.move(fromOffsets: source, toOffset: destination); library.updatePlaylist(value) }
                        .onDelete { offsets in var value = playlist; value.itemIDs.remove(atOffsets: offsets); library.updatePlaylist(value) }
                }
                Section(tr("إضافة عناصر", "Add items")) {
                    ForEach(library.items.filter { !playlist.itemIDs.contains($0.id) }) { item in
                        Button(item.title) { library.addToPlaylist(id, item: item) }
                    }
                    Text(tr("لإضافة قناة: افتح M3U IPTV Player ثم قائمة القناة واختر إضافتها إلى قائمة تشغيل.", "To add a channel, open its menu in M3U IPTV Player and choose Add to playlist.")).font(.footnote)
                }
            }
        }.navigationTitle(playlist?.title ?? "")
            .toolbar {
                EditButton()
                Menu {
                    Button(tr("إعادة تسمية", "Rename")) { title = playlist?.title ?? ""; rename = true }
                    Button(tr("المفضلة", "Favorite")) { if var p = playlist { p.favorite.toggle(); library.updatePlaylist(p) } }
                } label: { Image(systemName: "ellipsis.circle") }
            }
            .alert(tr("اسم القائمة", "Playlist name"), isPresented: $rename) {
                TextField(tr("الاسم", "Name"), text: $title)
                Button(tr("حفظ", "Save")) { if var p = playlist, !title.trimmingCharacters(in: .whitespaces).isEmpty { p.title = title; library.updatePlaylist(p) } }
                Button(tr("إلغاء", "Cancel"), role: .cancel) {}
            }
    }
}

struct LibraryDocumentPicker: UIViewControllerRepresentable {
    var folder = false
    let completion: ([URL]) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = folder ? [.folder] : [.movie, .video, .mpeg4Movie, .quickTimeMovie, .audio, .mp3, .mpeg4Audio]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
        picker.allowsMultipleSelection = true; picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: ([URL]) -> Void
        init(_ completion: @escaping ([URL]) -> Void) { self.completion = completion }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { completion(urls) }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { completion([]) }
    }
}

struct LibraryPhotoPicker: UIViewControllerRepresentable {
    let dismiss: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(dismiss) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(); config.filter = .videos; config.selectionLimit = 0
        let picker = PHPickerViewController(configuration: config); picker.delegate = context.coordinator; return picker
    }
    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let dismiss: () -> Void
        init(_ dismiss: @escaping () -> Void) { self.dismiss = dismiss }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            dismiss()
            Task { @MainActor in
                var urls: [URL] = []
                for result in results {
                    do {
                        let url: URL = try await withCheckedThrowingContinuation { continuation in
                            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                                do {
                                    guard let url else { throw error ?? CocoaError(.fileReadUnknown) }
                                    let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
                                    try FileManager.default.copyItem(at: url, to: copy)
                                    continuation.resume(returning: copy)
                                } catch { continuation.resume(throwing: error) }
                            }
                        }
                        urls.append(url)
                    } catch { MediaLibrary.shared.error = error.localizedDescription }
                }
                await MediaLibrary.shared.importFiles(urls)
                for url in urls { try? FileManager.default.removeItem(at: url) }
            }
        }
    }
}

struct ChannelLibraryMenu: View {
    let title: String
    let url: URL
    let live: Bool
    let sourceKey: String
    @ObservedObject private var library = MediaLibrary.shared
    var body: some View {
        Button(tr("حفظ في مكتبة القنوات", "Save in channel library")) { save() }
        Button(tr("القنوات المفضلة", "Favorite channels")) { save(); if let item = library.items.first(where: { $0.url == url }) { library.toggleFavorite(item.id) } }
        Menu(tr("إضافة إلى قائمة تشغيل", "Add to playlist")) {
            ForEach(library.playlists) { playlist in
                Button(playlist.title) { save(); if let item = library.items.first(where: { $0.url == url }) { library.addToPlaylist(playlist.id, item: item) } }
            }
        }
    }
    private func save() {
        do { try library.addRemote(title: title, url: url, isLive: live, sourceKey: sourceKey) }
        catch { library.error = error.localizedDescription }
    }
}
