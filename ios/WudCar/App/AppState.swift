import SwiftUI
import Combine

@MainActor final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var preferences: Preferences { didSet { try? LocalFiles.save(preferences, name: "preferences.json") } }
    @Published var sources: [MediaSource] { didSet { try? LocalFiles.save(sources, name: "sources.json") } }
    @Published var themes = [Theme.builtin]
    @Published var library: [LibraryItem] = []
    @Published var updates: [AppUpdate] = []
    @Published var tracks: [Track] = []
    @Published var messages: [InboxMessage] = []
    @Published var religious: [ReligiousContent] = []
    @Published var catalogSettings: CatalogSettings?
    @Published var legal: [RemotePolicy] = []
    @Published var notice: String?
    init() { preferences = LocalFiles.load(Preferences.self, name: "preferences.json") ?? Preferences(); sources = LocalFiles.load([MediaSource].self, name: "sources.json") ?? []
        if let cached=LocalFiles.load(Catalog.self,name:"catalog.json") { apply(cached) }
    }
    private func apply(_ catalog:Catalog) { themes=catalog.themes.isEmpty ? [.builtin] : catalog.themes;tracks=catalog.music;religious=catalog.religious ?? [];catalogSettings=catalog.settings;legal=catalog.legal ?? [];library=catalog.library ?? [];updates=catalog.updates ?? [] }

    var theme: Theme {
        let available=themes.filter{$0.isAvailable(at:Date())}.sorted{($0.priority ?? 0)>($1.priority ?? 0)}
        return available.first{$0.forced==true} ?? available.first{$0.id==preferences.themeID} ?? .builtin
    }
    var themeTracks: [Track] {
        if theme.music_mode == "all" { return tracks }
        if theme.music_mode == "selected" { return theme.music_ids.compactMap { id in tracks.first { $0.id == id } } }
        return []
    }
    func text(_ ar: String, _ en: String) -> String { preferences.language == "ar" ? ar : en }
    func refresh() async {
        await InformationService.shared.refresh(city:preferences.city,method:preferences.prayerMethod)
        guard AppConfiguration.configured else { return }
        do { let catalog = try await CloudClient.shared.catalog(); apply(catalog);try? LocalFiles.save(catalog,name:"catalog.json");await ThemeCache.shared.prepare(theme:theme)
            if CloudClient.shared.session != nil { messages = try await CloudClient.shared.inbox() }
        } catch { notice = error.localizedDescription }
    }
    func sync() async { await PushService.shared.sync(); do { try await CloudClient.shared.saveProfile(preferences) } catch { notice = error.localizedDescription } }
    func clearPersonalData() {
        PlayerService.shared.stop(); try? FileManager.default.removeItem(at: LocalFiles.root.appendingPathComponent("Media")); preferences = Preferences(); sources = []; messages = []
    }
}
