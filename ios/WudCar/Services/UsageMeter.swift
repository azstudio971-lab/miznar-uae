import SwiftUI
import Combine

struct TrialStatus: Decodable {
    let used_seconds: Int
    let remaining_seconds: Int
    let entitled: Bool
    let lease_seconds: Int
}

/// Server time is authoritative. No allowance is stored locally or reset on reinstall.
@MainActor final class UsageMeter: ObservableObject {
    static let shared = UsageMeter()
    @Published private(set) var status: TrialStatus?
    @Published private(set) var allowed = false
    @Published private(set) var message: String?
    var foreground = true
    private var previews = Set<UUID>()
    private var sessionID = UUID().uuidString
    private var sequence = 0
    private var owner: String?
    private var wasActive = false
    private var pendingActive: Bool?
    private var leaseDeadline = Date.distantPast
    private var nextHeartbeat = Date.distantPast
    // Billing remains off until hosted and StoreKit sandbox verification passes.
    var enabled: Bool { AppConfiguration.subscriptionsEnabled && AppState.shared.catalogSettings?.trial_enabled == true }
    func preview(_ id: UUID, visible: Bool) { if visible { previews.insert(id) } else { previews.remove(id) } }
    func reset() {
        status = nil; allowed = false; message = nil; owner = nil
        sessionID = UUID().uuidString; sequence = 0; wasActive = false; pendingActive = nil
        leaseDeadline = .distantPast; nextHeartbeat = .distantPast
    }
    func loadStatus() async {
        guard enabled, CloudClient.shared.session != nil else { return }
        do {
            let data = try await CloudClient.shared.request("/rest/v1/rpc/trial_status", method: "POST", body: Data("{}".utf8), authenticated: true)
            status = try JSONDecoder().decode(TrialStatus.self, from: data)
        } catch { message = error.localizedDescription }
    }
    /// A status check grants only startup permission; time starts on actual playback.
    func authorizePlayback() async -> Bool {
        guard enabled else { return true }
        let cloud = CloudClient.shared
        guard let user = cloud.session?.user.id else { return false }
        if owner != user { reset(); owner = user }
        do {
            try await cloud.registerDevice()
            let data = try await cloud.request("/rest/v1/rpc/trial_status", method: "POST", body: Data("{}".utf8), authenticated: true, timeout: 4)
            guard cloud.session?.user.id == user, owner == user else { return false }
            let result = try JSONDecoder().decode(TrialStatus.self, from: data)
            status = result
            guard result.entitled || result.remaining_seconds > 0 else { return false }
            allowed = true; leaseDeadline = Date().addingTimeInterval(2)
            nextHeartbeat = .distantPast
            return true
        } catch { message = error.localizedDescription; return false }
    }
    func run() async {
        while !Task.isCancelled {
            await tick()
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
        }
    }
    private func tick() async {
        guard enabled else { allowed = true; return }
        let cloud = CloudClient.shared
        if owner != cloud.session?.user.id { reset(); owner = cloud.session?.user.id }
        guard owner != nil else {
            allowed = false
            message = AppState.shared.text("سجّل الدخول لبدء دقائقك المجانية.", "Sign in to start your free minutes.")
            PlayerService.shared.player.pause(); return
        }
        let active = (foreground && !previews.isEmpty) || PlayerService.shared.player.timeControlStatus == .playing
        if Date() >= leaseDeadline { allowed = false; if wasActive && active { PlayerService.shared.player.pause() } }
        guard active || wasActive || pendingActive != nil else { return }
        guard active != wasActive || Date() >= nextHeartbeat else { return }
        // Renew within the 15-second lease with a bounded request timeout.
        if Date() >= leaseDeadline { allowed = false }
        let sentAt = Date()
        let sendingActive = pendingActive ?? active
        let requestOwner = owner
        let requestSession = sessionID
        do {
            if sequence == 0 { try await cloud.registerDevice() }
            let body = try JSONSerialization.data(withJSONObject: ["p_session": sessionID, "p_device": cloud.deviceID, "p_sequence": sequence + 1, "p_active": sendingActive])
            let data = try await cloud.request("/rest/v1/rpc/trial_heartbeat", method: "POST", body: body, authenticated: true, timeout: 4)
            guard owner == requestOwner, cloud.session?.user.id == requestOwner, sessionID == requestSession else { return }
            let result = try JSONDecoder().decode(TrialStatus.self, from: data)
            sequence += 1; status = result; wasActive = sendingActive; pendingActive = nil; message = nil
            leaseDeadline = sentAt.addingTimeInterval(TimeInterval(result.lease_seconds))
            allowed = result.entitled || (result.remaining_seconds > 0 && Date() < leaseDeadline)
            nextHeartbeat = Date().addingTimeInterval(5)
            if result.remaining_seconds == 0 && !result.entitled {
                allowed = false; PlayerService.shared.player.pause()
                message = AppState.shared.text("انتهت دقائقك المجانية. اختر الاشتراك من الإعدادات.", "Your free minutes are used. Choose a subscription in Settings.")
            }
        } catch {
            // Retry the same sequence after a lost response: server deduplicates it.
            pendingActive = sendingActive
            nextHeartbeat = Date().addingTimeInterval(5)
            message = error.localizedDescription
            if Date() >= leaseDeadline { allowed = false; PlayerService.shared.player.pause() }
        }
    }
}

struct MeteredPreview: ViewModifier {
    @ObservedObject private var meter = UsageMeter.shared
    @EnvironmentObject var state: AppState
    @State private var id = UUID()
    func body(content: Content) -> some View {
        ZStack {
            content.opacity(meter.enabled && !meter.allowed ? 0 : 1)
                .allowsHitTesting(!meter.enabled || meter.allowed)
            if meter.enabled && !meter.allowed {
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.exclamationmark").font(.largeTitle)
                    Text(meter.message ?? state.text("جارٍ التحقق من الدقائق المتبقية…", "Checking your remaining minutes…"))
                    NavigationLink(state.text("الحساب والاشتراك", "Account and subscription")) { SubscriptionView() }
                }.padding().frame(maxWidth: .infinity, maxHeight: .infinity).background(.regularMaterial)
            }
        }.onAppear { meter.preview(id, visible: true) }.onDisappear { meter.preview(id, visible: false) }
    }
}
