import SwiftUI

// MARK: - ألوان هوية WudCar (مأخوذة من الشعار الرسمي)

extension Color {
    /// الأزرق الداكن في خلفية الشعار
    static let wdNavy = Color(red: 1 / 255, green: 55 / 255, blue: 72 / 255)
    /// البرتقالي (الشمس في الشعار) — لون التمييز في التطبيق
    static let wdAccent = Color(red: 254 / 255, green: 177 / 255, blue: 59 / 255)
}

// MARK: - اللغة ووضع العرض

enum AppLanguage: String, CaseIterable, Identifiable {
    case ar, en
    var id: String { rawValue }
    var title: String { self == .ar ? "العربية" : "English" }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var title: String {
        switch self {
        case .system: return tr("تلقائي", "Automatic")
        case .light: return tr("فاتح", "Light")
        case .dark: return tr("داكن", "Dark")
        }
    }
}

enum L10n {
    static var language: AppLanguage {
        if let saved = UserDefaults.standard.string(forKey: WDKeys.language), let lang = AppLanguage(rawValue: saved) {
            return lang
        }
        return (Locale.preferredLanguages.first ?? "ar").hasPrefix("ar") ? .ar : .en
    }

    static var isArabic: Bool { language == .ar }
}

/// نص باللغتين حسب لغة التطبيق المختارة
func tr(_ arabic: String, _ english: String) -> String {
    L10n.isArabic ? arabic : english
}
