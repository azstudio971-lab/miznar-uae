import SwiftUI
import AVFoundation

enum PlayerPreferences {
    static let prefix = "wd.media."
    static func value<T>(_ key: String, _ fallback: T) -> T { UserDefaults.standard.object(forKey: prefix + key) as? T ?? fallback }
    static var skip: Int { let n = value("skip", 15); return [10,15,30].contains(n) ? n : 15 }
    static var resume: Bool { value("resume", true) }
    static var autoNext: Bool { value("autoNext", false) }
    static var subtitles: Bool { value("subtitles", true) }
    static var subtitleLanguage: String { value("subtitleLanguage", "ar") }
    static var audioLanguage: String { value("audioLanguage", "ar") }
    static var subtitleSize: Double { value("subtitleSize", 100.0) }
    static var yellow: Bool { value("yellow", false) }
    static var background: Double { value("background", 0.6) }
    static var rate: Float { Float(value("rate", 1.0)) }
    static var buffer: Double { value("buffer", 0.0) }
    static var timeout: Double { value("timeout", 30.0) }
    static var pip: Bool { value("pip", true) }
    static var rotate: Bool { value("rotate", true) }
    static var gravity: AVLayerVideoGravity {
        switch value("gravity", "fit") { case "fill": return .resizeAspectFill; case "stretch": return .resize; default: return .resizeAspect }
    }
    static func reset() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(prefix) { UserDefaults.standard.removeObject(forKey: key) }
    }
}

struct MediaSettingsView: View {
    @AppStorage("wd.media.skip") private var skip = 15
    @AppStorage("wd.media.resume") private var resume = true
    @AppStorage("wd.media.autoNext") private var autoNext = false
    @AppStorage("wd.media.subtitles") private var subtitles = true
    @AppStorage("wd.media.subtitleLanguage") private var subtitleLanguage = "ar"
    @AppStorage("wd.media.audioLanguage") private var audioLanguage = "ar"
    @AppStorage("wd.media.subtitleSize") private var subtitleSize = 100.0
    @AppStorage("wd.media.yellow") private var yellow = false
    @AppStorage("wd.media.background") private var background = 0.6
    @AppStorage("wd.media.rate") private var rate = 1.0
    @AppStorage("wd.media.gravity") private var gravity = "fit"
    @AppStorage("wd.media.rotate") private var rotate = true
    @AppStorage("wd.media.pip") private var pip = true
    @AppStorage("wd.media.buffer") private var buffer = 0.0
    @AppStorage("wd.media.timeout") private var timeout = 30.0
    @State private var sleep = 0
    var body: some View {
        Form {
            Section(tr("الترجمة", "Subtitles")) {
                Toggle(tr("تشغيل الترجمة", "Enable subtitles"), isOn: $subtitles)
                languagePicker(tr("لغة الترجمة", "Subtitle language"), selection: $subtitleLanguage)
                Picker(tr("حجم الخط", "Text size"), selection: $subtitleSize) {
                    Text(tr("صغير", "Small")).tag(75.0); Text(tr("متوسط", "Medium")).tag(100.0)
                    Text(tr("كبير", "Large")).tag(150.0); Text(tr("كبير جداً", "Extra large")).tag(200.0)
                }
                Toggle(tr("لون أصفر (بدلاً من الأبيض)", "Yellow text (instead of white)"), isOn: $yellow)
                Slider(value: $background, in: 0...1) { Text(tr("شفافية الخلفية السوداء", "Black background opacity")) }
                Text(tr("حمّل ملف SRT أو VTT من قائمة المشغّل لفيديو محلي. الترجمة الخارجية على الهاتف فقط.", "Load SRT or VTT from the player menu for a local video. External captions are iPhone only.")).font(.footnote)
            }
            Section(tr("الصوت", "Audio")) { languagePicker(tr("لغة الصوت المفضلة", "Preferred audio language"), selection: $audioLanguage) }
            Section(tr("العرض على الهاتف", "iPhone display")) {
                Picker(tr("حجم الفيديو", "Video layout"), selection: $gravity) {
                    Text(tr("ملاءمة", "Fit")).tag("fit"); Text(tr("ملء", "Fill")).tag("fill"); Text(tr("تمديد", "Stretch")).tag("stretch")
                }
                Toggle(tr("ملء الشاشة عند التدوير", "Fullscreen on rotation"), isOn: $rotate)
            }
            Section(tr("التشغيل", "Playback")) {
                Picker(tr("مدة القفز", "Skip interval"), selection: $skip) { ForEach([10,15,30], id: \.self) { Text("\($0) s").tag($0) } }
                Toggle(tr("الاستكمال من آخر موضع", "Resume playback"), isOn: $resume)
                Toggle(tr("تشغيل التالي تلقائياً", "Play next automatically"), isOn: $autoNext)
                Picker(tr("السرعة على الهاتف", "iPhone playback speed"), selection: $rate) { ForEach([0.5,0.75,1,1.25,1.5,1.75,2], id: \.self) { Text(String(format: "%.2g×", $0)).tag($0) } }
                Picker(tr("مؤقت النوم", "Sleep timer"), selection: $sleep) {
                    Text(tr("إيقاف", "Off")).tag(0)
                    ForEach([15,30,60,90], id: \.self) { Text("\($0) min").tag($0) }
                }.onChange(of: sleep) { _, value in PlaybackManager.shared.setSleepTimer(minutes: value) }
                Toggle(tr("صورة داخل صورة", "Picture in Picture"), isOn: $pip)
            }
            Section(tr("الشبكة", "Network")) {
                Picker(tr("التخزين المؤقت", "Forward buffer"), selection: $buffer) { ForEach([0.0,5,15,30,60], id: \.self) { Text($0 == 0 ? tr("تلقائي", "Automatic") : "\(Int($0)) s").tag($0) } }
                Picker(tr("مهلة الاتصال", "Connection timeout"), selection: $timeout) { ForEach([15.0,30,60,120], id: \.self) { Text("\(Int($0)) s").tag($0) } }
            }
            Button(tr("إعادة ضبط إعدادات المشغّل", "Reset player settings"), role: .destructive) { PlayerPreferences.reset(); sleep = 0; PlaybackManager.shared.setSleepTimer(minutes: 0) }
        }.navigationTitle(tr("إعدادات المشغّل", "Player settings"))
    }
    private func languagePicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            Text("العربية").tag("ar"); Text("English").tag("en"); Text("Français").tag("fr"); Text("हिन्दी").tag("hi")
        }
    }
}
