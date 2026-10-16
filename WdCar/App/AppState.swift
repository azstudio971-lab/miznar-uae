import SwiftUI
import Combine

/// طريقة عرض ود كار على شاشة السيارة
enum CarDisplayMode: String {
    /// السيارة غير متصلة
    case none
    /// النظام أعطى التطبيق نافذة حرة: متصفح كامل على شاشة السيارة
    case window
    /// قوالب CarPlay فقط: تصفح بالقوائم والفيديو يُبث عبر AirPlay
    case templates
}

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published private(set) var carMode: CarDisplayMode = .none
    @Published private(set) var toast: String?

    var isCarConnected: Bool { carMode != .none }

    var carStatusText: String {
        switch carMode {
        case .none: return "غير متصل"
        case .window: return "متصل — المتصفح الكامل"
        case .templates: return "متصل — وضع القوالب (الفيديو عبر AirPlay)"
        }
    }

    func carConnected(mode: CarDisplayMode) {
        onMain {
            self.carMode = mode
            DrivingMonitor.shared.start()
        }
    }

    func carDisconnected() {
        onMain {
            self.carMode = .none
            DrivingMonitor.shared.stop()
            CarKeyboardBridge.shared.cancel()
        }
    }

    func showToast(_ text: String) {
        onMain {
            self.toast = text
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
                if self?.toast == text { self?.toast = nil }
            }
        }
    }

    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }
}
