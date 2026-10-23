import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ImportedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: url)
            return Self(url: url)
        }
    }
}

struct MediaLibraryView: View {
    @ObservedObject private var library = MediaLibrary.shared
    @State private var query = ""
    @State private var filter = 0
    @AppStorage("wd.media.sort") private var sort = "recent"
    @State private var files = false
    @State private var addLink = false
    @State private var photos = false
    @State private var title = ""
    @State private var address = ""
    @State private var live = false
    @State private var removal: LibraryMedia?

    private var visible: [LibraryMedia] {
        library.items.filter {
            (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)) &&
            (filter == 0 || (filter == 1 && $0.favorite) || (filter == 2 && $0.localFilename != nil) || (filter == 3 && $0.lastPlayed != nil))
        }.sorted {
            if sort == "name" { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            return ($0.lastPlayed ?? $0.added) > ($1.lastPlayed ?? $1.added)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(tr("قوائم التشغيل", "Playlists")) { MediaPlaylistsView() }
                    NavigationLink(tr("القنوات وقوائم M3U وحسابات Xtream", "Channels, M3U playlists and Xtream")) { XtreamHomeView() }
                    Button { photos = true } label: { Label(tr("استيراد من الصور", "Import from Photos"), systemImage: "photo") }
                        .disabled(library.importProgress != nil)
                    Button { files = true } label: { Label(tr("استيراد من الملفات", "Import from Files"), systemImage: "folder") }
                        .disabled(library.importProgress != nil)
                    Button { addLink = true } label: { Label(tr("إضافة رابط وسائط", "Add media URL"), systemImage: "link") }
                    if let progress = library.importProgress { ProgressView(value: progress) }
                } footer: {
                    Text(tr("أضف محتواك الخاص. الملفات المستوردة تُنسخ للتشغيل دون إنترنت؛ روابط الإنترنت تحتاج اتصالاً. لا نوفر محتوى أو اشتراكات IPTV.", "Add your own content. Imported files are copied for offline playback; internet sources require a connection. No content or IPTV subscriptions are provided."))
                }
                Section {
                    Picker(tr("عرض", "Show"), selection: $filter) {
                        Text(tr("الكل", "All")).tag(0)
                        Text(tr("المفضلة", "Favorites")).tag(1)
                        Text(tr("محلي", "Local")).tag(2)
                        Text(tr("السجل", "History")).tag(3)
                    }.pickerStyle(.segmented)
                    Picker(tr("الترتيب", "Sort"), selection: $sort) {
                        Text(tr("الأحدث", "Recent")).tag("recent")
                        Text(tr("الاسم", "Name")).tag("name")
                    }
                    ForEach(visible) { item in
                        Button {
                            PlaybackManager.shared.playQueue(visible.compactMap(\.playbackItem), startingAt: item.url, presentOnPhone: true)
                        } label: {
                            HStack {
                                if let image = UIImage(contentsOfFile: library.thumbnailURL(item.id).path) {
                                    Image(uiImage: image).resizable().scaledToFit().frame(width: 70, height: 44)
                                } else { Image(systemName: item.localFilename == nil ? "network" : "film").frame(width: 70) }
                                VStack(alignment: .leading) {
                                    Text(item.title)
                                    Text(item.localFilename == nil ? tr("مصدر إنترنت", "Internet source") : tr("ملف مستورد • دون إنترنت", "Imported • Offline")).font(.caption).foregroundStyle(.secondary)
                                    if let duration = item.duration {
                                        Text(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond))).font(.caption)
                                    }
                                    if item.position > 0, let duration = item.duration, duration > 0 { ProgressView(value: min(item.position / duration, 1)) }
                                }
                                if item.favorite { Image(systemName: "star.fill") }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button { library.toggleFavorite(item.id) } label: { Label(tr("المفضلة", "Favorite"), systemImage: "star") }.tint(.orange)
                        }
                        .swipeActions {
                            Button(role: .destructive) { removal = item } label: { Label(tr("إزالة", "Remove"), systemImage: "trash") }
                        }
                    }
                    if visible.isEmpty { Text(tr("أضف ملفًا أو رابطًا للبدء", "Add a file or URL to begin")).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle(tr("مكتبة الوسائط", "Media library"))
            .searchable(text: $query)
            .sheet(isPresented: $files) {
                MediaDocumentPicker { urls in files = false; Task { await library.importFiles(urls) } }
            }
            .sheet(isPresented: $photos) {
                MediaPhotosPicker { urls, errors in
                    photos = false
                    Task { @MainActor in
                        await library.importFiles(urls)
                        for url in urls { try? FileManager.default.removeItem(at: url) }
                        if !errors.isEmpty { library.error = errors.joined(separator: "\n") }
                    }
                }
            }
            .sheet(isPresented: $addLink) {
                NavigationStack {
                    Form {
                        TextField(tr("الاسم", "Name"), text: $title)
                        TextField("https://", text: $address).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        Toggle(tr("بث مباشر", "Live stream"), isOn: $live)
                        Button(tr("إضافة", "Add")) {
                            do {
                                guard let url = URL(string: address.trimmingCharacters(in: .whitespacesAndNewlines)) else { throw M3UError.invalidURL }
                                try library.addRemote(title: title, url: url, isLive: live)
                                address = ""; title = ""; addLink = false
                            } catch { library.error = error.localizedDescription; addLink = false }
                        }
                    }.navigationTitle(tr("رابط وسائط", "Media URL"))
                        .toolbar { Button(tr("إلغاء", "Cancel")) { addLink = false } }
                }
            }
            .alert(tr("تعذّر إكمال العملية", "Operation failed"), isPresented: Binding(get: { library.error != nil }, set: { if !$0 { library.error = nil } })) {
                Button(tr("حسنًا", "OK")) { library.error = nil }
            } message: { Text(library.error ?? "") }
            .confirmationDialog(tr("إزالة نسخة التطبيق فقط؟ الأصل في الصور أو الملفات لن يُحذف.", "Remove the app copy only? The original in Photos or Files will remain."), isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } }), titleVisibility: .visible) {
                Button(tr("إزالة", "Remove"), role: .destructive) {
                    if let removal { library.remove(removal.id) }
                    removal = nil
                }
            }
        }
    }
}
