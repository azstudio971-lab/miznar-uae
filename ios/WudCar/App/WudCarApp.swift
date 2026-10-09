import SwiftUI

@main struct WudCarApp: App {
    @StateObject private var state = AppState.shared
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(state)
                .environment(\.layoutDirection, state.preferences.language == "ar" ? .rightToLeft : .leftToRight)
                .environment(\.locale, Locale(identifier: state.preferences.language))
                .tint(Color(red: 0.09, green: 0.40, blue: 0.36))
                .task { await state.refresh() }
        }
    }
}
