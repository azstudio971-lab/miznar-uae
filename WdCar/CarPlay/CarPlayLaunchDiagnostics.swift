import Foundation
import UIKit
import SwiftUI
import Combine

/// Local, bounded lifecycle events only: never URLs, media titles or account data.
final class CarPlayLaunchDiagnostics: ObservableObject {
    static let shared = CarPlayLaunchDiagnostics()
    private static let key = "wd.carplay.lifecycle"
    @Published private(set) var events: [String]
    init(storage: UserDefaults = .standard) {
        self.storage = storage
        events = storage.stringArray(forKey: Self.key) ?? []
    }
    private let storage: UserDefaults
    func record(_ event: String) {
        let apply = {
            self.events = Array((self.events + [ISO8601DateFormatter().string(from: Date()) + " " + event]).suffix(20))
            self.storage.set(self.events, forKey: Self.key)
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }
    var report: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "WudCar \(info["CFBundleShortVersionString"] ?? "?") (\(info["CFBundleVersion"] ?? "?"))\niOS \(UIDevice.current.systemVersion)\n" + events.joined(separator: "\n")
    }
}

struct CarPlayConnectionView: View {
    @ObservedObject private var diagnostics = CarPlayLaunchDiagnostics.shared
    var body: some View {
        List {
            Section {
                Text(tr("مشغّل للفيديو والصوت", "Video and audio player")).font(.headline)
                Text(tr("إذا بقيت شاشة السيارة فارغة بعد إعادة الاتصال، شارك هذا التقرير مع الدعم لتحديد وصول مشهد CarPlay ونتيجة فتح القالب. لا يتضمن التقرير مصادر المحتوى أو حساباتك.", "If the car display remains blank after reconnecting, share this report with support to identify whether CarPlay connected its scene and installed the template. It contains no media sources or account details."))
                ShareLink(item: diagnostics.report) { Label(tr("مشاركة تقرير الاتصال", "Share connection report"), systemImage: "square.and.arrow.up") }
            }
            Section(tr("سجل الاتصال المحلي", "Local connection log")) {
                Text(diagnostics.report).font(.footnote.monospaced()).textSelection(.enabled)
            }
        }.navigationTitle(tr("فحص اتصال CarPlay", "CarPlay connection check"))
    }
}
