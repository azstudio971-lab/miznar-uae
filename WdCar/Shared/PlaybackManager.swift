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
    static let carPlaybackRequested = Notification.Name("WudCar.carPlaybackRequested")

    struct Item: Equatable {
        let title: String
        let subtitle: String
        let url: URL
        let isLive: Bool
        let artworkURL: URL?
        var sourceKey: String? = nil
    }

    let player = AVPlayer()
    @Published private(set) var isSoftwareDecoding = false
    private(set) var software: SoftwareDecoder?
    @Published private(set) var availableQualities: [HLSQuality] = []

    @Published private(set) var current: Item?
    @Published private(set) var isPlaying = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isExternalDisplayPlayback = false
    @Published private(set) var isAirPlayActive = false
    @Published var isPlayerPresented = false
    @Published var isPictureInPictureActive = false
    @Published private(set) var isMinimized = false

    @Published private(set) var queue: [Item] = []
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var isLoading = false
    private var periodicObserver: Any?
    private var lastSaved: Double = 0
    private var sleepTimer: Timer?
    private var startupTimeout: DispatchWorkItem?
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
                guard self?.isSoftwareDecoding != true else { return }
                self?.isPlaying = (status == .playing)
                self?.updateNowPlaying()
            }
            .store(in: &bag)

        player.publisher(for: \.isExternalPlaybackActive)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] active in
                self?.isAirPlayActive = active
                self?.enforceSafety()
                WDLog.car("player externalPlaybackActive=\(active)")
            }
            .store(in: &bag)

        periodicObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self, !self.isSoftwareDecoding else { return }
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
        DrivingMonitor.shared.$isMoving.receive(on: RunLoop.main).sink { [weak self] _ in self?.enforceSafety() }.store(in: &bag)
        setupRemoteCommands()
    }

    // MARK: التشغيل

    func play(_ item: Item, presentOnPhone: Bool) {
        guard SubscriptionStore.shared.hasAccess else {
            errorMessage = tr("يلزم اشتراك ود كار. فعّله أو استعده من إعدادات الهاتف.", "WudCar Premium is required. Subscribe or restore in iPhone settings.")
            return
        }
        savePosition()
        software?.stop(); software = nil; isSoftwareDecoding = false
        if item.url.scheme == "https" || item.url.scheme == "http" {
            try? MediaLibrary.shared.addRemote(title: item.title, url: item.url, isLive: item.isLive, sourceKey: item.sourceKey)
        }
        let savedPosition = MediaLibrary.shared.items.first(where: { $0.url == item.url })?.position ?? 0
        MediaLibrary.shared.record(url: item.url, position: savedPosition)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo, options: [])
            try session.setActive(true)
        } catch { errorMessage = error.localizedDescription; return }

        errorMessage = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        current = item
        ExternalSubtitles.shared.restore(for: item.url)
        lastSaved = 0
        elapsed = 0
        duration = 0
        isLoading = true
        isExternalDisplayPlayback = !presentOnPhone
        artwork = UIImage(named: "LogoMark")

        if presentOnPhone, !isAirPlayActive, PlayerPreferences.text("softwareDecoding", "auto") == "always" {
            activateSoftware(for: item, position: savedPosition)
            isMinimized = false; isPlayerPresented = true
            return
        }
        availableQualities = []
        if item.url.pathExtension.lowercased() == "m3u8" {
            Task { @MainActor [weak self] in
                let values = (try? await HLSQuality.load(item.url)) ?? []
                if self?.current?.url == item.url { self?.availableQualities = values }
            }
        }
        let asset = AVURLAsset(url: item.url, options: [AVURLAssetHTTPUserAgentKey: PlayerPreferences.text("userAgent", "WudCar/3.0.1")])
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = PlayerPreferences.number("buffer", 0)
        playerItem.preferredPeakBitRate = PlayerPreferences.number("qualityBandwidth", 0)
        startupTimeout?.cancel()
        let timeout = DispatchWorkItem { [weak self, weak playerItem] in
            guard let self, self.player.currentItem === playerItem, playerItem?.status != .readyToPlay else { return }
            self.player.pause()
            self.isLoading = false
            self.errorMessage = tr("انتهت مهلة الاتصال بالمصدر. تحقق من الرابط والشبكة ثم أعد المحاولة.", "Source connection timed out. Check the URL and network, then retry.")
        }
        startupTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + PlayerPreferences.number("timeout", 30), execute: timeout)
        observe(playerItem)
        player.replaceCurrentItem(with: playerItem)
        player.defaultRate = presentOnPhone && !AppState.shared.isCarConnected ? Float(PlayerPreferences.number("rate", 1)) : 1
        player.play()
        updateNowPlaying()
        loadArtwork(for: item)

        if presentOnPhone { isMinimized = false; isPlayerPresented = true }
    }

    func minimize() { isMinimized = true; isPlayerPresented = false }
    func presentPlayer() { isMinimized = false; isPlayerPresented = true }

    /// Prepare the current, real AVPlayer item for the user's selected route.
    /// AVRoutePickerView remains responsible for receiver selection.
    @discardableResult
    func castCurrentMedia() -> Bool {
        guard SubscriptionStore.shared.hasAccess else {
            errorMessage = tr("يلزم تفعيل الاشتراك أو استعادته من الإعدادات.", "Activate or restore your subscription in Settings.")
            return false
        }
        if isSoftwareDecoding {
            errorMessage = tr("البث للسيارة يحتاج صيغة يدعمها AVPlayer. اختر ملف MP4 أو HLS متوافقاً.", "Car playback requires an AVPlayer-compatible format. Choose compatible MP4 or HLS media.")
            return false
        }
        guard current != nil, let item = player.currentItem else {
            errorMessage = tr("اختر فيديو أو ملف صوت من المكتبة أو البث أولاً.", "Choose a video or audio item from Library or TV first.")
            return false
        }
        guard item.status != .failed else { return false }
        CarExternalDisplaySceneDelegate.returnToTemplates()
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        isExternalDisplayPlayback = AppState.shared.isCarConnected || isAirPlayActive
        isPlayerPresented = false
        isMinimized = true
        DrivingMonitor.shared.requestMonitoringPermission()
        enforceSafety()
        player.play()
        updateNowPlaying()
        if AppState.shared.isCarConnected {
            NotificationCenter.default.post(name: Self.carPlaybackRequested, object: nil)
        }
        return true
    }

    func togglePlayPause() {
        guard SubscriptionStore.shared.hasAccess else { stop(); return }
        if isSoftwareDecoding { software?.toggle(); return }
        if player.timeControlStatus == .paused { player.play() } else { player.pause() }
    }

    func seek(by seconds: Double) {
        if isSoftwareDecoding { software?.seek(by: seconds); return }
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

    func playQueue(_ items: [Item], startingAt url: URL?, presentOnPhone: Bool, playlistName: String? = nil) {
        queue = items.map { item in
            Item(title: item.title, subtitle: playlistName ?? item.subtitle, url: item.url, isLive: item.isLive, artworkURL: item.artworkURL, sourceKey: item.sourceKey)
        }
        guard let first = queue.first(where: { $0.url == url }) ?? queue.first else { return }
        play(first, presentOnPhone: presentOnPhone)
    }

    var canSeek: Bool {
        if let software, isSoftwareDecoding { return software.player.isSeekable }
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
        if isSoftwareDecoding { return current?.isLive == false ? [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2] : [1] }
        guard current?.isLive == false, let item = player.currentItem, item.status == .readyToPlay else { return [1] }
        var rates: [Float] = [1]
        if item.canPlaySlowForward { rates.insert(0.5, at: 0) }
        if item.canPlayFastForward { rates += [1.5, 2] }
        return rates
    }

    func setRate(_ rate: Float) {
        if isSoftwareDecoding, !isExternalDisplayPlayback, !AppState.shared.isCarConnected, supportedRates.contains(rate) { software?.player.rate = rate; return }
        guard supportedRates.contains(rate), !AppState.shared.isCarConnected, !isExternalDisplayPlayback else { return }
        player.defaultRate = rate
        if isPlaying { player.rate = rate }
    }

    func next() { moveQueue(by: 1) }
    func previous() { moveQueue(by: -1) }
    private func moveQueue(by offset: Int) {
        guard let current, let index = queue.firstIndex(of: current), queue.indices.contains(index + offset) else { return }
        let onPhone = !isExternalDisplayPlayback
        let wasPresented = isPlayerPresented
        play(queue[index + offset], presentOnPhone: onPhone)
        if onPhone && !wasPresented { isPlayerPresented = false; isMinimized = true }
    }

    func savePosition(completed: Bool = false) {
        guard let current else { return }
        if current.isLive { MediaLibrary.shared.record(url: current.url, position: 0); return }
        if isSoftwareDecoding {
            MediaLibrary.shared.record(url: current.url, position: completed ? 0 : elapsed, duration: duration)
            lastSaved = elapsed; return
        }
        let total = player.currentItem?.duration.seconds ?? 0
        let atEnd = total.isFinite && total > 0 && player.currentTime().seconds >= total - 1
        let position = (completed || atEnd) ? 0 : player.currentTime().seconds
        guard position.isFinite else { return }
        MediaLibrary.shared.record(url: current.url, position: position, duration: total)
        lastSaved = position
    }

    func carDisconnected() {
        guard isExternalDisplayPlayback else { return }
        savePosition()
        player.pause()
        isExternalDisplayPlayback = false
        // Reconnection never resumes media without a new user action.
    }

    func stop() {
        PlaybackActivity.shared.end()
        savePosition()
        software?.stop(); software = nil; isSoftwareDecoding = false
        startupTimeout?.cancel()
        sleepTimer?.invalidate()
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
        isMinimized = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func enforceSafety() {
        if isSoftwareDecoding {
            software?.setVideoBlocked(DrivingMonitor.shared.shouldBlockVideo && WDSettings.lockVideoWhileDriving)
            return
        }
        guard let item = player.currentItem else { return }
        let continueAudio = isPlaying
        let block = Self.blocksVideo(isMoving: DrivingMonitor.shared.shouldBlockVideo,
                                    carConnected: isAirPlayActive || (isExternalDisplayPlayback && AppState.shared.isCarConnected),
                                    phonePreference: WDSettings.lockVideoWhileDriving)
        for track in item.tracks where track.assetTrack?.mediaType == .video { track.isEnabled = !block }
        // The legacy external dashboard pauses when notified; retain audio by applying its safety state first.
        if block, continueAudio, isExternalDisplayPlayback, current != nil {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.player.currentItem === item else { return }
                self.player.play()
            }
        }
    }

    static func blocksVideo(isMoving: Bool, carConnected: Bool, phonePreference: Bool) -> Bool {
        isMoving && (carConnected || phonePreference)
    }

    func setSleepTimer(minutes: Int) {
        sleepTimer?.invalidate()
        guard minutes > 0 else { return }
        sleepTimer = Timer.scheduledTimer(withTimeInterval: Double(minutes * 60), repeats: false) { [weak self] _ in
            guard let self else { return }
            if self.isSoftwareDecoding { self.software?.player.pause() } else { self.player.pause() }
        }
    }
    func applyPreferences() {
        guard let item = player.currentItem else { return }
        item.textStyleRules = PlayerPreferences.styleRules
        item.preferredForwardBufferDuration = PlayerPreferences.number("buffer", 0)
        if let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
            let preferred = group.options.first { $0.extendedLanguageTag?.hasPrefix(PlayerPreferences.text("audioLanguage", "ar")) == true }
            if let preferred { item.select(preferred, in: group) }
        }
        if let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            let preferred = group.options.first { $0.extendedLanguageTag?.hasPrefix(PlayerPreferences.subtitleLanguage) == true }
            item.select(PlayerPreferences.subtitles ? (preferred ?? group.defaultOption) : nil, in: group)
        }
    }
    var hasEnhancedDialogue: Bool {
        player.currentItem?.asset.mediaSelectionGroup(forMediaCharacteristic: .audible)?.options.contains { $0.hasMediaCharacteristic(.enhancesSpeechIntelligibility) } ?? false
    }
    func selectEnhancedDialogue() {
        guard let item = player.currentItem, let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible),
              let option = group.options.first(where: { $0.hasMediaCharacteristic(.enhancesSpeechIntelligibility) }) else { return }
        item.select(option, in: group)
    }

    // MARK: داخلي

    private func observe(_ item: AVPlayerItem) {
        itemBag.removeAll()
        item.publisher(for: \.status)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self, self.player.currentItem === item else { return }
                if status == .readyToPlay {
                    self.startupTimeout?.cancel()
                    self.isLoading = false
                    self.applyPreferences()
                    self.enforceSafety()
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
                    if Self.permitsSoftwareDecoding(preference: PlayerPreferences.text("softwareDecoding", "auto"), external: self.isExternalDisplayPlayback, airPlay: self.isAirPlayActive), let current = self.current {
                        self.activateSoftware(for: current, position: self.elapsed); return
                    }
                    self.isLoading = false
                    let error = item.error as NSError?
                    let unsupported = error?.domain == AVFoundationErrorDomain && [AVError.Code.fileFormatNotRecognized.rawValue, AVError.Code.decoderNotFound.rawValue].contains(error?.code ?? 0)
                    self.errorMessage = unsupported ? MediaImportError.unsupported.localizedDescription : (item.error?.localizedDescription ?? tr("تعذّر تشغيل المصدر. تحقق من الرابط والاتصال.", "Unable to play this source. Check its URL and connection."))
                }
                self.updateNowPlaying()
            }
            .store(in: &itemBag)
    }

    static func permitsSoftwareDecoding(preference: String, external: Bool, airPlay: Bool) -> Bool {
        preference != "never" && !external && !airPlay
    }

    private func activateSoftware(for media: Item, position: Double) {
        guard !isExternalDisplayPlayback, !isAirPlayActive else { return }
        startupTimeout?.cancel(); itemBag.removeAll(); player.pause(); player.replaceCurrentItem(with: nil)
        software?.stop()
        let decoder = SoftwareDecoder(); software = decoder; isSoftwareDecoding = true
        isLoading = false; errorMessage = nil
        decoder.progress = { [weak self, weak decoder] at, total, playing in
            guard let self, self.software === decoder else { return }
            self.elapsed = at; self.duration = total; self.isPlaying = playing
            self.enforceSafety()
            if abs(at - self.lastSaved) >= 5 { self.savePosition() }
            self.updateNowPlaying()
            if total > 0, at >= total - 0.25, PlayerPreferences.autoNext { self.next() }
        }
        decoder.failure = { [weak self, weak decoder] in
            guard let self, self.software === decoder else { return }
            self.errorMessage = MediaImportError.unsupported.localizedDescription; self.isPlaying = false
        }
        decoder.play(media.url, position: PlayerPreferences.resume ? position : 0)
        decoder.player.rate = AppState.shared.isCarConnected || media.isLive ? 1 : Float(PlayerPreferences.number("rate", 1))
        loadArtwork(for: media)
    }

    private func loadArtwork(for item: Item) {
        if let url = item.artworkURL, url.isFileURL, let image = UIImage(contentsOfFile: url.path) {
            artwork = image; updateNowPlaying(); return
        }
        ImageLoader.shared.load(item.artworkURL) { [weak self] image in
            guard let self, self.current == item else { return }
            if let image { self.artwork = image }
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
            MPMediaItemPropertyAlbumTitle: current.subtitle,
            MPNowPlayingInfoPropertyIsLiveStream: current.isLive,
            MPNowPlayingInfoPropertyMediaType: (["mp3", "m4a", "aac", "wav", "aiff", "flac"].contains(current.url.pathExtension.lowercased()) ? MPNowPlayingInfoMediaType.audio : .video).rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: isSoftwareDecoding ? (isPlaying ? Double(software?.player.rate ?? 1) : 0) : Double(player.rate)
        ]
        let center = MPRemoteCommandCenter.shared()
        let canSeek = self.canSeek
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
        let elapsed = isSoftwareDecoding ? self.elapsed : player.currentTime().seconds
        if elapsed.isFinite { info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed }
        if let duration = isSoftwareDecoding ? self.duration : player.currentItem?.duration.seconds, duration.isFinite, !current.isLive {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        }
        PlaybackActivity.shared.update(title: current.title, elapsed: self.elapsed, duration: self.duration, playing: isPlaying, casting: isAirPlayActive)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.changePlaybackRateCommand.supportedPlaybackRates = [0.5, 1, 1.5, 2]
        center.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackRateCommandEvent, !AppState.shared.isCarConnected else { return .commandFailed }
            self?.setRate(event.playbackRate); return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in self?.next(); return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in self?.previous(); return .success }
        center.playCommand.addTarget { [weak self] _ in
            guard SubscriptionStore.shared.hasAccess else { return .commandFailed }
            if self?.isSoftwareDecoding == true { self?.software?.player.play() } else { self?.player.play() }; return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            if self?.isSoftwareDecoding == true { self?.software?.player.pause() } else { self?.player.pause() }; return .success
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
            self.seek(by: event.positionTime - (self.isSoftwareDecoding ? self.elapsed : self.player.currentTime().seconds))
            return .success
        }
    }

    private func seekRemote(by seconds: Double) {
        seek(by: seconds)
    }
}

// MARK: - شاشة المشغل على الهاتف (فيها زر AirPlay وصورة داخل صورة)

struct PlayerScreen: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) { PlaybackManager.shared.isPictureInPictureActive = true }
        func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
            let playback = PlaybackManager.shared
            playback.isPictureInPictureActive = false
            if !playback.isPlayerPresented && !playback.isExternalDisplayPlayback { playback.stop() }
        }
        func playerViewController(_ playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
            PlaybackManager.shared.isPlayerPresented = true
            completionHandler(true)
        }
    }
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.delegate = context.coordinator
        controller.player = PlaybackManager.shared.player
        controller.allowsPictureInPicturePlayback = PlayerPreferences.flag("pip", true)
        controller.canStartPictureInPictureAutomaticallyFromInline = PlayerPreferences.flag("pip", true)
        // نحن ننشر معلومات Now Playing بأنفسنا
        controller.updatesNowPlayingInfoCenter = false
        controller.videoGravity = PlayerPreferences.gravity
        controller.entersFullScreenWhenPlaybackBegins = PlayerPreferences.flag("autoFullscreen", true)
        controller.exitsFullScreenWhenPlaybackEnds = true
        PlayerZoomOverlay.apply(to: controller)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.videoGravity = PlayerPreferences.gravity
        PlayerZoomOverlay.apply(to: controller)
        controller.allowsPictureInPicturePlayback = PlayerPreferences.flag("pip", true)
    }
}
