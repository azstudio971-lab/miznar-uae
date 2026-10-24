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
        var sourceKey: String? = nil
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
    private var connectionTimeout: DispatchWorkItem?
    private var sleepTimer: Timer?
    private var appliedPreferences: NSDictionary = [:]
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
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.savePosition() }.store(in: &bag)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in
                guard let self else { return }
                let values = UserDefaults.standard.dictionaryRepresentation().filter { $0.key.hasPrefix(PlayerPreferences.prefix) } as NSDictionary
                if !values.isEqual(self.appliedPreferences) { self.applyPreferences() }
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
        if !queue.contains(item) { queue = [] }
        if item.url.scheme == "https" || item.url.scheme == "http" {
            try? MediaLibrary.shared.addRemote(title: item.title, url: item.url, isLive: item.isLive, sourceKey: item.sourceKey, artworkURL: item.artworkURL)
        }
        let savedPosition = MediaLibrary.shared.items.first(where: { $0.url == item.url })?.position ?? 0
        MediaLibrary.shared.record(url: item.url, position: savedPosition)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo, options: [])
        try? session.setActive(true)

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
        player.defaultRate = presentOnPhone ? PlayerPreferences.rate : 1
        applyPreferences()
        connectionTimeout?.cancel()
        let timeout = DispatchWorkItem { [weak self, weak playerItem] in
            guard let self, let playerItem, self.player.currentItem === playerItem, playerItem.status != .readyToPlay else { return }
            self.player.pause(); self.isLoading = false
            self.errorMessage = tr("انتهت مهلة الاتصال. أعد المحاولة.", "Connection timed out. Please retry.")
        }
        connectionTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + PlayerPreferences.timeout, execute: timeout)
        player.play()
        updateNowPlaying()
        loadArtwork(for: item)

        isPlayerPresented = presentOnPhone
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

    var canSeek: Bool {
        guard let item = player.currentItem, item.status == .readyToPlay else { return false }
        return item.seekableTimeRanges.contains { value in
            let range = value.timeRangeValue
            return range.duration.seconds.isFinite && range.duration.seconds > 0
        }
    }
    var canPlayNext: Bool {
        guard let current, let index = queue.firstIndex(of: current) else { return false }
        return queue.indices.contains(index + 1)
    }
    var canPlayPrevious: Bool {
        guard let current, let index = queue.firstIndex(of: current) else { return false }
        return index > 0
    }

    var supportedRates: [Float] {
        guard current?.isLive == false, let item = player.currentItem, item.status == .readyToPlay else { return [1] }
        var rates: [Float] = [1]
        if item.canPlaySlowForward { rates.insert(0.5, at: 0) }
        if item.canPlayFastForward { rates += [1.5, 2] }
        return rates
    }

    func setRate(_ rate: Float) {
        guard !isExternalDisplayPlayback, (0.5...2).contains(rate) else { return }
        player.defaultRate = rate
        if isPlaying { player.rate = rate }
    }

    func next() { moveQueue(by: 1) }
    func previous() { moveQueue(by: -1) }
    private func moveQueue(by offset: Int) {
        guard let current, let index = queue.firstIndex(of: current), queue.indices.contains(index + offset) else { return }
        play(queue[index + offset], presentOnPhone: !isExternalDisplayPlayback)
    }

    func savePosition(completed: Bool = false) {
        guard let current, !current.isLive else { return }
        let total = player.currentItem?.duration.seconds ?? 0
        let atEnd = total.isFinite && total > 0 && player.currentTime().seconds >= total - 1
        let position = (completed || atEnd) ? 0 : player.currentTime().seconds
        guard position.isFinite else { return }
        MediaLibrary.shared.record(url: current.url, position: position, duration: total)
        lastSaved = position
    }

    func stop() {
        savePosition()
        connectionTimeout?.cancel()
        itemBag.removeAll()
        player.pause()
        player.replaceCurrentItem(with: nil)
        artwork = nil
        isPlaying = false
        isLoading = false
        elapsed = 0
        duration = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        current = nil
        isExternalDisplayPlayback = false
        errorMessage = nil
        isPlayerPresented = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func setSleepTimer(minutes: Int) {
        sleepTimer?.invalidate()
        guard minutes > 0 else { return }
        sleepTimer = Timer.scheduledTimer(withTimeInterval: Double(minutes * 60), repeats: false) { [weak self] _ in self?.player.pause(); self?.savePosition() }
    }
    func applyPreferences() {
        appliedPreferences = UserDefaults.standard.dictionaryRepresentation().filter { $0.key.hasPrefix(PlayerPreferences.prefix) } as NSDictionary
        guard let item = player.currentItem else { return }
        item.preferredForwardBufferDuration = PlayerPreferences.buffer
        if !isExternalDisplayPlayback { player.defaultRate = PlayerPreferences.rate; if isPlaying { player.rate = PlayerPreferences.rate } }
        guard item.status == .readyToPlay else { return }
        for (characteristic, language, enabled) in [(AVMediaCharacteristic.legible, PlayerPreferences.subtitleLanguage, PlayerPreferences.subtitles), (.audible, PlayerPreferences.audioLanguage, true)] {
            if let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) {
                let preferred = group.options.first { $0.extendedLanguageTag?.hasPrefix(language) == true }
                item.select(enabled ? (preferred ?? group.defaultOption) : nil, in: group)
            }
        }
        let color: [CGFloat] = PlayerPreferences.yellow ? [1,1,1,0] : [1,1,1,1]
        let attributes: [String: Any] = [
            kCMTextMarkupAttribute_RelativeFontSize as String: PlayerPreferences.subtitleSize,
            kCMTextMarkupAttribute_ForegroundColorARGB as String: color,
            kCMTextMarkupAttribute_BackgroundColorARGB as String: [PlayerPreferences.background,0,0,0]
        ]
        item.textStyleRules = AVTextStyleRule(textMarkupAttributes: attributes).map { [$0] } ?? []
    }

    // MARK: داخلي

    private func observe(_ item: AVPlayerItem) {
        itemBag.removeAll()
        item.publisher(for: \.status)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self, self.player.currentItem === item else { return }
                if status == .readyToPlay {
                    self.connectionTimeout?.cancel()
                    self.applyPreferences()
                    self.isLoading = false
                    if PlayerPreferences.resume, self.current?.isLive == false,
                       let url = self.current?.url,
                       let saved = MediaLibrary.shared.items.first(where: { $0.url == url }), saved.position > 0,
                       item.duration.seconds.isFinite, saved.position < item.duration.seconds - 3 {
                        self.player.seek(to: CMTime(seconds: saved.position, preferredTimescale: 600))
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
        if let url = item.artworkURL, url.isFileURL {
            artwork = UIImage(contentsOfFile: url.path); updateNowPlaying(); return
        }
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
        let center = MPRemoteCommandCenter.shared()
        let canSeek = player.currentItem?.seekableTimeRanges.isEmpty == false
        center.skipForwardCommand.isEnabled = canSeek
        center.skipBackwardCommand.isEnabled = canSeek
        center.changePlaybackPositionCommand.isEnabled = canSeek && !current.isLive
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: PlayerPreferences.skip)]
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: PlayerPreferences.skip)]
        if let index = queue.firstIndex(of: current) {
            center.nextTrackCommand.isEnabled = index + 1 < queue.count
            center.previousTrackCommand.isEnabled = index > 0
        } else {
            center.nextTrackCommand.isEnabled = false
            center.previousTrackCommand.isEnabled = false
        }
        if let index = queue.firstIndex(of: current) {
            info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = index
            info[MPNowPlayingInfoPropertyPlaybackQueueCount] = queue.count
        }
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
            guard SubscriptionStore.shared.hasAccess else { return .commandFailed }
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
        configure(controller)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) { configure(controller) }
    private func configure(_ controller: AVPlayerViewController) {
        controller.videoGravity = PlayerPreferences.gravity
        controller.allowsPictureInPicturePlayback = PlayerPreferences.pip
        controller.canStartPictureInPictureAutomaticallyFromInline = PlayerPreferences.pip
    }
}
