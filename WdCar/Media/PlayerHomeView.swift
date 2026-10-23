import SwiftUI
import AVKit

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
                        Button { playback.isPlayerPresented = true } label: { Label(item.title, systemImage: "play.rectangle") }
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
    var body: some View {
        NavigationStack {
            List {
                Section {
                    AirPlayButton().frame(height: 60).listRowBackground(Color.wdNavy)
                    Text(tr("اختر شاشة السيارة أو التلفزيون", "Choose the car display or television"))
                    Text(tr("يتطلب جهاز استقبال متوافقاً مع AirPlay. لا يتضمن التطبيق Google Cast.", "Requires an AirPlay-compatible receiver. Google Cast is not included.")).font(.footnote).foregroundStyle(.secondary)
                    Text(app.carScreenText)
                    Button(tr("فتح المتصفح على شاشة السيارة", "Open browser on car screen")) { app.showCarScreenHelp = true }
                }
                CarConnectionCard()
                Text(tr("للركاب فقط — لا تشاهد أثناء القيادة", "Passengers only — do not watch while driving"))
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
