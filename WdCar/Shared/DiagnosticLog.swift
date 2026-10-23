import Foundation
import UIKit

extension Notification.Name {
    static let wdCarPlayDiagnosticSettingsChanged = Notification.Name("wdCarPlayDiagnosticSettingsChanged")
}

/// Thread-safe, persistent diagnostic log used by the owner-requested TestFlight experiment.
final class DiagnosticLog {
    static let shared = DiagnosticLog()
    static let maximumLines = 5_000

    private let lock = NSRecursiveLock()
    private let fileURL: URL
    private let maximum: Int
    private var lines: [String]
    private var summaryValues: [String: String] = [:]

    init(fileURL: URL? = nil, maximumLines: Int = DiagnosticLog.maximumLines) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("WudCar", isDirectory: true)
        self.fileURL = fileURL ?? support.appendingPathComponent("diagnostic.txt")
        self.maximum = max(1, maximumLines)
        if let text = try? String(contentsOf: self.fileURL, encoding: .utf8) {
            self.lines = Array(text.components(separatedBy: .newlines).filter { !$0.isEmpty }.suffix(self.maximum))
        } else {
            self.lines = []
        }
        for key in ["الصلاحيات في profile", "آخر supportsVideoPlayback", "آخر حالة شاشة خارجية", "وضع عنصر المتصفح", "آخر CarPlay tab"] {
            if let value = UserDefaults.standard.string(forKey: Self.summaryDefaultsKey(key)) { summaryValues[key] = value }
        }
    }

    func append(category: String, message: String, date: Date = Date()) {
        lock.lock(); defer { lock.unlock() }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let oneLineMessage = Self.redact(message).replacingOccurrences(of: "\n", with: "\\n")
        let entry = "\(formatter.string(from: date))\t\(category)\t\(oneLineMessage)"
        let previousCount = lines.count
        lines.append(entry)
        if lines.count > maximum { lines.removeFirst(lines.count - maximum) }
        persistLocked(appendedLine: entry, appendOnly: previousCount < maximum && lines.count <= maximum)
    }

    var lineCount: Int { lock.lock(); defer { lock.unlock() }; return lines.count }
    var currentLines: [String] { lock.lock(); defer { lock.unlock() }; return lines }
    var logFileURL: URL { fileURL }

    var summaryText: String {
        lock.lock(); defer { lock.unlock() }
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        let external = summaryValues["آخر حالة شاشة خارجية"] ?? "لا يوجد اتصال مسجل"
        let support = summaryValues["آخر supportsVideoPlayback"] ?? "لم تسجل بعد"
        let profile = summaryValues["الصلاحيات في profile"] ?? "unavailable"
        return [
            "نسخة الاختبار: \(WD_BUILD_TAG)",
            "الإصدار: \(version)",
            "البناء: \(build)",
            "صلاحيات CarPlay في profile: \(profile)",
            "آخر supportsVideoPlayback: \(support)",
            "اتصال شاشة خارجية: \(external)",
            "فتح المتصفح تلقائياً عند اختيار المفضلة: \(WDSettings.testAutoOpenBrowserOnFavorites)",
            "فرض وضع الفيديو لعنصر المتصفح: \(WDSettings.testForceBrowserVideo)"
        ].joined(separator: "\n")
    }

    func setSummaryValue(_ key: String, value: String) {
        lock.lock(); defer { lock.unlock() }
        summaryValues[key] = value
        UserDefaults.standard.set(value, forKey: Self.summaryDefaultsKey(key))
    }

    private static func summaryDefaultsKey(_ key: String) -> String { "wudcar.diagnostic.summary.\(key)" }

    func markExternalDisplayConnected() {
        setSummaryValue("آخر حالة شاشة خارجية", value: "نعم — \(ISO8601DateFormatter().string(from: Date()))")
    }

    func fullText(summary: String? = nil) -> String {
        lock.lock(); defer { lock.unlock() }
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        let head = summary ?? summaryText + "\nالإصدار المسجل: \(version)\nالبناء المسجل: \(build)\n" +
            summaryValues.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        return "\(head)\n\n\(lines.joined(separator: "\n"))"
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        lines.removeAll()
        UserDefaults.standard.removeObject(forKey: "wudcar.carplay.connectionLog")
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: fileURL.path, contents: Data())
    }

    private func persistLocked(appendedLine: String, appendOnly: Bool) {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            if appendOnly {
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    FileManager.default.createFile(atPath: fileURL.path, contents: nil)
                }
                let handle = try FileHandle(forWritingTo: fileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data((appendedLine + "\n").utf8))
                try handle.close()
            } else {
                try (lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n"))
                    .write(to: fileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            // Logging must never interrupt app or CarPlay callbacks.
        }
    }

    static func redact(_ text: String) -> String {
        var value = text
        let patterns = [
            #"(https?://)[^/@\s:]+:[^/@\s]+@"#,
            #"(https?://[^/\s?#]+)/(live|movie|series)/[^/\s?#]+/[^/\s?#]+"#,
            #"([?&](?:username|user|password|pass|token|api_key)=)[^&#\s]+"#
        ]
        for (index, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            let replacement = index == 0 ? "$1***:***@" : (index == 1 ? "$1/$2/***/***" : "$1***")
            value = regex.stringByReplacingMatches(in: value, range: range, withTemplate: replacement)
        }
        return value
    }
}

enum DiagnosticProfile {
    static func carPlayEntitlements() -> String {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let message = try? Data(contentsOf: url),
              let plistData = embeddedProfilePlist(in: message),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let profileEntitlements = plist["Entitlements"] as? [String: Any] else { return "entitlements-unavailable" }
        let keys = profileEntitlements.keys.filter { $0.hasPrefix("com.apple.developer.carplay-") }.sorted()
        return keys.isEmpty ? "none" : keys.map { "\($0)=\(profileEntitlements[$0] ?? "nil")" }.joined(separator: ", ")
    }

    private static func embeddedProfilePlist(in cmsMessage: Data) -> Data? {
        let header = Data("<?xml".utf8)
        let openingTag = Data("<plist".utf8)
        let closingTag = Data("</plist>".utf8)
        guard let start = cmsMessage.range(of: header)?.lowerBound ?? cmsMessage.range(of: openingTag)?.lowerBound,
              let end = cmsMessage.range(of: closingTag, in: start..<cmsMessage.endIndex)?.upperBound else { return nil }
        return cmsMessage.subdata(in: start..<end)
    }

    static func recordAppLaunch() {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        var system = utsname()
        uname(&system)
        let model = withUnsafePointer(to: &system.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: system.machine)) { String(cString: $0) }
        }
        let entitlements = carPlayEntitlements()
        DiagnosticLog.shared.setSummaryValue("الصلاحيات في profile", value: entitlements)
        if UserDefaults.standard.string(forKey: "wudcar.diagnostic.summary.آخر حالة شاشة خارجية") == nil {
            DiagnosticLog.shared.setSummaryValue("آخر حالة شاشة خارجية", value: "لا — لم تتصل شاشة خارجية في هذا السجل")
        }
        WDLog.car("\(WD_BUILD_TAG) | version=\(version) build=\(build) iOS=\(UIDevice.current.systemVersion) device=\(model) profileCarPlay=[\(entitlements)]")
    }
}

extension DiagnosticLog {
    static func recordScreens(event: String) {
        let screens = UIScreen.screens.map { "\(Int($0.bounds.width))x\(Int($0.bounds.height))@\($0.scale)" }
        WDLog.car("screens \(event) count=\(screens.count) sizes=[\(screens.joined(separator: ","))]")
    }
}
