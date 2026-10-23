import SwiftUI
import AVFoundation
import AVKit
import CoreMedia
import UniformTypeIdentifiers

extension PlayerPreferences {
    static func number(_ key: String, _ fallback: Double) -> Double { UserDefaults.standard.object(forKey: "wd.media." + key) as? Double ?? fallback }
    static func flag(_ key: String, _ fallback: Bool) -> Bool { UserDefaults.standard.object(forKey: "wd.media." + key) as? Bool ?? fallback }
    static func text(_ key: String, _ fallback: String) -> String { UserDefaults.standard.string(forKey: "wd.media." + key) ?? fallback }
    static var gravity: AVLayerVideoGravity {
        switch text("gravity", "fit") { case "fill": return .resizeAspectFill; case "stretch": return .resize; default: return .resizeAspect }
    }
    static var styleRules: [AVTextStyleRule] {
        let yellow = text("subtitleColor", "white") == "yellow"
        let position = number("subtitlePosition", 90)
        let attributes: [String: Any] = [
            kCMTextMarkupAttribute_RelativeFontSize as String: number("subtitleSize", 100),
            kCMTextMarkupAttribute_ForegroundColorARGB as String: [1.0, 1.0, 1.0, yellow ? 0.0 : 1.0],
            kCMTextMarkupAttribute_BackgroundColorARGB as String: [number("subtitleOpacity", 0.6), 0.0, 0.0, 0.0],
            kCMTextMarkupAttribute_OrthogonalLinePositionPercentageRelativeToWritingDirection as String: position
        ]
        return AVTextStyleRule(textMarkupAttributes: attributes).map { [$0] } ?? []
    }
    static func reset() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("wd.media.") { UserDefaults.standard.removeObject(forKey: key) }
        PlaybackManager.shared.applyPreferences()
    }
}

struct PlayerOptionsView: View {
    @AppStorage("wd.media.subtitleSize") private var subtitleSize = 100.0
    @AppStorage("wd.media.subtitleColor") private var color = "white"
    @AppStorage("wd.media.subtitleOpacity") private var opacity = 0.6
    @AppStorage("wd.media.subtitlePosition") private var position = 90.0
    @AppStorage("wd.media.subtitleEncoding") private var encoding = "utf8"
    @AppStorage("wd.media.audioLanguage") private var audioLanguage = "ar"
    @AppStorage("wd.media.gravity") private var gravity = "fit"
    @AppStorage("wd.media.autoFullscreen") private var autoFullscreen = true
    @AppStorage("wd.media.rate") private var rate = 1.0
    @AppStorage("wd.media.pip") private var pip = true
    @AppStorage("wd.media.buffer") private var buffer = 0.0
    @AppStorage("wd.media.timeout") private var timeout = 30.0
    @AppStorage("wd.media.userAgent") private var userAgent = "WudCar/3.0.1"
    @State private var importSubtitle = false
    @State private var sleepMinutes = 0
    @State private var error: String?
    @ObservedObject private var playback = PlaybackManager.shared
    var body: some View {
        Form {
            Section(tr("الترجمة", "Subtitles")) {
                NavigationLink(tr("تشغيل الترجمة والتفضيلات", "Subtitle and playback preferences")) { MediaSettingsView() }
                Picker(tr("حجم الخط", "Font size"), selection: $subtitleSize) {
                    Text(tr("صغير", "Small")).tag(75.0); Text(tr("متوسط", "Medium")).tag(100.0)
                    Text(tr("كبير", "Large")).tag(125.0); Text(tr("كبير جداً", "Extra large")).tag(150.0)
                }
                Picker(tr("اللون", "Color"), selection: $color) { Text(tr("أبيض", "White")).tag("white"); Text(tr("أصفر", "Yellow")).tag("yellow") }
                Slider(value: $opacity, in: 0...1) { Text(tr("شفافية الخلفية", "Background opacity")) }
                Picker(tr("موضع الترجمة", "Subtitle position"), selection: $position) { Text(tr("أسفل", "Bottom")).tag(90.0); Text(tr("وسط", "Center")).tag(50.0); Text(tr("أعلى", "Top")).tag(10.0) }
                Picker(tr("الترميز", "Encoding"), selection: $encoding) { Text("UTF-8").tag("utf8"); Text("Windows-1256").tag("windows1256") }
                Button(tr("تحميل ملف SRT / VTT", "Load SRT / VTT")) { importSubtitle = true }.disabled(playback.current == nil)
                MediaTrackPicker(characteristic: .legible)
                Text(tr("الترجمة الخارجية تظهر على الهاتف فقط؛ للشاشة الخارجية استخدم الترجمة المدمجة.", "External subtitles display on iPhone only; use embedded subtitles for external screens.")).font(.footnote)
            }
            Section(tr("الصوت", "Audio")) {
                Picker(tr("لغة الصوت المفضلة", "Preferred audio language"), selection: $audioLanguage) { Text("العربية").tag("ar"); Text("English").tag("en") }
                MediaTrackPicker(characteristic: .audible)
                Button(tr("تحسين الحوار إن توفر مسار مخصص", "Use enhanced-dialogue track if available")) { playback.selectEnhancedDialogue() }.disabled(!playback.hasEnhancedDialogue)
            }
            Section(tr("العرض والتشغيل", "Display and playback")) {
                Picker(tr("ملاءمة الصورة", "Video fit"), selection: $gravity) { Text("Fit").tag("fit"); Text("Fill").tag("fill"); Text("Stretch").tag("stretch") }
                Toggle(tr("ملء الشاشة تلقائياً عند بدء التشغيل", "Auto full screen when playback begins"), isOn: $autoFullscreen)
                Picker(tr("السرعة الافتراضية — الهاتف فقط", "Default rate — iPhone only"), selection: $rate) { ForEach([0.5, 0.75, 1, 1.25, 1.5, 1.75, 2], id: \.self) { Text(String(format: "%.2g×", $0)).tag($0) } }
                Toggle(tr("صورة داخل صورة", "Picture in Picture"), isOn: $pip)
                Picker(tr("مؤقت النوم", "Sleep timer"), selection: $sleepMinutes) { Text(tr("إيقاف", "Off")).tag(0); ForEach([15,30,60], id: \.self) { Text("\($0) " + tr("دقيقة", "min")).tag($0) } }
                    .onChange(of: sleepMinutes) { _, value in playback.setSleepTimer(minutes: value) }
            }
            Section(tr("الشبكة — لمصادر المشغّل فقط", "Network — player sources only")) {
                Picker(tr("التخزين المؤقت", "Forward buffer"), selection: $buffer) { Text(tr("تلقائي", "Automatic")).tag(0.0); ForEach([5.0, 15.0, 30.0, 60.0], id: \.self) { Text("\(Int($0)) s").tag($0) } }
                Stepper(tr("مهلة بدء الاتصال: ", "Startup timeout: ") + "\(Int(timeout)) s", value: $timeout, in: 10...120, step: 5)
                TextField("User-Agent", text: $userAgent).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text(tr("تُطبق مهلة البدء وUser-Agent على المصدر التالي. لا تتغير إعدادات المتصفح.", "Startup timeout and User-Agent apply to the next source. Browser settings are unchanged.")).font(.footnote)
            }
            Button(tr("إعادة ضبط إعدادات المشغّل", "Reset player settings"), role: .destructive) { PlayerPreferences.reset() }
        }.navigationTitle(tr("المشغّل", "Player"))
            .onDisappear { playback.applyPreferences() }
            .fileImporter(isPresented: $importSubtitle, allowedContentTypes: [UTType(filenameExtension: "srt") ?? .plainText, UTType(filenameExtension: "vtt") ?? .plainText]) { result in
                do { let url = try result.get(); if let media = playback.current?.url { try ExternalSubtitles.shared.load(url, for: media) } } catch { self.error = error.localizedDescription }
            }
            .alert(tr("تعذر تحميل الترجمة", "Subtitle import failed"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}
struct MediaTrackPicker: View {
    let characteristic: AVMediaCharacteristic
    @ObservedObject private var playback = PlaybackManager.shared
    var body: some View {
        if let item = playback.player.currentItem, let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) {
            Menu(characteristic == .legible ? tr("مسار الترجمة", "Subtitle track") : tr("مسار الصوت", "Audio track")) {
                if characteristic == .legible { Button(tr("إيقاف", "Off")) { item.select(nil, in: group) } }
                ForEach(Array(group.options.enumerated()), id: \.offset) { _, option in Button(option.displayName) { item.select(option, in: group) } }
            }
        }
    }
}
