import Foundation

/// مفاتيح الإعدادات المحفوظة
enum WDKeys {
    static let lockVideoWhileDriving = "wd.lockVideoWhileDriving"
    static let phoneDesktopMode = "wd.phoneDesktopMode"
    static let carZoom = "wd.carZoom.compact.v2"
    static let carDesktopMode = "wd.carDesktopMode"
    static let carLanguage = "wd.carLanguage"
    static let carInputLanguage = "wd.carInputLanguage"
    static let language = "wd.language"
    static let appearance = "wd.appearance"
}

enum WDSettings {
    private static var defaults: UserDefaults { .standard }

    /// إيقاف الفيديو تلقائياً عند حركة السيارة (مفعّل افتراضياً)
    static var lockVideoWhileDriving: Bool {
        get { defaults.object(forKey: WDKeys.lockVideoWhileDriving) as? Bool ?? true }
        set { defaults.set(newValue, forKey: WDKeys.lockVideoWhileDriving) }
    }

    /// متصفح الهاتف يفتح المواقع بنسخة سطح المكتب افتراضياً (مثل CarTV)
    static var phoneDesktopMode: Bool {
        get { defaults.object(forKey: WDKeys.phoneDesktopMode) as? Bool ?? true }
        set { defaults.set(newValue, forKey: WDKeys.phoneDesktopMode) }
    }

    static var carDesktopMode: Bool {
        get { defaults.object(forKey: WDKeys.carDesktopMode) as? Bool ?? true }
        set { defaults.set(newValue, forKey: WDKeys.carDesktopMode) }
    }
    static var carLanguage: String {
        get { defaults.string(forKey: WDKeys.carLanguage) ?? "ar" }
        set { defaults.set(newValue, forKey: WDKeys.carLanguage) }
    }

    /// حجم النص في متصفح السيارة
    static var carZoom: Double {
        get { defaults.object(forKey: WDKeys.carZoom) as? Double ?? 0.75 }
        set { defaults.set(newValue, forKey: WDKeys.carZoom) }
    }

    /// لغة الكتابة في شاشة السيارة: "ar" أو "en"
    static var carInputIsArabic: Bool {
        get { (defaults.string(forKey: WDKeys.carInputLanguage) ?? "ar") == "ar" }
        set { defaults.set(newValue ? "ar" : "en", forKey: WDKeys.carInputLanguage) }
    }
}
