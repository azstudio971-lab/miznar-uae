import SwiftUI
import VLCKit

/// Phone-only software decoder. Vehicle output remains AVPlayer/AirPlay.
final class SoftwareDecoder: NSObject, VLCMediaPlayerDelegate {
    let player = VLCMediaPlayer(options: ["--avcodec-hw=none", "--no-video-title-show", "--no-osd"])
    var progress: ((Double, Double, Bool) -> Void)?
    var failure: (() -> Void)?
    private var timer: Timer?
    private var initialPosition: Double = 0
    private var resumed = false
    private var blockedVideo = false
    override init() { super.init(); player.delegate = self }
    func play(_ url: URL, position: Double) {
        initialPosition = position; resumed = false; player.delegate = self
        player.media = VLCMedia(url: url)
        player.media?.addOption(":network-caching=\(Int(PlayerPreferences.number("buffer", 5) * 1000))")
        player.media?.addOption(":http-user-agent=\(PlayerPreferences.text("userAgent", "WudCar/3.0.1"))")
        player.play()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let elapsed = Double(self.player.time.intValue) / 1000
            let duration = Double(self.player.media?.length.intValue ?? 0) / 1000
            if !self.resumed, self.player.isSeekable, duration > 0 {
                self.resumed = true
                if self.initialPosition > 0, self.initialPosition < duration - 3 { self.player.time = VLCTime(int: Int32(self.initialPosition * 1000)) }
            }
            self.progress?(max(0, elapsed), max(0, duration), self.player.isPlaying)
        }
    }
    func setVideoBlocked(_ blocked: Bool) {
        if blocked { blockedVideo = true; player.deselectAllVideoTracks() }
        else if blockedVideo { blockedVideo = false; player.videoTracks.first?.isSelectedExclusively = true }
    }
    func seek(by seconds: Double) {
        guard player.isSeekable else { return }
        if seconds >= 0 { player.jumpForward(seconds) } else { player.jumpBackward(-seconds) }
    }
    func toggle() { if player.isPlaying { player.pause() } else { player.play() } }
    func stop() { timer?.invalidate(); timer = nil; player.delegate = nil; player.stop(); player.drawable = nil }
    func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
        if newState == .error { DispatchQueue.main.async { [weak self] in self?.failure?() } }
    }
    deinit { timer?.invalidate(); player.delegate = nil; player.stop() }
}
struct SoftwarePlaybackSurface: UIViewRepresentable {
    let decoder: SoftwareDecoder
    func makeUIView(context: Context) -> UIView { let view = UIView(); view.backgroundColor = .black; decoder.player.drawable = view; return view }
    func updateUIView(_ view: UIView, context: Context) { if decoder.player.drawable as? UIView !== view { decoder.player.drawable = view } }
}
struct SoftwarePlayerView: View {
    let decoder: SoftwareDecoder
    @ObservedObject private var manager = PlaybackManager.shared
    var body: some View {
        ZStack(alignment: .bottom) {
            SoftwarePlaybackSurface(decoder: decoder)
            VStack {
                Text(tr("فك ترميز برمجي — الهاتف فقط", "Software decoding — iPhone only")).font(.caption)
                HStack(spacing: 24) {
                    Button { manager.previous() } label: { Image(systemName: "backward.end.fill") }.disabled(!manager.canPlayPrevious)
                    Button { manager.seek(by: -15) } label: { Image(systemName: "gobackward.15") }
                    Button { manager.togglePlayPause() } label: { Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill") }
                    Button { manager.seek(by: 15) } label: { Image(systemName: "goforward.15") }
                    Button { manager.next() } label: { Image(systemName: "forward.end.fill") }.disabled(!manager.canPlayNext)
                }.font(.title2).padding()
                HStack {
                    Menu(tr("الصوت", "Audio")) {
                        ForEach(Array(decoder.player.audioTracks.enumerated()), id: \.offset) { index, track in
                            Button(track.trackName) { decoder.player.selectTrack(at: index, type: .audio) }
                        }
                    }
                    Menu("CC") {
                        Button(tr("إيقاف", "Off")) { decoder.player.selectTextTracks([]) }
                        ForEach(Array(decoder.player.textTracks.enumerated()), id: \.offset) { _, track in
                            Button(track.trackName) { track.isSelectedExclusively = true }
                        }
                    }
                }
            }.foregroundStyle(.white).padding(.bottom, 30).frame(maxWidth: .infinity).background(.black.opacity(0.5))
        }
    }
}

struct OpenSourceLicensesView: View {
    private var text: String {
        guard let url = Bundle.main.url(forResource: "VLCKit-LICENSE", withExtension: "txt") else { return "" }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("VLCKit — VideoLAN — LGPL 2.1 or later").font(.headline)
                Link("VLCKit source and build instructions", destination: URL(string: "https://github.com/videolan/vlckit/tree/2e0868f5ed40fe59cd92f377645fdcc260c6e759")!)
                Link("WudCar source and XcodeGen project for rebuilding", destination: URL(string: "https://github.com/azstudio971-lab/miznar-uae/tree/release/wudcar-3.0.1")!)
                Text("VLCKit is unmodified. You may modify the library and reverse engineer this application to debug those modifications under the LGPL terms. The library is provided without warranty.").font(.footnote)
                Text(text).font(.footnote)
            }.padding()
        }.navigationTitle("Open source")
    }
}
