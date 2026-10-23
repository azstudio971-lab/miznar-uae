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
                        if ["mp3", "m4a", "aac", "wav", "aiff", "flac", "ogg"].contains(item.url.pathExtension.lowercased()) {
                            AudioVisualizer().frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 12))
                        } else if playback.isSoftwareDecoding, let decoder = playback.software {
                            SoftwarePlayerView(decoder: decoder).frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 12))
                        } else { MiniMediaPlayer().frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 12)) }
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
                Section(tr("المصادر", "Sources")) {
                    NavigationLink(tr("مصادري", "My sources")) { SourcesView() }
                    NavigationLink(tr("بحث في جميع الوسائط", "Search all media")) { MediaSearchView() }
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
    @ObservedObject private var relay = ScreenRelay.shared
    @State private var castMessage: String?
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
                Section(tr("عكس الشاشة", "Screen mirroring")) {
                    if !SubscriptionStore.shared.hasAccess {
                        NavigationLink(tr("تفعيل الاشتراك", "Activate subscription")) { SubscriptionView() }
                    } else if relay.available {
                        HStack {
                            BroadcastPicker().frame(width: 60, height: 60)
                            Text(relay.active ? tr("التقاط الشاشة نشط — الإنهاء من زر النظام", "Capture active — stop using the system control") : tr("بدء مشاركة الشاشة عبر النظام", "Start sharing using the system control"))
                        }
                        Text(app.externalDisplayActive ? tr("شاشة خارجية متصلة", "External display connected") : tr("بانتظار شاشة خارجية متوافقة", "Waiting for a compatible external display")).font(.footnote)
                        Text(tr("يتطلب شاشة خارجية متصلة ومتوافقة. قد يمنع iOS التقاط المحتوى المحمي أو استمرار العرض في الخلفية.", "Requires a connected compatible external display. iOS may restrict protected content capture or background presentation.")).font(.footnote)
                    } else { Text(tr("مشاركة الشاشة غير متاحة في هذا التثبيت.", "Screen sharing is unavailable in this installation.")) }
                }
                Section(tr("صفحة الويب الحالية", "Current web page")) {
                    Button(tr("إرسال صفحة الهاتف إلى السيارة", "Send iPhone page to car")) {
                        guard SubscriptionStore.shared.hasAccess else { castMessage = tr("الاشتراك مطلوب", "Subscription required"); return }
                        guard let url = TabStore.phone.activeTab?.url else { castMessage = tr("افتح صفحة في متصفح الهاتف أولاً.", "Open a page in the iPhone browser first."); return }
                        guard !TabStore.car.isFull else { castMessage = tr("وصلت إلى الحد الأقصى: 8 تبويبات. أغلق تبويباً من متصفح السيارة.", "The 8-tab limit is reached. Close a tab in the car browser."); return }
                        TabStore.car.open(url, inNewTab: true)
                        CarScreenLauncher.shared.launch()
                    }
                    if let castMessage { Text(castMessage).font(.footnote) }
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
            }.navigationTitle("Cast / AirPlay").onAppear { relay.monitor() }
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
