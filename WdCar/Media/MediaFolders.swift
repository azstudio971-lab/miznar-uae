import SwiftUI

@MainActor final class MediaFolders: ObservableObject {
    static let shared = MediaFolders()
    @Published private(set) var folders: [MediaPlaylist] = []
    @Published var error: String?
    private var writable = true
    private var file: URL { MediaLibrary.directory.appendingPathComponent("folders.json") }
    private init() {
        do { if FileManager.default.fileExists(atPath: file.path) { folders = try JSONDecoder().decode([MediaPlaylist].self, from: Data(contentsOf: file)) } }
        catch { writable = false; self.error = error.localizedDescription }
    }
    private func save() { guard writable else { return }; do { try JSONEncoder().encode(folders).write(to: file, options: [.atomic, .completeFileProtection]) } catch { self.error = error.localizedDescription } }
    func create(_ name: String) {
        guard writable, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        folders.append(MediaPlaylist(name: name)); save()
    }
    func rename(_ id: UUID, name: String) {
        guard writable, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].name = name; save()
    }
    func remove(_ id: UUID) { guard writable else { return }; folders.removeAll { $0.id == id }; save() }
    func setMembers(_ ids: [UUID], in id: UUID) {
        guard writable, let index = folders.firstIndex(where: { $0.id == id }) else { return }
        var seen = Set<UUID>(); folders[index].itemIDs = ids.filter { id in seen.insert(id).inserted && MediaLibrary.shared.items.contains { $0.id == id } }; save()
    }
    func add(_ ids: Set<UUID>, to id: UUID) {
        guard let folder = folders.first(where: { $0.id == id }) else { return }; setMembers(folder.itemIDs + ids.sorted { $0.uuidString < $1.uuidString }, in: id)
    }
    func members(_ id: UUID) -> [LibraryMedia] { (folders.first { $0.id == id }?.itemIDs ?? []).compactMap { id in MediaLibrary.shared.items.first { $0.id == id } } }
}
struct MediaFoldersView: View {
    @ObservedObject private var folders = MediaFolders.shared
    @State private var name = ""
    var body: some View {
        List {
            Section {
                TextField(tr("اسم المجلد", "Folder name"), text: $name)
                Button(tr("إنشاء مجلد", "Create folder")) { folders.create(name); name = "" }
            }
            ForEach(folders.folders) { folder in
                NavigationLink { MediaFolderDetail(id: folder.id) } label: { Label(folder.name, systemImage: "folder") }
                    .swipeActions { Button(role: .destructive) { folders.remove(folder.id) } label: { Image(systemName: "trash") } }
            }
        }.navigationTitle(tr("المجلدات", "Folders"))
    }
}
struct MediaFolderDetail: View {
    let id: UUID
    @ObservedObject private var folders = MediaFolders.shared
    @ObservedObject private var library = MediaLibrary.shared
    @State private var name = ""
    private var folder: MediaPlaylist? { folders.folders.first { $0.id == id } }
    var body: some View {
        List {
            if let folder {
                Section {
                    TextField(tr("الاسم", "Name"), text: $name)
                    Button(tr("إعادة تسمية", "Rename")) { folders.rename(id, name: name) }
                    Button(tr("تشغيل المجلد", "Play folder")) { PlaybackManager.shared.playQueue(folders.members(id).compactMap(\.playbackItem), startingAt: nil, presentOnPhone: true, playlistName: folder.name) }.disabled(folder.itemIDs.isEmpty)
                }
                Section(tr("الترتيب", "Order")) {
                    ForEach(folders.members(id)) { Text($0.title) }
                        .onMove { source, destination in var values = folder.itemIDs; values.move(fromOffsets: source, toOffset: destination); folders.setMembers(values, in: id) }
                        .onDelete { offsets in var values = folder.itemIDs; values.remove(atOffsets: offsets); folders.setMembers(values, in: id) }
                }
                Section(tr("إضافة وإزالة الوسائط", "Add and remove media")) {
                    Button(tr("تحديد الكل", "Select all")) { folders.setMembers(library.items.map(\.id), in: id) }
                    Button(tr("إلغاء التحديد", "Deselect all")) { folders.setMembers([], in: id) }
                    ForEach(library.items) { media in
                        Toggle(media.title, isOn: Binding(get: { folder.itemIDs.contains(media.id) }, set: { selected in
                            var values = folder.itemIDs.filter { $0 != media.id }; if selected { values.append(media.id) }; folders.setMembers(values, in: id)
                        }))
                    }
                }
            }
        }.navigationTitle(folder?.name ?? "").toolbar { EditButton() }.onAppear { name = folder?.name ?? "" }
    }
}
