import Foundation
import SwiftUI

struct MediaPlaylist: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var itemIDs: [UUID] = []
    var favorite = false
}
enum MediaImportError: LocalizedError {
    case unsupported
    var errorDescription: String? { tr("صيغة الوسائط غير مدعومة أو الملف تالف. استخدم صيغة يدعمها AVPlayer مثل MP4 أو MOV أو MP3 أو M4A.", "Unsupported media format or damaged file. Use an AVPlayer-compatible format such as MP4, MOV, MP3 or M4A.") }
}
extension MediaLibrary {
    func createPlaylist(_ name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        updatePlaylists { $0.append(MediaPlaylist(name: name)) }
    }
    func renamePlaylist(_ id: UUID, name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        updatePlaylists { lists in
            guard let index = lists.firstIndex(where: { $0.id == id }) else { return }
            lists[index].name = name
        }
    }
    func deletePlaylist(_ id: UUID) { updatePlaylists { $0.removeAll { $0.id == id } } }
    func favoritePlaylist(_ id: UUID) {
        updatePlaylists { lists in
            guard let index = lists.firstIndex(where: { $0.id == id }) else { return }
            lists[index].favorite.toggle()
        }
    }
    func setMembers(_ ids: [UUID], in id: UUID) {
        updatePlaylists { lists in
            guard let index = lists.firstIndex(where: { $0.id == id }) else { return }
            var seen = Set<UUID>()
            lists[index].itemIDs = ids.filter { id in seen.insert(id).inserted && items.contains(where: { $0.id == id }) }
        }
    }
    func members(_ id: UUID) -> [LibraryMedia] {
        (playlists.first { $0.id == id }?.itemIDs ?? []).compactMap { id in items.first { $0.id == id } }
    }
    func play(_ list: MediaPlaylist, onPhone: Bool) {
        PlaybackManager.shared.playQueue(members(list.id).compactMap(\.playbackItem), startingAt: nil, presentOnPhone: onPhone, playlistName: list.name)
    }
}
struct MediaPlaylistsView: View {
    @ObservedObject private var library = MediaLibrary.shared
    @State private var name = ""
    var body: some View {
        List {
            Section {
                TextField(tr("اسم القائمة", "Playlist name"), text: $name)
                Button(tr("إنشاء قائمة", "Create playlist")) { library.createPlaylist(name); name = "" }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ForEach(library.playlists) { list in
                NavigationLink { MediaPlaylistDetail(id: list.id) } label: {
                    Label(list.name, systemImage: list.favorite ? "star.fill" : "list.bullet.rectangle")
                }.swipeActions {
                    Button(role: .destructive) { library.deletePlaylist(list.id) } label: { Label(tr("حذف القائمة", "Delete playlist"), systemImage: "trash") }
                    Button { library.favoritePlaylist(list.id) } label: { Label(tr("المفضلة", "Favorite"), systemImage: "star") }.tint(.orange)
                }
            }
        }.navigationTitle(tr("قوائم التشغيل", "Playlists"))
    }
}
struct MediaPlaylistDetail: View {
    let id: UUID
    @ObservedObject private var library = MediaLibrary.shared
    @State private var name = ""
    private var list: MediaPlaylist? { library.playlists.first { $0.id == id } }
    var body: some View {
        List {
            if let list {
                Section {
                    TextField(tr("اسم القائمة", "Playlist name"), text: $name)
                    Button(tr("إعادة تسمية", "Rename")) { library.renamePlaylist(id, name: name) }
                    Button(tr("تشغيل القائمة", "Play playlist")) { library.play(list, onPhone: true) }.disabled(list.itemIDs.isEmpty)
                }
                Section(tr("اسحب لإعادة الترتيب", "Drag to reorder")) {
                    ForEach(library.members(id)) { item in Text(item.title) }
                        .onMove { source, destination in
                            var ids = list.itemIDs; ids.move(fromOffsets: source, toOffset: destination); library.setMembers(ids, in: id)
                        }.onDelete { offsets in
                            var ids = list.itemIDs; ids.remove(atOffsets: offsets); library.setMembers(ids, in: id)
                        }
                }
                Section(tr("إضافة وإزالة الوسائط", "Add and remove media")) {
                    ForEach(library.items) { item in
                        Toggle(item.title, isOn: Binding(get: { list.itemIDs.contains(item.id) }, set: { selected in
                            var ids = list.itemIDs; ids.removeAll { $0 == item.id }; if selected { ids.append(item.id) }; library.setMembers(ids, in: id)
                        }))
                    }
                }
            }
        }.navigationTitle(list?.name ?? "").toolbar { EditButton() }.onAppear { name = list?.name ?? "" }
    }
}
