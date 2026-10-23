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
    @AppStorage(WDKeys.lockVideoWhileDriving) private var lockVideo = true
    @AppStorage("wd.media.skip") private var skip = 15
    @AppStorage("wd.media.resume") private var resume = true
    @AppStorage("wd.media.autoNext") private var autoNext = false
    @AppStorage("wd.media.subtitles") private var subtitles = true
    @AppStorage("wd.media.subtitleLanguage") private var subtitleLanguage = "ar"
    @ObservedObject private var library = MediaLibrary.shared

    var body: some View {
        Form {
            Section(tr("التشغيل", "Playback")) {
                Picker(tr("التقديم والتأخير", "Skip interval"), selection: $skip) {
                    ForEach([10, 15, 30], id: \.self) { Text("\($0) " + tr("ثانية", "seconds")).tag($0) }
                }
                Toggle(tr("الاستئناف من آخر موضع", "Resume from last position"), isOn: $resume)
                Toggle(tr("تشغيل العنصر التالي تلقائيًا", "Automatically play next"), isOn: $autoNext)

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
            Section(tr("التخزين", "Storage")) {
                LabeledContent(tr("الملفات المستوردة", "Imported files"), value: ByteCountFormatter.string(fromByteCount: library.importedBytes, countStyle: .file))
                NavigationLink(tr("إدارة الملفات والمكتبة", "Manage files and library")) { MediaLibraryView() }
                Text(tr("إزالة ملف من المكتبة تحذف نسخة التطبيق فقط. يتولى النظام ذاكرة البث المؤقتة.", "Removing a library file deletes only the app copy. Streaming buffers are managed by the system.")).font(.footnote)
            }
            Section("AirPlay") {
                Text(tr("شغّل فيديو ثم افتح زر AirPlay داخل المشغّل لاختيار جهاز متوافق. عرض الفيديو بالسيارة يحدده النظام والسيارة؛ دعم الفيديو وحده ليس إثباتًا للسماح بعرضه الآن.", "Play a video, then use AirPlay in the player to choose a compatible device. The system and vehicle control car video presentation; video support alone does not establish current permission."))
            }
            Section {
                Toggle(tr("إيقاف فيديو الهاتف أثناء القيادة", "Pause iPhone video while driving"), isOn: $lockVideo)
                    .onChange(of: lockVideo) { _, enabled in
                        if enabled { DrivingMonitor.shared.requestMonitoringPermission() }
                        PlaybackManager.shared.enforceSafety()
                    }
            } header: {
                Text(tr("الفيديو على الهاتف", "Video on iPhone"))
            } footer: {
                Text(tr("اتبع ارشادات وقوانين المرور في بلدك", "Follow the traffic guidance and laws in your country"))
            }

        }.navigationTitle(tr("إعدادات المشغّل", "Player settings"))
    }
}
