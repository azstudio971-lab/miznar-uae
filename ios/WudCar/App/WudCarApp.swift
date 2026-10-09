import SwiftUI

@main struct WudCarApp: App {
    @StateObject private var state = AppState.shared
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(state)
                .environment(\.layoutDirection, state.preferences.language == "ar" ? .rightToLeft : .leftToRight)
                .environment(\.locale, Locale(identifier: state.preferences.language))
                .preferredColorScheme(state.preferences.appearance == "dark" ? .dark : state.preferences.appearance == "light" ? .light : nil)
                .tint(Color(red: 0.09, green: 0.40, blue: 0.36))
                .task(id:phase) {
                    guard phase == .active else{return}
                    while !Task.isCancelled {
                        await state.refresh()
                        do { try await Task.sleep(for:.seconds(max(60,min(1800,state.catalogSettings?.refresh_seconds ?? 600)))) } catch { return }
                    }
                }
        }
    }
}
