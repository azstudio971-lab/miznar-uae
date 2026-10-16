import Foundation

enum AppConfiguration {
    static var browserUITesting: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--browser-ui-tests")
        #else
        return false
        #endif
    }
    static var supabaseURL:String {Bundle.main.object(forInfoDictionaryKey:"WUD_SUPABASE_URL") as? String ?? ""}
    static var publishableKey:String {Bundle.main.object(forInfoDictionaryKey:"WUD_SUPABASE_KEY") as? String ?? ""}
    static var configured:Bool {supabaseURL.hasPrefix("https://") && !publishableKey.isEmpty && !publishableKey.contains("$(")}
    // Enable only in a release with approved App Store products and verified trial behavior.
    static let subscriptionsEnabled=false
    static let productIDs=["com.azpixel.wudcar.monthly","com.azpixel.wudcar.yearly"]
    static let supportEmail="az.studio971@gmail.com"
}
