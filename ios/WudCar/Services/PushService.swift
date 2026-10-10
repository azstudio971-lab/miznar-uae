import UIKit
import CarPlay
import UserNotifications
import Combine

@MainActor final class PushService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = PushService()
    @Published var status = ""
    @Published var enabled = false
    private var token: String? { get { SecureStore.load("apns-token").flatMap { String(data: $0, encoding: .utf8) } } set { if let newValue { try? SecureStore.save(Data(newValue.utf8), key: "apns-token") } } }
    private func credential(_ key: String) -> String {
        if let data = SecureStore.load(key), let value = String(data: data, encoding: .utf8) { return value }
        let value = UUID().uuidString; try? SecureStore.save(Data(value.utf8), key: key); return value
    }
    override init() { super.init(); UNUserNotificationCenter.current().delegate = self }
    func requestPermission() async {
        do { enabled = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]); if enabled { UIApplication.shared.registerForRemoteNotifications() } else { status = "الإشعارات غير مسموحة. / Notifications are not allowed." } }
        catch { status = error.localizedDescription }
    }
    func registered(_ data: Data) { token = data.map { String(format: "%02x", $0) }.joined(); Task { await sync() } }
    func sync() async {
        guard let token else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        enabled = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        let p = AppState.shared.preferences
        let environment = Bundle.main.object(forInfoDictionaryKey: "WUD_APNS_ENVIRONMENT") as? String ?? "sandbox"
        let payload: [String: Any] = ["installation_id": credential("push-installation"), "secret": credential("push-secret"), "device_token": token, "environment": environment, "city": p.city, "region": p.region, "country": p.country, "action": enabled ? "register" : "disable"]
        do { let body = try JSONSerialization.data(withJSONObject: payload); _ = try await CloudClient.shared.request("/functions/v1/push-register", method: "POST", body: body, authenticated: CloudClient.shared.session != nil); status = enabled ? "الإشعارات مفعلة / Notifications enabled" : "الإشعارات معطلة / Notifications disabled" }
        catch { status = error.localizedDescription }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound, .list] }
}
@MainActor final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        guard connectingSceneSession.role == .carTemplateApplication else { return connectingSceneSession.configuration }
        let configuration = UISceneConfiguration(name: "CarPlay", sessionRole: connectingSceneSession.role)
        configuration.sceneClass = CPTemplateApplicationScene.self
        configuration.delegateClass = CarPlaySceneDelegate.self
        return configuration
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) { PushService.shared.registered(deviceToken) }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) { PushService.shared.status = error.localizedDescription }
}
