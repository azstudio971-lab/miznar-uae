import Foundation
import os

enum WDLog {
    private static let logger = Logger(subsystem: "com.azstudio.wudcar", category: "CarPlay")
    private static let lock = NSLock()
    private static let key = "wudcar.carplay.connectionLog"

    static func car(_ message: String) {
        logger.notice("WUDCAR \(message, privacy: .public)")
        lock.lock()
        defer { lock.unlock() }
        var entries = UserDefaults.standard.stringArray(forKey: key) ?? []
        entries.append("\(Date().ISO8601Format()) \(message)")
        UserDefaults.standard.set(Array(entries.suffix(100)), forKey: key)
    }

    static var recentText: String {
        lock.lock()
        defer { lock.unlock() }
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        return "WudCar \(version) (\(build))\n" +
            (UserDefaults.standard.stringArray(forKey: key) ?? []).joined(separator: "\n")
    }
}
