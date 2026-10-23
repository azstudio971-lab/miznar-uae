import SwiftUI
import Translation

struct SubtitleTranslationView: View {
    @ObservedObject private var subtitles = ExternalSubtitles.shared
    @State private var source = "en"
    @State private var target = "ar"
    @State private var configuration: TranslationSession.Configuration?
    @State private var progress: String?
    @State private var error: String?
    var body: some View {
        Form {
            Text(tr("تُترجم ملفات الترجمة الخارجية على الجهاز. حمّل ملف SRT أو VTT من إعدادات المشغّل أولاً.", "Translate external subtitles on-device. Load an SRT or VTT file in Player settings first."))
            Picker(tr("اللغة الأصلية", "Source language"), selection: $source) { languages }
            Picker(tr("ترجمة إلى", "Translate to"), selection: $target) { languages }
            Button(tr("ترجمة ملف الترجمة", "Translate subtitles")) {
                if configuration == nil { configuration = .init(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target)) } else { configuration?.invalidate() }
            }.disabled(subtitles.cues.isEmpty || progress != nil || source == target)
            Text(tr("نزّل اللغة من الإعدادات أولاً، أو وافق على تنزيل نموذج اللغة عند طلب النظام.", "Download the language in Settings first, or approve the system language-model download prompt.")).font(.footnote)
            if let progress { ProgressView(progress) }
            if let error { Text(error).foregroundStyle(.red) }
        }.navigationTitle(tr("ترجمة الترجمة", "Subtitle translation"))
            .translationTask(configuration) { session in
                let original = subtitles.cues
                guard let media = subtitles.mediaURL, !original.isEmpty else { return }
                error = nil; defer { progress = nil }
                do {
                    let availability = await LanguageAvailability().status(from: Locale.Language(identifier: source), to: Locale.Language(identifier: target))
                    guard availability != .unsupported else { error = tr("الترجمة غير متاحة لهذا الزوج من اللغات.", "Translation is unavailable for this language pair."); return }
                    try await session.prepareTranslation()
                    var translated: [SubtitleCue] = []
                    for (index, cue) in original.enumerated() {
                        try Task.checkCancellation()
                        progress = "\(index + 1) / \(original.count)"
                        let value = try await session.translate(cue.text)
                        translated.append(SubtitleCue(start: cue.start, end: cue.end, text: value.targetText))
                    }
                    subtitles.replaceTranslation(translated, for: media, original: original)
                } catch { self.error = tr("تعذّرت الترجمة. تحقق من دعم اللغة وتنزيلها من إعدادات الترجمة.", "Translation failed. Check language support and download it in Translation settings.") }
            }
    }
    @ViewBuilder private var languages: some View {
        ForEach(["ar", "en", "fr", "de", "es", "it", "pt", "tr", "ru", "ja", "ko", "zh", "hi"], id: \.self) { code in
            Text(Locale.current.localizedString(forLanguageCode: code) ?? code).tag(code)
        }
    }
}
