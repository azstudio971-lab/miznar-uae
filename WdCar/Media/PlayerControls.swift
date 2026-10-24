import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct PlayerControls: View {
    @ObservedObject private var playback = PlaybackManager.shared
    @ObservedObject private var captions = ExternalSubtitles.shared
    @AppStorage("wd.media.subtitles") private var subtitles = true
    @AppStorage("wd.media.subtitleSize") private var subtitleSize = 100.0
    @AppStorage("wd.media.yellow") private var yellow = false
    @AppStorage("wd.media.background") private var background = 0.6
    @State private var importing = false
    @State private var error: String?
    var body: some View {
        VStack {
            Spacer()
            if subtitles {
                let text = captions.text(at: playback.elapsed, mediaURL: playback.current?.url)
                if !text.isEmpty {
                    Text(text).font(.system(size: 22 * subtitleSize / 100)).foregroundStyle(yellow ? .yellow : .white)
                        .multilineTextAlignment(.center).padding(8).background(.black.opacity(background)).allowsHitTesting(false)
                }
            }
            HStack(spacing: 24) {
                Button { playback.previous() } label: { Image(systemName: "backward.end.fill") }.disabled(!playback.canPlayPrevious)
                Button { playback.seek(by: -Double(PlayerPreferences.skip)) } label: { Image(systemName: "gobackward.\(PlayerPreferences.skip)") }.disabled(!playback.canSeek)
                Button { playback.seek(by: Double(PlayerPreferences.skip)) } label: { Image(systemName: "goforward.\(PlayerPreferences.skip)") }.disabled(!playback.canSeek)
                Button { playback.next() } label: { Image(systemName: "forward.end.fill") }.disabled(!playback.canPlayNext)
                Menu {
                    if playback.current?.url.isFileURL == true { Button(tr("تحميل SRT / VTT", "Load SRT / VTT")) { importing = true } }
                    if let item = playback.player.currentItem, let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
                        ForEach(Array(group.options.enumerated()), id: \.offset) { _, option in
                            Button(option.displayName) { item.select(option, in: group) }
                        }
                    }
                    ForEach([15,30,60], id: \.self) { minutes in Button(tr("نوم بعد \(minutes) دقيقة", "Sleep in \(minutes) minutes")) { playback.setSleepTimer(minutes: minutes) } }
                    Button(tr("إلغاء مؤقت النوم", "Cancel sleep timer")) { playback.setSleepTimer(minutes: 0) }
                } label: { Image(systemName: "ellipsis.circle") }
            }.font(.title3).foregroundStyle(.white).padding(12).background(.black.opacity(0.65), in: Capsule())
            .padding(.bottom, 70)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "srt") ?? .plainText, UTType(filenameExtension: "vtt") ?? .plainText]) { result in
            do { if let media = playback.current?.url, media.isFileURL { try captions.load(result.get(), for: media) } }
            catch { self.error = error.localizedDescription }
        }
        .alert(tr("تعذّر تحميل الترجمة", "Could not load subtitles"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}
