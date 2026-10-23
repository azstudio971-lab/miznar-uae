import Foundation

/// مفاتيح الإعدادات المحفوظة
enum WDKeys {
    static let lockVideoWhileDriving = "wd.lockVideoWhileDriving"
    static let phoneDesktopMode = "wd.phoneDesktopMode"
    static let carZoom = "wd.carZoom"
    static let carInputLanguage = "wd.carInputLanguage"
    static let carDesktopMode = "wd.carDesktopMode"
    static let carLanguage = "wd.carLanguage"
    static let language = "wd.language"
    static let appearance = "wd.appearance"
}

enum WDSettings {
    private static var defaults: UserDefaults { .standard }

    /// يوقف الفيديو عند حركة السيارة إذا اختار المستخدم تفعيل ذلك
    static var lockVideoWhileDriving: Bool {
        get { defaults.object(forKey: WDKeys.lockVideoWhileDriving) as? Bool ?? true }
        set { defaults.set(newValue, forKey: WDKeys.lockVideoWhileDriving) }
    }

    /// متصفح الهاتف يفتح المواقع بنسخة سطح المكتب افتراضياً (مثل CarTV)
    static var phoneDesktopMode: Bool {
        get { defaults.object(forKey: WDKeys.phoneDesktopMode) as? Bool ?? true }
        set { defaults.set(newValue, forKey: WDKeys.phoneDesktopMode) }
    }

    /// حجم النص في متصفح السيارة
    static var carZoom: Double {
        get {
            migrateBrowserZoom(in: defaults)
            let stored = defaults.object(forKey: WDKeys.carZoom) as? Double ?? 1.0
            return min(1.5, max(0.5, stored))
        }
        set {
            migrateBrowserZoom(in: defaults)
            defaults.set(min(1.5, max(0.5, newValue)), forKey: WDKeys.carZoom)
        }
    }

    static func migrateBrowserZoom(in storage: UserDefaults) {
        let migration = "wd.browserZoom160Migrated"
        guard !storage.bool(forKey: migration) else { return }
        if storage.object(forKey: WDKeys.carZoom) == nil || storage.double(forKey: WDKeys.carZoom) == 0.5 {
            storage.set(1.0, forKey: WDKeys.carZoom)
        }
        storage.set(true, forKey: migration)
    }

    /// لغة واجهة CarPlay: "ar" أو "en"
    static var carLanguage: String {
        get { defaults.string(forKey: WDKeys.carLanguage) ?? "ar" }
        set { defaults.set(newValue == "en" ? "en" : "ar", forKey: WDKeys.carLanguage) }
    }

    /// فتح صفحات السيارة بوضع سطح المكتب افتراضياً
    static var carDesktopMode: Bool {
        get { defaults.object(forKey: WDKeys.carDesktopMode) as? Bool ?? true }
        set { defaults.set(newValue, forKey: WDKeys.carDesktopMode) }
    }

    /// لغة الكتابة في شاشة السيارة: "ar" أو "en"
    static var carInputIsArabic: Bool {
        get { (defaults.string(forKey: WDKeys.carInputLanguage) ?? "ar") == "ar" }
        set { defaults.set(newValue ? "ar" : "en", forKey: WDKeys.carInputLanguage) }
    }
}

/// نصوص واجهة CarPlay حسب اللغة المختارة من إعدادات السيارة.
func carTr(_ arabic: String, _ english: String) -> String {
    WDSettings.carLanguage == "en" ? english : arabic
}

