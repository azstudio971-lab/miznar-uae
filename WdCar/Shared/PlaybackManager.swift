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

    @Published private(set) var queue: [Item] = []
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var isLoading = false
    private var periodicObserver: Any?
    private var lastSaved: Double = 0
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
                self?.isPlaying = (status == .playing)
                self?.updateNowPlaying()
            }
            .store(in: &bag)

        player.publisher(for: \.isExternalPlaybackActive)
            .removeDuplicates()
            .sink { active in WDLog.car("player externalPlaybackActive=\(active)") }
            .store(in: &bag)

        periodicObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self else { return }
            self.elapsed = time.seconds.isFinite ? time.seconds : 0
            let total = self.player.currentItem?.duration.seconds ?? 0
            self.duration = total.isFinite ? total : 0
            self.isLoading = self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            if abs(self.elapsed - self.lastSaved) >= 5 { self.savePosition() }
            self.updateNowPlaying()
        }
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self, let item = note.object as? AVPlayerItem, item === self.player.currentItem else { return }
                self.savePosition(completed: true)
                if PlayerPreferences.autoNext { self.next() }
            }.store(in: &bag)
        setupRemoteCommands()
    }

    // MARK: التشغيل

    func play(_ item: Item, presentOnPhone: Bool) {
        guard SubscriptionStore.shared.hasAccess else {
            errorMessage = tr("يلزم اشتراك ود كار. فعّله أو استعده من إعدادات الهاتف.", "WudCar Premium is required. Subscribe or restore in iPhone settings.")
            return
        }
        savePosition()
        if item.url.scheme == "https" || item.url.scheme == "http" {
            try? MediaLibrary.shared.addRemote(title: item.title, url: item.url, isLive: item.isLive)
        }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo, options: [])
            try session.setActive(true)
        } catch { errorMessage = error.localizedDescription; return }

        errorMessage = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        current = item
        lastSaved = 0
        elapsed = 0
        duration = 0
        isLoading = true
        isExternalDisplayPlayback = !presentOnPhone
        artwork = nil

        let playerItem = AVPlayerItem(url: item.url)
        observe(playerItem)
        player.replaceCurrentItem(with: playerItem)
        player.play()
        updateNowPlaying()
        loadArtwork(for: item)

        if presentOnPhone { isPlayerPresented = true }
    }

    func togglePlayPause() {
        guard SubscriptionStore.shared.hasAccess else { stop(); return }
        if player.timeControlStatus == .paused { player.play() } else { player.pause() }
    }

    func seek(by seconds: Double) {
        guard let item = player.currentItem, item.status == .readyToPlay else { return }
        let ranges = item.seekableTimeRanges.map { $0.timeRangeValue }
        guard let range = ranges.last else { return }
        let lower = range.start.seconds
        let upper = CMTimeRangeGetEnd(range).seconds
        guard lower.isFinite, upper.isFinite, upper > lower else { return }
        // Live streams are seekable only when the source exposes a time-shift window.
        let target = min(upper, max(lower, player.currentTime().seconds + seconds))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }

    func playQueue(_ items: [Item], startingAt url: URL?, presentOnPhone: Bool) {
        queue = items
        guard let first = items.first(where: { $0.url == url }) ?? items.first else { return }
        play(first, presentOnPhone: presentOnPhone)
    }

    func next() { moveQueue(by: 1) }
    func previous() { moveQueue(by: -1) }
    private func moveQueue(by offset: Int) {
        guard let current, let index = queue.firstIndex(of: current), queue.indices.contains(index + offset) else { return }
        play(queue[index + offset], presentOnPhone: isPlayerPresented)
    }

    func savePosition(completed: Bool = false) {
        guard let current, !current.isLive else { return }
        let position = completed ? 0 : player.currentTime().seconds
        guard position.isFinite else { return }
        MediaLibrary.shared.record(url: current.url, position: position)
        lastSaved = position
    }

    func stop() {
        savePosition()
        itemBag.removeAll()
        player.pause()
        player.replaceCurrentItem(with: nil)
        artwork = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
                if status == .readyToPlay {
                    self.isLoading = false
                    if PlayerPreferences.resume, self.current?.isLive == false,
                       let url = self.current?.url,
                       let saved = MediaLibrary.shared.items.first(where: { $0.url == url }), saved.position > 0,
                       item.duration.seconds.isFinite, saved.position < item.duration.seconds - 3 {
                        self.player.seek(to: CMTime(seconds: saved.position, preferredTimescale: 600))
                    }
                    if let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
                        let language = PlayerPreferences.subtitleLanguage
                        let preferred = group.options.first { $0.extendedLanguageTag?.hasPrefix(language) == true }
                        item.select(PlayerPreferences.subtitles ? (preferred ?? group.defaultOption) : nil, in: group)
                    }
                }
                if status == .failed {
                    self.isLoading = false
                    self.errorMessage = item.error?.localizedDescription
                        ?? tr("تعذّر تشغيل هذا المحتوى.", "This content could not be played.")
                }
                self.updateNowPlaying()
            }
            .store(in: &itemBag)
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
        center.nextTrackCommand.addTarget { [weak self] _ in self?.next(); return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in self?.previous(); return .success }
        center.playCommand.addTarget { [weak self] _ in
            self?.player.play(); return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.player.pause(); return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause(); return .success
        }
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: PlayerPreferences.skip)]
        center.skipForwardCommand.addTarget { [weak self] _ in
            self?.seekRemote(by: Double(PlayerPreferences.skip)); return .success
        }
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: PlayerPreferences.skip)]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            self?.seekRemote(by: -Double(PlayerPreferences.skip)); return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            guard let self, self.current?.isLive == false else { return .commandFailed }
            self.seek(by: event.positionTime - self.player.currentTime().seconds)
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
        controller.videoGravity = PlayerPreferences.fill ? .resizeAspectFill : .resizeAspect
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}
}

