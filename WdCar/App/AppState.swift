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

/// هل السيارة المتصلة تعلن دعم الفيديو (ميزة Video in Car)؟
enum CarVideoSupport {
    case unknown
    case supported
    case unsupported
}

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published private(set) var carMode: CarDisplayMode = .none
    @Published private(set) var carVideoSupport: CarVideoSupport = .unknown
    /// التحديث 3: متصفح ود كار معروض على شاشة السيارة كشاشة خارجية (مثل CarTV)
    @Published private(set) var carScreenActive = false
    @Published private(set) var carScreenInteractive = false
    /// طلب من CarPlay لعرض نافذة «شاشة السيارة» على الهاتف
    @Published var showCarScreenHelp = false

    var carScreenText: String {
        guard carScreenActive else { return tr("غير معروض", "Not shown") }
        return carScreenInteractive ? tr("المتصفح يعمل — اللمس مفعّل", "Browser running — touch enabled")
                                    : tr("المتصفح يعمل — التحكم من الهاتف", "Browser running — control from iPhone")
    }

    func carScreenConnected(interactive: Bool) {
        onMain {
            self.carScreenActive = true
            self.carScreenInteractive = interactive
            self.showCarScreenHelp = false
            DrivingMonitor.shared.start()
            self.showToast(tr("المتصفح يعمل على شاشة السيارة 🚗", "Browser is on the car screen 🚗"))
        }
    }

    func carScreenDisconnected() {
        onMain {
            self.carScreenActive = false
            self.carScreenInteractive = false
            if self.carMode == .none { DrivingMonitor.shared.stop() }
        }
    }
    @Published private(set) var toast: String?

    var isCarConnected: Bool { carMode != .none }

    var carStatusText: String {
        switch carMode {
        case .none: return tr("غير متصل", "Not connected")
        case .window: return tr("متصل — المتصفح الكامل", "Connected — full browser")
        case .templates: return tr("متصل — وضع القوالب (الفيديو عبر AirPlay)", "Connected — templates mode (video via AirPlay)")
        }
    }

    /// نص حالة دعم الفيديو في السيارة (للإعدادات والرئيسية)
    var carVideoText: String {
        guard isCarConnected else { return tr("غير متصل", "Not connected") }
        switch carVideoSupport {
        case .unknown: return tr("جارِ التحقق…", "Checking…")
        case .supported: return tr("مدعوم ✓", "Supported ✓")
        case .unsupported: return tr("غير مدعوم — الصوت فقط", "Not supported — audio only")
        }
    }

    func carConnected(mode: CarDisplayMode) {
        onMain {
            self.carMode = mode
            self.carVideoSupport = .unknown
            DrivingMonitor.shared.start()
        }
    }

    func carDisconnected() {
        onMain {
            self.carMode = .none
            self.carVideoSupport = .unknown
            DrivingMonitor.shared.stop()
            CarKeyboardBridge.shared.cancel()
        }
    }

    /// تحديث حالة دعم الفيديو كما تعلنها السيارة عبر CPSessionConfiguration
    func updateCarVideoSupport(_ supported: Bool) {
        onMain {
            let newValue: CarVideoSupport = supported ? .supported : .unsupported
            guard self.carVideoSupport != newValue else { return }
            self.carVideoSupport = newValue
            if !supported {
                self.showToast(tr("السيارة لا تعلن دعم الفيديو — سيصل الصوت فقط",
                                  "The car does not report video support — audio only"))
            }
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
