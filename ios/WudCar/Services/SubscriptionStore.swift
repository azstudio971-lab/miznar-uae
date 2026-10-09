import StoreKit
import Combine

@MainActor final class SubscriptionStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var entitled = false
    @Published var message: String?
    private var updates: Task<Void, Never>?
    init() {
        guard AppConfiguration.subscriptionsEnabled else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await self?.refreshEntitlements(); await transaction.finish()
            }
        }
    }
    deinit { updates?.cancel() }
    func load() async {
        guard AppConfiguration.subscriptionsEnabled else { return }
        do { products = try await Product.products(for: AppConfiguration.productIDs); await refreshEntitlements() }
        catch { message = error.localizedDescription }
    }
    func buy(_ product: Product) async {
        guard AppConfiguration.subscriptionsEnabled else { return }
        do {
            guard let id=CloudClient.shared.session?.user.id,let token=UUID(uuidString:id)else {throw WudError.message("Please sign in / يرجى تسجيل الدخول")}
            switch try await product.purchase(options:[.appAccountToken(token)]) {
            case .success(let result):
                guard case .verified(let transaction) = result else { throw WudError.message("Purchase could not be verified / تعذر التحقق من الشراء") }
                await refreshEntitlements(); await transaction.finish()
            case .pending: message = "Purchase pending / عملية الشراء معلقة"
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = error.localizedDescription }
    }
    func restore() async { do { try await AppStore.sync(); await refreshEntitlements() } catch { message = error.localizedDescription } }
    private func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, AppConfiguration.productIDs.contains(t.productID), t.revocationDate == nil, !t.isUpgraded else { continue }
            if let expiration = t.expirationDate, expiration > Date() { active = true }
        }
        entitled = active
    }
}
