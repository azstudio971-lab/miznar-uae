import SwiftUI
import AVKit
import CoreLocation

struct PlayerHomeView: View {
    @ObservedObject private var library = MediaLibrary.shared
    @ObservedObject private var playback = PlaybackManager.shared
    @EnvironmentObject private var app: AppState
    var body: some View {
        NavigationStack {
            List {
                Section(tr("يعمل الآن", "Now playing")) {
                    if let item = playback.current {
                        MiniMediaPlayer().frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 12))
                        Button { playback.presentPlayer() } label: { Label(item.title, systemImage: "play.rectangle") }
                        HStack {
                            Button { playback.previous() } label: { Image(systemName: "backward.end.fill") }.disabled(!playback.canPlayPrevious)
                            Spacer()
                            Button { playback.togglePlayPause() } label: { Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill") }
                            Spacer()
                            Button { playback.next() } label: { Image(systemName: "forward.end.fill") }.disabled(!playback.canPlayNext)
                        }.buttonStyle(.borderless)
                        if playback.duration > 0 { ProgressView(value: min(max(playback.elapsed / playback.duration, 0), 1)) }
                    } else { Text(tr("أضف وسائطك من المكتبة أو البث", "Add your media from Library or TV")).foregroundStyle(.secondary) }
                }
                Section(tr("متابعة المشاهدة", "Continue watching")) {
                    ForEach(library.items.filter { $0.position > 0 }.sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }) { item in
                        mediaButton(item)
                    }
                }
                Section(tr("قوائم التشغيل", "Playlists")) {
                    NavigationLink(tr("إدارة قوائم التشغيل", "Manage playlists")) { MediaPlaylistsView() }
                    ForEach(library.playlists) { list in Button(list.name) { library.play(list, onPhone: true) } }
                }
                Section(tr("آخر القنوات", "Recent channels")) {
                    ForEach(Array(library.items.filter { $0.isLive && $0.lastPlayed != nil }.sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }.prefix(10))) { mediaButton($0) }
                }
                Section {
                    CarConnectionCard()
                }
            }.navigationTitle(tr("المشغّل", "Player"))
        }
    }
    private func mediaButton(_ item: LibraryMedia) -> some View {
        Button { if let media = item.playbackItem { playback.playQueue([media], startingAt: nil, presentOnPhone: true) } } label: { Label(item.title, systemImage: "play.circle") }
    }
}

struct CastView: View {
    @EnvironmentObject private var app: AppState
    @ObservedObject private var playback = PlaybackManager.shared
    @ObservedObject private var driving = DrivingMonitor.shared
    var body: some View {
        NavigationStack {
            List {
                Section(tr("الوسائط", "Media")) {
                    if let item = playback.current {
                        Label(item.title, systemImage: "play.rectangle")
                        Button(tr("تشغيل الوسائط على الجهاز المختار", "Play media on the selected device")) {
                            playback.castCurrentMedia()
                        }.accessibilityIdentifier("cast.play.current")
                    } else {
                        Text(tr("اختر وسائطك أولاً، ثم اختر جهاز الاستقبال.", "Choose your media, then choose a receiver."))
                    }
                    NavigationLink(tr("اختيار من المكتبة", "Choose from Library")) { MediaLibraryView() }
                }
                Section("AirPlay") {
                    AirPlayButton().frame(height: 60).listRowBackground(Color.wdNavy)
                    Text(playback.isAirPlayActive ? tr("البث نشط", "Streaming active") : tr("اختر جهاز الاستقبال من زر AirPlay", "Choose a receiver using the AirPlay button"))
                        .accessibilityIdentifier("cast.route.status")
                    Text(tr("تظهر السيارة هنا إذا كانت تدعم استقبال الفيديو عبر AirPlay. اتصال CarPlay وحده لا يضمن دعم بث الفيديو.", "The car appears here if it supports AirPlay video reception. CarPlay connection alone does not guarantee video streaming support."))
                        .font(.footnote).foregroundStyle(.secondary)
                    if app.isCarConnected && app.carVideoSupport == .unsupported {
                        Text(tr("السيارة المتصلة لا تعلن دعم الفيديو؛ يتاح تشغيل الصوت.", "The connected car does not report video support; audio playback is available."))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if app.isCarConnected && driving.authorization == .notDetermined {
                    Section {
                        Button(tr("تفعيل مراقبة الحركة", "Enable motion monitoring")) {
                            driving.requestMonitoringPermission()
                        }
                    }
                }
                if let error = playback.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
                CarConnectionCard()
            }.navigationTitle("Cast / AirPlay")
        }
    }
}

struct MiniMediaPlayer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = PlaybackManager.shared.player
        controller.updatesNowPlayingInfoCenter = false
        controller.videoGravity = PlayerPreferences.gravity
        controller.allowsPictureInPicturePlayback = PlayerPreferences.flag("pip", true)
        controller.entersFullScreenWhenPlaybackBegins = false
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) { controller.videoGravity = PlayerPreferences.gravity }
}
