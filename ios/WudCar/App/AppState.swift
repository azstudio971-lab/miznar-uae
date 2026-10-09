import SwiftUI
import Combine

@MainActor final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var preferences: Preferences { didSet { try? LocalFiles.save(preferences, name: "preferences.json") } }
    @Published var sources: [MediaSource] { didSet { try? LocalFiles.save(sources, name: "sources.json") } }
    @Published var themes = [Theme.builtin]
    @Published var tracks: [Track] = []
    @Published var messages: [InboxMessage] = []
    @Published var notice: String?
    init() { preferences = LocalFiles.load(Preferences.self, name: "preferences.json") ?? Preferences(); sources = LocalFiles.load([MediaSource].self, name: "sources.json") ?? [] }
    var theme: Theme { themes.first { $0.forced == true } ?? themes.first { $0.id == preferences.themeID } ?? .builtin }
    func text(_ ar: String, _ en: String) -> String { preferences.language == "ar" ? ar : en }
    func refresh() async {
        guard AppConfiguration.configured else { return }
        do { let catalog = try await CloudClient.shared.catalog(); themes = catalog.themes.isEmpty ? [.builtin] : catalog.themes; tracks = catalog.music
            if CloudClient.shared.session != nil { messages = try await CloudClient.shared.inbox() }
        } catch { notice = error.localizedDescription }
    }
    func sync() async { do { try await CloudClient.shared.saveProfile(preferences) } catch { notice = error.localizedDescription } }
    func clearPersonalData() {
        PlayerService.shared.stop(); try? FileManager.default.removeItem(at: LocalFiles.root.appendingPathComponent("Media")); preferences = Preferences(); sources = []; messages = []
    }
}
