import os

/// سجلات تشخيص CarPlay: تظهر في Console (iMazing) — ابحث عن كلمة WUDCAR
enum WDLog {
    private static let logger = Logger(subsystem: "com.azstudio.wudcar", category: "CarPlay")

    static func car(_ message: String) {
        logger.notice("WUDCAR \(message, privacy: .public)")
    }
}
