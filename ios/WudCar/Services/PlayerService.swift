import SwiftUI
import AVKit
import MediaPlayer
import Combine

@MainActor final class PlayerService: ObservableObject {
    static let shared = PlayerService()
    let player = AVPlayer()
    @Published var title = ""
    @Published var error: String?
    private var queue: [Track] = []
    private var queueIndex = 0
    private var endObserver: NSObjectProtocol?
    private var observation: NSKeyValueObservation?
    init() {
        player.allowsExternalPlayback = true
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] notification in
            Task { @MainActor in guard let self, let item = notification.object as? AVPlayerItem, item === self.player.currentItem else { return }; self.next() }
        }
        MPRemoteCommandCenter.shared().nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.next() }; return .success }
        MPRemoteCommandCenter.shared().previousTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.previous() }; return .success }
        MPRemoteCommandCenter.shared().playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.player.play() }; return .success }
        MPRemoteCommandCenter.shared().pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.player.pause() }; return .success }
    }
    func playPlaylist(_ tracks: [Track], startingAt id: String? = nil) {
        queue = tracks; queueIndex = id.flatMap { selected in tracks.firstIndex { $0.id == selected } } ?? 0
        playQueued()
    }
    private func playQueued() { guard queue.indices.contains(queueIndex), let url = WudDomain.validURL(queue[queueIndex].url) else { return }; let track = queue[queueIndex]; authorize(url: url, name: AppState.shared.text(track.name_ar, track.name_en)) }
    func next() { guard queueIndex + 1 < queue.count else { player.pause(); return }; queueIndex += 1; playQueued() }
    func previous() { guard !queue.isEmpty else { return }; queueIndex = max(0, queueIndex - 1); playQueued() }
    func play(url: URL, name: String) { queue = []; authorize(url: url, name: name) }
    private func authorize(url: URL, name: String) {
        if UsageMeter.shared.enabled && !UsageMeter.shared.allowed {
            Task {
                guard await UsageMeter.shared.authorizePlayback() else {
                    error = UsageMeter.shared.message ?? AppState.shared.text("تحقق من حسابك والدقائق المتبقية أو الاشتراك.", "Check your account, remaining minutes or subscription."); return
                }
                start(url: url, name: name)
            }
        } else { start(url: url, name: name) }
    }
    private func start(url: URL, name: String) {
        guard !UsageMeter.shared.enabled || UsageMeter.shared.allowed else {
            error = AppState.shared.text("تحقق من حسابك والدقائق المتبقية أو الاشتراك.", "Check your account, remaining minutes or subscription."); return
        }
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
    func stop() { queue = []; player.pause(); player.replaceCurrentItem(with: nil); title = ""; MPNowPlayingInfoCenter.default().nowPlayingInfo = nil; try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
}
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView { let view = AVRoutePickerView(); view.prioritizesVideoDevices = true; return view }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
