import SwiftUI

enum PlayerPreferences {
    static var skip: Int {
        let value = UserDefaults.standard.integer(forKey: "wd.media.skip")
        return [10, 15, 30].contains(value) ? value : 15
    }
    static var resume: Bool { UserDefaults.standard.object(forKey: "wd.media.resume") as? Bool ?? true }
    static var autoNext: Bool { UserDefaults.standard.bool(forKey: "wd.media.autoNext") }
    static var subtitles: Bool { UserDefaults.standard.object(forKey: "wd.media.subtitles") as? Bool ?? true }
    static var subtitleLanguage: String { UserDefaults.standard.string(forKey: "wd.media.subtitleLanguage") ?? "ar" }
    static var fill: Bool { UserDefaults.standard.bool(forKey: "wd.media.fill") }
}

struct MediaSettingsView: View {
    @AppStorage("wd.media.skip") private var skip = 15
    @AppStorage("wd.media.resume") private var resume = true
    @AppStorage("wd.media.autoNext") private var autoNext = false
    @AppStorage("wd.media.subtitles") private var subtitles = true
    @AppStorage("wd.media.subtitleLanguage") private var subtitleLanguage = "ar"
    @AppStorage("wd.media.fill") private var fill = false
    @AppStorage("wd.media.externalSubtitles") private var externalSubtitles = true
    @AppStorage("wd.media.subtitleSize") private var subtitleSize = 22.0
    @AppStorage("wd.media.subtitleDelay") private var subtitleDelay = 0.0
    @AppStorage("wd.media.subtitleYellow") private var subtitleYellow = false
    @AppStorage("wd.media.subtitleBackground") private var subtitleBackground = true
    @ObservedObject private var library = MediaLibrary.shared

    var body: some View {
        Form {
            Section(tr("التشغيل", "Playback")) {
                Picker(tr("التقديم والتأخير", "Skip interval"), selection: $skip) {
                    ForEach([10, 15, 30], id: \.self) { Text("\($0) " + tr("ثانية", "seconds")).tag($0) }
                }
                Toggle(tr("الاستئناف من آخر موضع", "Resume from last position"), isOn: $resume)
                Toggle(tr("تشغيل العنصر التالي تلقائيًا", "Automatically play next"), isOn: $autoNext)
                Toggle(tr("ملء الشاشة بقص الحواف", "Fill screen by cropping edges"), isOn: $fill)
            }
            Section {
                Toggle(tr("تفعيل الترجمة المضمنة", "Enable embedded subtitles"), isOn: $subtitles)
                Picker(tr("لغة الترجمة المفضلة", "Preferred subtitle language"), selection: $subtitleLanguage) {
                    Text("العربية").tag("ar")
                    Text("English").tag("en")
                }
                Text(tr("تظهر مسارات الصوت والترجمة المتوفرة داخل المشغّل الأصلي. التفضيلات تطبق عند فتح المحتوى.", "Available audio and subtitle tracks appear in the native player. Preferences apply when content opens."))
                    .font(.footnote).foregroundStyle(.secondary)
            } header: { Text(tr("الترجمة", "Subtitles")) }
            Section {
                Toggle(tr("عرض الترجمة الخارجية", "Show external subtitles"), isOn: $externalSubtitles)
                Slider(value: $subtitleSize, in: 14...40, step: 1) { Text(tr("حجم الخط", "Font size")) }
                Toggle(tr("لون أصفر", "Yellow text"), isOn: $subtitleYellow)
                Toggle(tr("خلفية الترجمة", "Subtitle background"), isOn: $subtitleBackground)
                Stepper(tr("تأخير الترجمة: ", "Subtitle delay: ") + String(format: "%.1f s", subtitleDelay), value: $subtitleDelay, in: -30...30, step: 0.5)
                Text(tr("استيراد SRT/VTT من قائمة المشغّل. هذه الترجمة تظهر على الهاتف فقط ولا تُرسل عبر AirPlay أو CarPlay أو صورة داخل صورة. للعرض الخارجي استخدم ترجمة مضمّنة في المصدر.", "Import SRT/VTT from the player menu. These captions display on iPhone only, not AirPlay, CarPlay or Picture in Picture. Use embedded source subtitles for external playback.")).font(.footnote)
            } header: { Text(tr("ترجمة خارجية على الهاتف", "External subtitles on iPhone")) }
            Section(tr("التخزين", "Storage")) {
                LabeledContent(tr("الملفات المستوردة", "Imported files"), value: ByteCountFormatter.string(fromByteCount: library.importedBytes, countStyle: .file))
                NavigationLink(tr("إدارة الملفات والمكتبة", "Manage files and library")) { MediaLibraryView() }
                Text(tr("إزالة ملف من المكتبة تحذف نسخة التطبيق فقط. يتولى النظام ذاكرة البث المؤقتة.", "Removing a library file deletes only the app copy. Streaming buffers are managed by the system.")).font(.footnote)
            }
            Section("AirPlay") {
                Text(tr("شغّل فيديو ثم افتح زر AirPlay داخل المشغّل لاختيار جهاز متوافق. عرض الفيديو بالسيارة يحدده النظام والسيارة؛ دعم الفيديو وحده ليس إثباتًا للسماح بعرضه الآن.", "Play a video, then use AirPlay in the player to choose a compatible device. The system and vehicle control car video presentation; video support alone does not establish current permission."))
            }
        }.navigationTitle(tr("إعدادات المشغّل", "Player settings"))
    }
}
