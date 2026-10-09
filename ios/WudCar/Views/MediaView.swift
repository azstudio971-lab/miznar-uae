import SwiftUI
import UniformTypeIdentifiers

struct MediaView: View {
    @EnvironmentObject var state: AppState
    @State private var adding = false
    @State private var importing = false
    @State private var name = ""
    @State private var address = ""
    @State private var type = "stream"
    @State private var kind = "audio"
    @State private var items: [MediaItem] = []
    @State private var loading = false
    @State private var loadingID: UUID?
    var body: some View {
        List {
            Section { Text(state.text("أضف ملفاتك أو روابط لديك حق تشغيلها. لا يتضمن التطبيق قنوات أو محتوى مدفوعًا.", "Add your own files or links you are authorized to play. No channels or paid content are bundled.")).font(.caption).foregroundStyle(.secondary) }
            Section {
                Button { adding = true } label: { Label(state.text("إضافة رابط", "Add a link"), systemImage: "link.badge.plus") }
                Button { importing = true } label: { Label(state.text("استيراد ملف", "Import a file"), systemImage: "folder") }
            }
            if loading { ProgressView() }
            if !state.tracks.isEmpty && state.theme.music_mode != "none" {
                Section(state.text("مكتبة الثيم", "Theme audio")) {
                    ForEach(state.tracks.filter { state.theme.music_mode == "all" || state.theme.music_ids.contains($0.id) }) { track in
                        Button(state.preferences.language == "ar" ? track.name_ar : track.name_en) { if let url = WudDomain.validURL(track.url) { PlayerService.shared.play(url: url, name: state.preferences.language == "ar" ? track.name_ar : track.name_en) } }
                    }
                }
            }
            ForEach(state.sources) { source in
                Button { Task { await open(source) } } label: { HStack { Image(systemName: source.mediaKind == "video" ? "play.rectangle" : "waveform"); VStack(alignment: .leading) { Text(source.name); Text(source.type.uppercased()).font(.caption).foregroundStyle(.secondary) }; Spacer(); if source.favorite { Image(systemName: "star.fill") } } }
                    .swipeActions { Button(role: .destructive) { remove(source) } label: { Label(state.text("حذف", "Delete"), systemImage: "trash") }; Button { if let i = state.sources.firstIndex(where: { $0.id == source.id }) { state.sources[i].favorite.toggle() } } label: { Label(state.text("المفضلة", "Favorite"), systemImage: "star") }.tint(.orange) }
            }
            if state.sources.isEmpty { ContentUnavailableView(state.text("مكتبتك جاهزة", "Your library is ready"), systemImage: "play.rectangle.on.rectangle", description: Text(state.text("ابدأ بإضافة مصدر صوت أو فيديو خاص بك.", "Start by adding your own audio or video source."))) }
            if !items.isEmpty { Section(state.text("قائمة التشغيل", "Playlist")) { ForEach(items) { item in Button(item.name) { PlayerService.shared.play(url: item.url, name: item.name) } } } }
        }.navigationTitle(state.text("مكتبتي", "My library"))
        .sheet(isPresented: $adding) { NavigationStack { Form {
            TextField(state.text("الاسم", "Name"), text: $name)
            TextField("https://", text: $address).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
            Picker(state.text("النوع", "Type"), selection: $type) { Text(state.text("بث مباشر / HLS", "Stream / HLS")).tag("stream"); Text("M3U").tag("playlist") }
            Picker(state.text("المحتوى", "Media"), selection: $kind) { Text(state.text("صوت", "Audio")).tag("audio"); Text(state.text("فيديو", "Video")).tag("video") }
            Button(state.text("حفظ", "Save")) { guard let url = WudDomain.validURL(address), !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }; state.sources.append(MediaSource(name: String(name.prefix(100)), url: url.absoluteString, type: type, mediaKind: kind)); adding = false; name = ""; address = "" }.disabled(WudDomain.validURL(address) == nil || name.isEmpty)
        }.navigationTitle(state.text("مصدر جديد", "New source")).toolbar { Button(state.text("إلغاء", "Cancel")) { adding = false } } } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio, .movie]) { result in
            do { let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let folder = LocalFiles.root.appendingPathComponent("Media", isDirectory: true); try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let filename = UUID().uuidString + "." + url.pathExtension; let destination = folder.appendingPathComponent(filename)
                try FileManager.default.copyItem(at: url, to: destination)
                let contentType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType
                state.sources.append(MediaSource(name: url.deletingPathExtension().lastPathComponent, url: filename, type: "local", mediaKind: contentType?.conforms(to: .movie) == true ? "video" : "audio"))
            } catch { state.notice = error.localizedDescription }
        }
    }
    private func remove(_ source: MediaSource) { if source.type == "local" { try? FileManager.default.removeItem(at: LocalFiles.root.appendingPathComponent("Media").appendingPathComponent(source.url)) }; state.sources.removeAll { $0.id == source.id } }
    private func open(_ source: MediaSource) async {
        if source.type == "local" { PlayerService.shared.play(url: LocalFiles.root.appendingPathComponent("Media").appendingPathComponent(source.url), name: source.name); return }
        guard let url = WudDomain.validURL(source.url) else { return }
        if source.type != "playlist" { PlayerService.shared.play(url: url, name: source.name); return }
        let id = UUID(); loadingID = id; loading = true
        defer { if loadingID == id { loading = false } }
        do { var request = URLRequest(url: url); request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count < 5_000_000, let text = String(data: data, encoding: .utf8) else { throw WudError.message(state.text("تعذر قراءة القائمة", "Could not read playlist")) }
            guard loadingID == id else { return }
            if text.contains("#EXT-X-") { PlayerService.shared.play(url: url, name: source.name); items = [] }
            else { var seen = Set<String>(); items = WudDomain.parseM3U(text, base: url).filter { seen.insert($0.id).inserted }; if items.isEmpty { throw WudError.message(state.text("القائمة فارغة أو غير مدعومة", "Playlist is empty or unsupported")) } }
        } catch { if loadingID == id { state.notice = error.localizedDescription } }
    }
}
