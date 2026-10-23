import SwiftUI
import Combine

@MainActor final class MediaSearch: ObservableObject {
    struct Result: Identifiable {
        let id: String
        let title: String
        let source: String
        let play: () -> Void
    }
    @Published private(set) var results: [Result] = []
    @Published private(set) var history: [String] = UserDefaults.standard.stringArray(forKey: "wd.media.searchHistory") ?? []
    @Published private(set) var searching = false
    @Published private(set) var failures = 0
    func remember(_ query: String) {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        history.removeAll { $0 == text }; history.insert(String(text.prefix(200)), at: 0); history = Array(history.prefix(30)); UserDefaults.standard.set(history, forKey: "wd.media.searchHistory")
    }
    func clear() { history = []; UserDefaults.standard.removeObject(forKey: "wd.media.searchHistory") }
    func search(_ query: String, includeNetwork: Bool = true, onPhone: Bool = true) async {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { results = []; return }
        searching = true; failures = 0; defer { searching = false }
        var found: [Result] = []
        for media in MediaLibrary.shared.items where media.title.localizedCaseInsensitiveContains(query) {
            found.append(Result(id: "local-" + media.id.uuidString, title: media.title, source: tr("المكتبة", "Library"), play: {
                if let item = media.playbackItem { PlaybackManager.shared.playQueue([item], startingAt: item.url, presentOnPhone: onPhone) }
            }))
        }
        for source in SourceStore.shared.sources where !source.hidden {
            let items = SourceStore.shared.cached(source)
            for media in items where !media.folder && media.title.localizedCaseInsensitiveContains(query) {
                found.append(Result(id: source.id.uuidString + media.id, title: media.title, source: source.name, play: { SourceStore.shared.play(media, source: source, onPhone: onPhone) }))
            }
        }
        results = found
        guard includeNetwork else { return }
        for list in M3UStore.shared.playlists {
            guard !Task.isCancelled else { return }
            do {
                for entry in try await M3UStore.shared.entries(for: list) where entry.title.localizedCaseInsensitiveContains(query) {
                    found.append(Result(id: list.id.uuidString + entry.id, title: entry.title, source: list.name, play: { PlaybackManager.shared.playQueue([.init(title: entry.title, subtitle: list.name, url: entry.url, isLive: true, artworkURL: entry.logo)], startingAt: entry.url, presentOnPhone: onPhone) }))
                }
            } catch { failures += 1 }
        }
        for account in XtreamStore.shared.accounts {
            let client = XtreamClient(account: account)
            for kind in XtreamKind.allCases {
                guard !Task.isCancelled else { return }
                do {
                    for stream in try await client.streams(kind, categoryID: nil) where stream.name.localizedCaseInsensitiveContains(query) {
                        guard let url = client.playbackURL(for: stream) else { continue }
                        found.append(Result(id: account.id.uuidString + kind.rawValue + stream.id, title: stream.name, source: account.name, play: { PlaybackManager.shared.playQueue([.init(title: stream.name, subtitle: account.name, url: url, isLive: kind == .live, artworkURL: stream.icon)], startingAt: url, presentOnPhone: onPhone) }))
                    }
                } catch { failures += 1 }
            }
        }
        for source in SourceStore.shared.sources where !source.hidden && [.jellyfin,.emby,.plex].contains(source.kind) {
            guard !Task.isCancelled else { return }
            do {
                guard let credentials = SourceStore.shared.credentials(source) else { continue }
                for media in try await SourceNetwork().search(source, credentials: credentials, query: query) where !media.folder {
                    found.append(Result(id: source.id.uuidString + media.id, title: media.title, source: source.name, play: { SourceStore.shared.play(media, source: source, onPhone: onPhone) }))
                }
            } catch { failures += 1 }
        }
        guard !Task.isCancelled else { return }
        var seen = Set<String>(); results = found.filter { seen.insert($0.id).inserted }
    }
}
struct MediaSearchView: View {
    @StateObject private var model = MediaSearch()
    @State private var query = ""
    @State private var dictating = false
    var body: some View {
        List {
            if query.isEmpty {
                Section(tr("سجل البحث", "Search history")) {
                    ForEach(model.history, id: \.self) { value in Button(value) { query = value } }
                    Button(tr("مسح سجل البحث", "Clear search history"), role: .destructive) { model.clear() }
                }
            }
            if model.searching { ProgressView(tr("جارِ البحث في المصادر…", "Searching sources…")) }
            ForEach(model.results) { result in Button { model.remember(query); result.play() } label: { VStack(alignment: .leading) { Text(result.title); Text(result.source).font(.caption).foregroundStyle(.secondary) } } }
            if model.failures > 0 { Text(tr("تعذّر البحث في بعض الخوادم. تحقق من اتصالها.", "Some servers could not be searched. Check their connection.")).font(.footnote) }
        }.navigationTitle(tr("البحث في الوسائط", "Search media"))
            .searchable(text: $query).onSubmit(of: .search) { model.remember(query) }
            .toolbar {
                Button {
                    if dictating { SpeechDictation.shared.stop() }
                    else {
                        dictating = true
                        SpeechDictation.shared.start(localeID: L10n.language.rawValue == "ar" ? "ar-AE" : "en-US", onText: { query = $0 }, onEnd: { dictating = false })
                    }
                } label: { Image(systemName: dictating ? "stop.circle" : "mic") }
            }
            .task(id: query) { do { try await Task.sleep(for: .milliseconds(500)); try Task.checkCancellation(); await model.search(query) } catch {} }
            .onDisappear { if dictating { SpeechDictation.shared.stop() } }
    }
}
