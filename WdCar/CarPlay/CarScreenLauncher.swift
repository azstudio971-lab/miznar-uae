import AVFoundation
import Foundation

/// يحاول فتح «وضع الفيديو» في السيارة من قوالب CarPlay:
/// يشغّل مقطعاً قصيراً من التطبيق (مقطع المقدمة) كعنصر فيديو، فيعرض CarPlay شاشة الفيديو
/// ويتصل مشهد الشاشة الخارجية، وعندها نوقف المقطع ونعرض المتصفح.
/// كل خطوة تُسجَّل في Console بكلمة WUDCAR لنعرف من أول تجربة أي مسار يعمل في سيارتك.
final class CarScreenLauncher {
    static let shared = CarScreenLauncher()

    private(set) var isLaunching = false
    private var timeout: DispatchWorkItem?

    private init() {}

    func launch() {
        guard !AppState.shared.carScreenActive else {
            WDLog.car("launcher: car screen already active")
            return
        }
        // A route may already exist for media. Reuse it only after this explicit
        // browser action; connection itself must keep the native CarPlay tabs.
        if CarExternalDisplaySceneDelegate.presentBrowserIfConnected() {
            // Keep the existing media route alive, as the original bootstrap
            // path does; replacing its item can disconnect the external scene.
            PlaybackManager.shared.player.pause()
            return
        }
        guard let url = Bundle.main.url(forResource: "intro_night", withExtension: "mp4") else {
            WDLog.car("launcher: intro clip missing")
            return
        }
        isLaunching = true
        WDLog.car("launcher: starting video mode with bootstrap clip")
        PlaybackManager.shared.play(.init(title: "WudCar",
                                          subtitle: tr("المتصفح", "Browser"),
                                          url: url,
                                          isLive: false,
                                          artworkURL: nil),
                                    presentOnPhone: false)

        timeout?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isLaunching else { return }
            self.isLaunching = false
            let external = PlaybackManager.shared.player.isExternalPlaybackActive
            WDLog.car("launcher: no external display after 12s (externalPlaybackActive=\(external))")
        }
        timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: work)
    }

    func externalDisplayDidConnect() {
        guard isLaunching else { return }
        isLaunching = false
        timeout?.cancel()
        // إيقاف مؤقت فقط (وليس إزالة) حتى لا ينهي CarPlay وضع الفيديو. السجل يوضح إن انقطعت الشاشة بعده.
        WDLog.car("launcher: external display connected — pausing bootstrap clip")
        PlaybackManager.shared.player.pause()
    }
}
