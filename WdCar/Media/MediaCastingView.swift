import SwiftUI

/// Real AVPlayer/AirPlay sending, not an AirPlay receiver or screen recorder.
struct MediaCastingView: View {
    @ObservedObject private var library = MediaLibrary.shared
    @ObservedObject private var playback = PlaybackManager.shared

    var body: some View {
        List {
            Section {
                Label(tr("بث الوسائط من مشغّل WudCar", "Send media from the WudCar player"), systemImage: "airplay.video")
                    .font(.headline)
                Text(tr("١. شغّل فيديو من القائمة أدناه.\n٢. اختر شاشة متوافقة من زر AirPlay داخل المشغّل.\n٣. للتحكم والعودة، استخدم أدوات المشغّل.", "1. Play a video from the list below.\n2. Choose a compatible display with AirPlay in the player.\n3. Use player controls to manage playback."))
                HStack {
                    Text(tr("اختيار شاشة AirPlay", "Choose an AirPlay display"))
                    Spacer()
                    AirPlayButton().frame(width: 60, height: 48)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.wdNavy))
                        .accessibilityLabel(tr("اختيار شاشة AirPlay", "Choose an AirPlay display"))
                }
                if let current = playback.current {
                    Button {
                        playback.isPlayerPresented = true
                    } label: { Label(tr("فتح المشغّل: ", "Open player: ") + current.title, systemImage: "play.rectangle") }
                }
            } footer: {
                Text(tr("في CarPlay، يتطلب الفيديو سيارة متوافقة وسماحًا من النظام أثناء الوقوف. عند حجب الصورة يتحكم النظام بإخراج الصوت. لا تتجاوز قيود السيارة.", "CarPlay video requires a compatible vehicle and system permission while parked. When video is blocked, the system controls audio output. Vehicle restrictions cannot be bypassed."))
            }
            Section(tr("اختر من مكتبة المشغّل", "Choose from your player library")) {
                ForEach(library.items) { media in
                    Button {
                        CarScreenLauncher.shared.closeBrowser()
                        PlaybackManager.shared.playQueue(library.items.compactMap(\.playbackItem), startingAt: media.url, presentOnPhone: true)
                    } label: {
                        Label(media.title, systemImage: media.localFilename == nil ? "network" : "film")
                    }
                }
                if library.items.isEmpty {
                    Text(tr("أضف ملفات أو روابط من مكتبة الوسائط أولًا.", "Add files or URLs in Media library first."))
                        .foregroundStyle(.secondary)
                }
            }
            Section(tr("حدود الوظيفة", "What this supports")) {
                Text(tr("يرسل AirPlay الفيديو أو الصوت من مشغّل التطبيق إلى أجهزة متوافقة. هذه الصفحة لا تعكس شاشة iPhone بالكامل، ولا تجعل WudCar مستقبل AirPlay أو DLNA.", "AirPlay sends video or audio from the app player to compatible devices. This page does not mirror the full iPhone screen or make WudCar an AirPlay or DLNA receiver."))
                Text(tr("تختلف الأجهزة والصيغ المحمية بدعم المصدر. الترجمة الخارجية الخاصة بالهاتف لا تنتقل عبر AirPlay.", "Device and protected-format support depend on the source. Phone-only external captions are not sent through AirPlay."))
            }
        }
        .navigationTitle(tr("البث إلى الشاشة", "Send to display"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
