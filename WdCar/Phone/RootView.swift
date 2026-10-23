import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @ObservedObject private var bridge = CarKeyboardBridge.shared
    @AppStorage(WDKeys.language) private var language = L10n.language.rawValue
    @AppStorage(WDKeys.appearance) private var appearance = AppAppearance.system.rawValue
    @State private var introFinished = false

    var body: some View {
        ZStack {
            MainTabView()
                .id(language) // يعيد بناء الواجهة بعد تغيير اللغة
                .sheet(isPresented: $app.showCarScreenHelp) {
                    CarScreenSheet()
                        .environmentObject(app)
                        .presentationDetents([.medium, .large])
                }

            if !introFinished {
                IntroView {
                    withAnimation(.easeOut(duration: 0.35)) { introFinished = true }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .environment(\.layoutDirection, language == AppLanguage.ar.rawValue ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: language))
        .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
        .sheet(isPresented: $bridge.isPhoneEditorPresented) {
            PhoneCarKeyboardSheet()
                .presentationDetents([.large])
        }
        .overlay(alignment: .top) {
            if let text = app.toast {
                ToastView(text: text)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: app.toast)
    }
}

struct MainTabView: View {
    @ObservedObject private var playback = PlaybackManager.shared
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            HomeView(selectTab: { tab = $0 })
                .tabItem { Label(tr("الرئيسية", "Home"), systemImage: "house") }
                .tag(0)
            SubscriptionGate { PhoneBrowserScreen() }
                .tabItem { Label(tr("الترفيه", "Entertainment"), systemImage: "play.tv") }
                .tag(1)
            SubscriptionGate { XtreamHomeView() }
                .tabItem { Label("Xtream", systemImage: "antenna.radiowaves.left.and.right") }
                .tag(2)
            SubscriptionGate { MediaLibraryView() }
                .tabItem { Label(tr("المكتبة", "Library"), systemImage: "play.rectangle.on.rectangle") }
                .tag(3)
            SettingsView(isSheet: false)
                .tabItem { Label(tr("الإعدادات", "Settings"), systemImage: "gearshape") }
                .tag(4)
        }
        .fullScreenCover(isPresented: $playback.isPlayerPresented) {
            PlayerContainer()
                .onDisappear { if !playback.isExternalDisplayPlayback { playback.stop() } }
        }
    }
}

/// المشغل بملء الشاشة على الهاتف + زر إغلاق + زر AirPlay
private struct PlayerContainer: View {
    @ObservedObject private var playback = PlaybackManager.shared
    @ObservedObject private var captions = ExternalSubtitles.shared
    @State private var importSubtitle = false
    @State private var subtitleError: String?
    @AppStorage("wd.media.externalSubtitles") private var externalSubtitles = true
    @AppStorage("wd.media.subtitleSize") private var subtitleSize = 22.0
    @AppStorage("wd.media.subtitleDelay") private var subtitleDelay = 0.0
    @AppStorage("wd.media.subtitleYellow") private var subtitleYellow = false
    @AppStorage("wd.media.subtitleBackground") private var subtitleBackground = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            PlayerScreen().ignoresSafeArea()
            if externalSubtitles && !playback.player.isExternalPlaybackActive {
                VStack {
                    Spacer()
                    let text = captions.text(at: playback.elapsed - subtitleDelay, mediaURL: playback.current?.url)
                    if !text.isEmpty {
                        Text(text).font(.system(size: subtitleSize)).multilineTextAlignment(.center)
                            .foregroundStyle(subtitleYellow ? Color.yellow : Color.white)
                            .padding(8).background(subtitleBackground ? Color.black.opacity(0.75) : Color.clear)
                            .padding(.bottom, 95)
                    }
                }.frame(maxWidth: .infinity).allowsHitTesting(false)
            }
            HStack {
                Button {
                    playback.stop()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                Spacer()
                if let error = playback.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Capsule().fill(Color.red.opacity(0.8)))
                }
                Spacer()
                Menu {
                    Button(tr("السابق", "Previous")) { playback.previous() }
                    Button(tr("التالي", "Next")) { playback.next() }
                    Button(tr("تأخير", "Skip backward")) { playback.seek(by: -Double(PlayerPreferences.skip)) }
                    Button(tr("تقديم", "Skip forward")) { playback.seek(by: Double(PlayerPreferences.skip)) }
                    Button(tr("استيراد SRT/VTT للهاتف", "Import SRT/VTT for iPhone")) { importSubtitle = true }
                    ForEach(Array(playback.queue.enumerated()), id: \.offset) { _, item in
                        Button(item.title) { playback.play(item, presentOnPhone: true) }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill").font(.title).foregroundStyle(.white)
                }
                AirPlayButton()
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .environment(\.layoutDirection, .leftToRight)
        }
        .fileImporter(isPresented: $importSubtitle, allowedContentTypes: [.plainText, UTType(filenameExtension: "srt") ?? .data, UTType(filenameExtension: "vtt") ?? .data]) { result in
            do {
                guard let mediaURL = playback.current?.url else { return }
                try captions.load(result.get(), for: mediaURL)
            } catch { subtitleError = error.localizedDescription }
        }
        .alert(tr("خطأ في الترجمة", "Subtitle error"), isPresented: Binding(get: { subtitleError != nil }, set: { if !$0 { subtitleError = nil } })) {
            Button(tr("حسنًا", "OK")) { subtitleError = nil }
        } message: { Text(subtitleError ?? "") }
    }
}

// MARK: - عناصر مشتركة

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color.wdNavy))
            .overlay(Capsule().stroke(Color.wdAccent.opacity(0.7), lineWidth: 1))
            .shadow(radius: 12)
    }
}

struct CircleIconButton<Icon: View>: View {
    var size: CGFloat = 52
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        Button(action: action) {
            icon()
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(Color(white: 0.13)))
                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// أيقونة "إرسال للسيارة" (سيارة + سهم مشاركة) مثل CarTV
struct SendToCarIcon: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "car.side")
                .font(.system(size: 20, weight: .regular))
                .offset(x: -4, y: -4)
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 13, weight: .semibold))
                .offset(x: 4, y: 4)
        }
    }
}

