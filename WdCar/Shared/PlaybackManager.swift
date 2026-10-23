import SwiftUI
import AVFoundation
import AVKit
import MediaPlayer
import Combine
import UIKit

/// مشغل الوسائط المركزي (Xtream وغيرها):
/// - AVPlayer يدعم AirPlay (allowsExternalPlayback) فيُبث الفيديو لشاشة السيارة أو التلفزيون.
/// - ينشر معلومات Now Playing وأوامر التحكم، وهي ما يعتمد عليه CarPlay Video لعرض الفيديو أو تحويله لصوت أثناء القيادة.
final class PlaybackManager: ObservableObject {
    static let shared = PlaybackManager()

    struct Item: Equatable {
        let title: String
        let subtitle: String
        let url: URL
        let isLive: Bool
        let artworkURL: URL?
    }

    let player = AVPlayer()

    @Published private(set) var current: Item?
    @Published private(set) var isPlaying = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isExternalDisplayPlayback = false
    @Published var isPlayerPresented = false

    private var artwork: UIImage?
    private var bag = Set<AnyCancellable>()
    private var itemBag = Set<AnyCancellable>()

    private init() {
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        player.automaticallyWaitsToMinimizeStalling = true

        player.publisher(for: \.timeControlStatus)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                WDLog.car("AVPlayer timeControlStatus=\(String(describing: status))")
                self?.isPlaying = (status == .playing)
                self?.updateNowPlaying()
            }
            .store(in: &bag)

        player.publisher(for: \.isExternalPlaybackActive)
            .removeDuplicates()
            .sink { active in
                WDLog.car("AVPlayer isExternalPlaybackActive=\(active)")
                DiagnosticLog.shared.setSummaryValue("AVPlayer external playback", value: "\(active)")
            }
            .store(in: &bag)

        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] note in self?.logAudioRouteChange(note) }
            .store(in: &bag)
        logAudioRouteChange(nil)

        setupRemoteCommands()
    }

    // MARK: التشغيل

    func play(_ item: Item, presentOnPhone: Bool) {
        guard SubscriptionStore.shared.hasAccess else {
            errorMessage = tr("يلزم اشتراك ود كار. فعّله أو استعده من إعدادات الهاتف.", "WudCar Premium is required. Subscribe or restore in iPhone settings.")
            return
        }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo, options: [])
            try session.setActive(true)
            WDLog.car("AVAudioSession category=\(session.category.rawValue) mode=\(session.mode.rawValue) active for playback")
        } catch {
            WDLog.car("AVAudioSession playback setup error=\(error.localizedDescription)")
        }

        errorMessage = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        current = item
        isExternalDisplayPlayback = !presentOnPhone
        artwork = nil

        let playerItem = AVPlayerItem(url: item.url)
        observe(playerItem)
        player.replaceCurrentItem(with: playerItem)
        player.playImmediately(atRate: 1)
        updateNowPlaying()
        loadArtwork(for: item)

        if presentOnPhone { isPlayerPresented = true }
    }

    func togglePlayPause() {
        guard SubscriptionStore.shared.hasAccess else { stop(); return }
        if player.timeControlStatus == .paused { player.play() } else { player.pause() }
    }

    func seek(by seconds: Double) {
        guard current?.isLive == false else { return }
        let target = max(0, player.currentTime().seconds + seconds)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }

    func stop() {
        itemBag.removeAll()
        player.pause()
        player.replaceCurrentItem(with: nil)
        artwork = nil
        isPlaying = false
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            WDLog.car("AVAudioSession deactivation error=\(error.localizedDescription)")
        }
        current = nil
        isExternalDisplayPlayback = false
        errorMessage = nil
        isPlayerPresented = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: داخلي

    private func observe(_ item: AVPlayerItem) {
        itemBag.removeAll()
        item.publisher(for: \.status)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self, self.player.currentItem === item else { return }
                WDLog.car("AVPlayerItem status=\(String(describing: status))")
                if status == .failed {
                    WDLog.car("AVPlayerItem error=\(item.error?.localizedDescription ?? "unknown")")
                    self.errorMessage = item.error?.localizedDescription
                        ?? tr("تعذّر تشغيل هذا المحتوى.", "This content could not be played.")
                }
                self.updateNowPlaying()
            }
            .store(in: &itemBag)
        if let error = item.error { WDLog.car("AVPlayerItem initial error=\(error.localizedDescription)") }
    }

    private func logAudioRouteChange(_ notification: Notification?) {
        let session = AVAudioSession.sharedInstance()
        let reason: String
        if let raw = notification?.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
           let value = AVAudioSession.RouteChangeReason(rawValue: raw) {
            reason = "\(value.rawValue) (\(String(describing: value)))"
        } else { reason = notification == nil ? "initial" : "unknown" }
        let outputs = session.currentRoute.outputs.map { "\($0.portType.rawValue):\($0.portName)" }
        WDLog.car("AVAudioSession routeChange reason=\(reason) category=\(session.category.rawValue) mode=\(session.mode.rawValue) outputs=[\(outputs.joined(separator: ", "))]")
    }

    private func loadArtwork(for item: Item) {
        ImageLoader.shared.load(item.artworkURL) { [weak self] image in
            guard let self, self.current == item else { return }
            self.artwork = image
            self.updateNowPlaying()
        }
    }

    private func updateNowPlaying() {
        guard let current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: current.title,
            MPMediaItemPropertyArtist: current.subtitle,
            MPNowPlayingInfoPropertyIsLiveStream: current.isLive,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: Double(player.rate)
        ]
        let elapsed = player.currentTime().seconds
        if elapsed.isFinite { info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed }
        if let duration = player.currentItem?.duration.seconds, duration.isFinite, !current.isLive {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.player.play(); return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.player.pause(); return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause(); return .success
        }
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] _ in
            self?.seekRemote(by: 15); return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            self?.seekRemote(by: -15); return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.player.seek(to: CMTime(seconds: event.positionTime, preferredTimescale: 600))
            return .success
        }
    }

    private func seekRemote(by seconds: Double) {
        seek(by: seconds)
    }
}

// MARK: - شاشة المشغل على الهاتف (فيها زر AirPlay وصورة داخل صورة)

struct PlayerScreen: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = PlaybackManager.shared.player
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        // نحن ننشر معلومات Now Playing بأنفسنا
        controller.updatesNowPlayingInfoCenter = false
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}
}
