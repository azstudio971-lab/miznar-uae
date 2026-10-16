import SwiftUI

@main struct WudCarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = AppState.shared
    @Environment(\.scenePhase) private var phase
    init() {
        #if DEBUG
        if AppConfiguration.browserUITesting {
            AppState.shared.preferences = Preferences()
            AppState.shared.preferences.language = ProcessInfo.processInfo.arguments.contains("--arabic") ? "ar" : "en"
            AppState.shared.preferences.appearance = ProcessInfo.processInfo.arguments.contains("--light") ? "light" : "dark"
            AppState.shared.preferences.onboarded = true
            AppState.shared.sources = []
            UserDefaults.standard.removeObject(forKey: "wudcar.v3.browser.starters.v1")
        }
        #endif
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(state)
                .environment(\.layoutDirection, state.preferences.language == "ar" ? .rightToLeft : .leftToRight)
                .environment(\.locale, Locale(identifier: state.preferences.language))
                .preferredColorScheme(state.preferences.appearance == "dark" ? .dark : state.preferences.appearance == "light" ? .light : nil)
                .tint(Color(red: 0.09, green: 0.40, blue: 0.36))
                .task { await UsageMeter.shared.run() }
                .onChange(of: phase) { _, value in UsageMeter.shared.foreground = value == .active }
                .task(id:phase) {
                    guard phase == .active, !AppConfiguration.browserUITesting else{return}
                    while !Task.isCancelled {
                        await state.refresh()
                        await PushService.shared.sync()
                        do { try await Task.sleep(for:.seconds(max(60,min(1800,state.catalogSettings?.refresh_seconds ?? 600)))) } catch { return }
                    }
                }
        }
    }
}
