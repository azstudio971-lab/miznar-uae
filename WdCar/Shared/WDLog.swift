import Foundation
import os

enum WDLog {
    private static let logger = Logger(subsystem: "com.azstudio.wudcar", category: "CarPlay")
    private static let lock = NSLock()
    private static let key = "wudcar.carplay.connectionLog"

    static func car(_ message: String) {
        let safeMessage = DiagnosticLog.redact(message)
        logger.notice("WUDCAR \(safeMessage, privacy: .public)")
        DiagnosticLog.shared.append(category: "CarPlay", message: safeMessage)
        lock.lock()
        defer { lock.unlock() }
        var entries = UserDefaults.standard.stringArray(forKey: key) ?? []
        entries.append("\(Date().ISO8601Format()) \(safeMessage)")
        UserDefaults.standard.set(Array(entries.suffix(100)), forKey: key)
    }

    static var recentText: String {
        DiagnosticLog.shared.fullText
    }
}
