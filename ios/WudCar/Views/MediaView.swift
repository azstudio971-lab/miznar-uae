import SwiftUI
import AVKit

struct MediaView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openURL) private var openURL
    @ObservedObject private var player = PlayerService.shared
    @State private var section = "website"
    @State private var adding = false
    @State private var showingPlayer = false
    @State private var name = ""
    @State private var address = ""
    @State private var query = ""
    private var entries: [MediaSource] {
        let official = state.library.map { MediaSource(id: $0.id, name: $0.name(state.preferences.language), url: $0.url, type: $0.kind == "website" ? "website" : "stream", mediaKind: "video", favorite: state.preferences.favoriteIDs.contains($0.id)) }
        return (official + state.sources).filter { (section == "website" ? $0.type == "website" : $0.type != "website") && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Picker(state.text("المكتبة", "Library"), selection: $section) { Text(state.text("المواقع", "Websites")).tag("website"); Text(state.text("البث المباشر", "Live streams")).tag("live") }.pickerStyle(.segmented)
                TextField(state.text("ابحث في مكتبتك", "Search your library"), text: $query).textFieldStyle(.roundedBorder)
                grid(entries)
                Text(state.text("المفضلة", "Favorites")).font(.title3.bold())
                if entries.contains(where: \.favorite) { grid(entries.filter(\.favorite)) } else { Text(state.text("اضغط النجمة لحفظ رابطك المفضل.", "Tap a star to save a favorite.")).font(.caption).foregroundStyle(.secondary) }
                Button { adding = true } label: { Label(state.text("إضافة رابط", "Add a link"), systemImage: "plus").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                if section == "live" && entries.isEmpty { ContentUnavailableView(state.text("أضف أول بث مباشر", "Add your first live stream"), systemImage: "dot.radiowaves.left.and.right") }
                if !state.tracks.isEmpty && state.theme.music_mode != "none" {
                    Text(state.text("قائمة الثيم", "Theme playlist")).font(.title3.bold())
                    ForEach(state.tracks.filter { state.theme.music_mode == "all" || state.theme.music_ids.contains($0.id) }) { track in
                        Button(state.text(track.name_ar, track.name_en)) { if let url = WudDomain.validURL(track.url) { player.play(url: url, name: state.text(track.name_ar, track.name_en)); showingPlayer = true } }
                    }
                }
            }.padding()
        }.navigationTitle(state.text("مكتبتي", "My library"))
        .onChange(of: state.sources) { _, _ in Task { do { try await CloudClient.shared.saveLibrary() } catch { state.notice = error.localizedDescription } } }
        .sheet(isPresented: $showingPlayer) { VStack { Text(player.title).font(.headline); VideoPlayer(player: player.player); AirPlayButton().frame(width: 44, height: 44); if let error = player.error { Text(error).foregroundStyle(.red) }; Button(state.text("إغلاق", "Close")) { player.stop(); showingPlayer = false } }.padding() }
        .sheet(isPresented: $adding) { NavigationStack { Form {
            TextField(state.text("الاسم", "Name"), text: $name)
            TextField("https://", text: $address).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
            Text(state.text("المواقع تفتح في المتصفح. البث يحتاج رابط فيديو مباشر مثل HLS.", "Websites open in your browser. Live streams need a direct video URL, such as HLS.")).font(.caption)
            Button(state.text("حفظ في المفضلة", "Save to favorites")) { guard let url = WudDomain.validURL(address) else { return }; state.sources.append(MediaSource(name: String(name.prefix(80)), url: url.absoluteString, type: section == "website" ? "website" : "stream", mediaKind: "video", favorite: true)); adding = false; name = ""; address = "" }.disabled(WudDomain.validURL(address) == nil || name.trimmingCharacters(in: .whitespaces).isEmpty)
        }.navigationTitle(state.text("إضافة رابط", "Add a link")).toolbar { Button(state.text("إلغاء", "Cancel")) { adding = false } } } }
    }
    private func grid(_ sources: [MediaSource]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 22) {
            ForEach(sources) { source in VStack(spacing: 9) {
                Button { open(source) } label: { VStack(spacing: 10) {
                    ZStack { RoundedRectangle(cornerRadius: 18).fill(Color(red: 0.04, green: 0.32, blue: 0.38)); Text(String(source.name.prefix(2))).font(.title2.bold()).foregroundStyle(.white) }.frame(width: 66, height: 66)
                    Text(source.name).font(.caption).lineLimit(1)
                } }.buttonStyle(.plain)
                Button { favorite(source) } label: { Image(systemName: source.favorite ? "star.fill" : "star").foregroundStyle(source.favorite ? Color.orange : Color.secondary) }.accessibilityLabel(state.text("المفضلة", "Favorite") + " " + source.name)
            }.contextMenu { if state.sources.contains(where: { $0.id == source.id }) { Button(state.text("حذف", "Delete"), role: .destructive) { state.sources.removeAll { $0.id == source.id } } } } }
        }
    }
    private func favorite(_ source: MediaSource) {
        if let i = state.sources.firstIndex(where: { $0.id == source.id }) { state.sources[i].favorite.toggle() }
        else if state.preferences.favoriteIDs.contains(source.id) { state.preferences.favoriteIDs.removeAll { $0 == source.id } }
        else { state.preferences.favoriteIDs.append(source.id) }
        Task { await state.sync(); do { try await CloudClient.shared.saveLibrary() } catch { state.notice = error.localizedDescription } }
    }
    private func open(_ source: MediaSource) {
        guard let url = WudDomain.validURL(source.url) else { return }
        if source.type == "website" { openURL(url) }
        else { player.play(url: url, name: source.name); showingPlayer = true }
    }
}
