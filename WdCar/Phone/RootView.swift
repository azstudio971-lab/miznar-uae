import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @ObservedObject private var bridge = CarKeyboardBridge.shared
    @AppStorage(WDKeys.language) private var language = L10n.language.rawValue
    @AppStorage(WDKeys.appearance) private var appearance = AppAppearance.system.rawValue
    @State private var introFinished = false
    @AppStorage("wd.safetyNotice301") private var safetyAccepted = false

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
        .alert(tr("إذن الموقع", "Location permission"), isPresented: $app.showLocationExplanation) {
            Button(tr("متابعة", "Continue")) { DrivingMonitor.shared.requestAuthorizationAfterExplanation() }
        } message: {
            Text(tr("يستخدم WudCar السرعة لحظياً لإيقاف الفيديو عند الحركة دون تخزين موقعك أو إرساله. عند رفض الإذن يُمنع فيديو السيارة إلا إذا أعلنت السيارة دعم الفيديو؛ ويظل تحكم النظام سارياً.", "WudCar uses speed in real time to stop video when moving, without storing or sending location. If denied, car video remains blocked unless the car reports video support; system restrictions always apply."))
        }
        .alert(tr("للركاب فقط — لا تشاهد أثناء القيادة", "Passengers only — do not watch while driving"), isPresented: Binding(get: { introFinished && !safetyAccepted && !app.showLocationExplanation }, set: { if !$0 { safetyAccepted = true } })) {
            Button(tr("فهمت", "Understood")) { safetyAccepted = true }
        }
    }
}

struct MainTabView: View {
    @ObservedObject private var playback = PlaybackManager.shared
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            PlayerHomeView()
                .tabItem { Label(tr("المشغّل", "Player"), systemImage: "play.rectangle") }.tag(0)
            SubscriptionGate { XtreamHomeView() }
                .tabItem { Label(tr("البث", "TV"), systemImage: "antenna.radiowaves.left.and.right") }.tag(1)
            MediaLibraryView()
                .tabItem { Label(tr("المكتبة", "Library"), systemImage: "play.rectangle.on.rectangle") }.tag(2)
            CastView()
                .tabItem { Label("Cast", systemImage: "airplay.video") }.tag(3)
            SettingsView(isSheet: false)
                .tabItem { Label(tr("الإعدادات", "Settings"), systemImage: "gearshape") }
                .tag(4)
        }
        .fullScreenCover(isPresented: $playback.isPlayerPresented) {
            PlayerContainer()
                .onDisappear { if !playback.isExternalDisplayPlayback && !playback.isPictureInPictureActive && !playback.isMinimized { playback.stop() } }
        }
    }
}

/// المشغل بملء الشاشة على الهاتف + زر إغلاق + زر AirPlay
private struct PlayerContainer: View {
    @ObservedObject private var playback = PlaybackManager.shared
    @ObservedObject private var subtitles = ExternalSubtitles.shared

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            PlayerScreen().ignoresSafeArea()
            VStack {
                if PlayerPreferences.number("subtitlePosition", 90) > 50 { Spacer() }
                if PlayerPreferences.subtitles {
                    Text(subtitles.text(at: playback.elapsed, mediaURL: playback.current?.url))
                        .font(.system(size: 22 * PlayerPreferences.number("subtitleSize", 100) / 100))
                        .foregroundStyle(PlayerPreferences.text("subtitleColor", "white") == "yellow" ? Color.yellow : Color.white)
                        .padding(8).background(Color.black.opacity(PlayerPreferences.number("subtitleOpacity", 0.6)))
                }
                if PlayerPreferences.number("subtitlePosition", 90) <= 50 { Spacer() }
            }.frame(maxWidth: .infinity).padding(.vertical, 60).allowsHitTesting(false)
            HStack {
                Button {
                    playback.minimize()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                Button { playback.stop() } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44).background(Circle().fill(Color.black.opacity(0.5)))
                }.accessibilityLabel(tr("إغلاق المشغّل وإيقاف التشغيل", "Close and stop playback"))
                Spacer()
                if let error = playback.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Capsule().fill(Color.red.opacity(0.8)))
                }
                Spacer()
                AirPlayButton()
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .environment(\.layoutDirection, .leftToRight)
        }
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
