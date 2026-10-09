import AVKit
import MediaPlayer
import Combine

@MainActor final class PlayerService: ObservableObject {
    static let shared = PlayerService()
    let player = AVPlayer()
    @Published var title = ""
    @Published var error: String?
    private var observation: NSKeyValueObservation?
    init() {
        player.allowsExternalPlayback = true
        MPRemoteCommandCenter.shared().playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.player.play() }; return .success }
        MPRemoteCommandCenter.shared().pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.player.pause() }; return .success }
    }
    func play(url: URL, name: String) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            title = name; error = nil
            let item = AVPlayerItem(url: url)
            observation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                if item.status == .failed { let message = item.error?.localizedDescription ?? "Playback failed"; Task { @MainActor in self?.error = message } }
            }
            player.replaceCurrentItem(with: item); player.play()
            MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: name]
        } catch { self.error = error.localizedDescription }
    }
    func stop() { player.pause(); player.replaceCurrentItem(with: nil); title = ""; MPNowPlayingInfoCenter.default().nowPlayingInfo = nil; try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
}
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView { let view = AVRoutePickerView(); view.prioritizesVideoDevices = true; return view }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
