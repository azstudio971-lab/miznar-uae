import SwiftUI
import AVFoundation

/// انترو WudCar عند فتح التطبيق على iPhone فقط (لا يظهر في CarPlay):
/// النهاري في الوضع الفاتح، والليلي في الوضع الداكن. ينتهي تلقائياً، ويمكن تخطيه باللمس.
struct IntroView: View {
    @Environment(\.colorScheme) private var scheme
    let onFinish: () -> Void

    var body: some View {
        let isDark = scheme == .dark
        ZStack {
            (isDark ? Color.black : Color.white).ignoresSafeArea()
            IntroPlayerView(resource: isDark ? "intro_night" : "intro_day", onFinish: onFinish)
                .id(isDark)
                .ignoresSafeArea()
        }
        .overlay(alignment: .bottom) { Text("WudCar Media Player").font(.headline).padding(.bottom, 60) }
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .accessibilityLabel("WudCar")
    }
}

final class IntroPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct IntroPlayerView: UIViewRepresentable {
    let resource: String
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIView(context: Context) -> IntroPlayerUIView {
        let view = IntroPlayerUIView()
        view.backgroundColor = .clear
        // يحافظ على نسب أبعاد الفيديو بدون قص
        view.playerLayer.videoGravity = .resizeAspect

        guard let url = Bundle.main.url(forResource: resource, withExtension: "mp4") else {
            DispatchQueue.main.async { context.coordinator.finish() }
            return view
        }
        let player = AVPlayer(url: url)
        // لا نحسبه "تشغيلاً حالياً" في السيارة أو مركز التحكم
        player.allowsExternalPlayback = false
        view.playerLayer.player = player
        context.coordinator.observe(player)
        player.play()
        return view
    }

    func updateUIView(_ uiView: IntroPlayerUIView, context: Context) {}

    static func dismantleUIView(_ uiView: IntroPlayerUIView, coordinator: Coordinator) {
        uiView.playerLayer.player?.pause()
        uiView.playerLayer.player = nil
    }

    final class Coordinator {
        private let onFinish: () -> Void
        private var token: NSObjectProtocol?
        private var finished = false

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func observe(_ player: AVPlayer) {
            token = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak self] _ in self?.finish() }
            // أمان: لا يعلق التطبيق إذا تعذّر تشغيل الفيديو
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in self?.finish() }
        }

        func finish() {
            guard !finished else { return }
            finished = true
            onFinish()
        }

        deinit {
            if let token { NotificationCenter.default.removeObserver(token) }
        }
    }
}
