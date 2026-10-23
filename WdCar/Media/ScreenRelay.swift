import SwiftUI
import ReplayKit
import Combine

final class ScreenRelay: ObservableObject {
    static let shared = ScreenRelay()
    @Published private(set) var active = false
    @Published private(set) var image: UIImage?
    private var timer: Timer?
    private var presented = false
    private var lastFrame: Date?
    private var lastStateRead = Date.distantPast
    private var relayState: CastShared.RelayState?
    var available: Bool { CastShared.directory != nil }
    func monitor() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in self?.refresh() }
    }
    private func refresh() {
        if Date().timeIntervalSince(lastStateRead) >= 1 {
            lastStateRead = Date()
            relayState = CastShared.state.flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(CastShared.RelayState.self, from: $0) }
        }
        let state = relayState
        let broadcasting = state?.active == true && Date().timeIntervalSince(state?.updated ?? .distantPast) < 3
        if broadcasting != active { active = broadcasting }
        if !broadcasting || !SubscriptionStore.shared.hasAccess {
            image = nil
            if !broadcasting, let frame = CastShared.frame, FileManager.default.fileExists(atPath: frame.path) { try? FileManager.default.removeItem(at: frame) }
            if presented { CarExternalDisplaySceneDelegate.returnToTemplates(); presented = false }
            return
        }
        if !presented { presented = CarExternalDisplaySceneDelegate.presentRelayIfConnected() }
        guard let file = CastShared.frame else { return }
        let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        guard modified != lastFrame else { return }; lastFrame = modified
        if let data = try? Data(contentsOf: file) { image = UIImage(data: data) }
    }
}
struct BroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        picker.preferredExtension = "com.azstudio.wudcar.ScreenRelay"
        picker.showsMicrophoneButton = false
        return picker
    }
    func updateUIView(_ view: RPSystemBroadcastPickerView, context: Context) {}
}
struct RelayDisplay: View {
    @ObservedObject private var relay = ScreenRelay.shared
    @ObservedObject private var driving = DrivingMonitor.shared
    var body: some View {
        ZStack {
            Color.black
            if !SubscriptionStore.shared.hasAccess {
                Text(tr("الاشتراك مطلوب", "Subscription required")).foregroundStyle(.white)
            } else if driving.shouldBlockVideo {
                Text(tr("الفيديو متوقف أثناء حركة السيارة", "Video paused while the vehicle is moving")).foregroundStyle(.white)
            } else if let image = relay.image { Image(uiImage: image).resizable().scaledToFit() }
            else { Text(tr("بانتظار صورة من iPhone", "Waiting for iPhone frames")).foregroundStyle(.white) }
        }.ignoresSafeArea()
    }
}
