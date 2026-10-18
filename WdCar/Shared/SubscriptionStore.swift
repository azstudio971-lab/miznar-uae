import StoreKit
import Combine
import UIKit

enum WudCarSubscriptionState: String {
    case checking, notSubscribed, trial, active, grace, expired, billingRetry, revoked

    var title: String {
        switch self {
        case .checking: return tr("جارٍ التحقق", "Checking")
        case .notSubscribed: return tr("غير مشترك", "Not subscribed")
        case .trial: return tr("تجربة مجانية", "Free trial")
        case .active: return tr("اشتراك نشط", "Active subscription")
        case .grace: return tr("فترة سماح للفوترة", "Billing grace period")
        case .expired: return tr("اشتراك منتهٍ", "Expired subscription")
        case .billingRetry: return tr("تعذّر تجديد الاشتراك", "Billing retry")
        case .revoked: return tr("اشتراك ملغى أو مسترد", "Revoked or refunded")
        }
    }
}

/// Access is derived only from StoreKit-verified transactions. No local trial clock or paid flag.
final class SubscriptionStore: ObservableObject {
    static let shared = SubscriptionStore()
    static let productID = "com.azstudio.wudcar.premium.monthly"

    @Published private(set) var state: WudCarSubscriptionState = .checking
    @Published private(set) var validUntil: Date?
    @Published private(set) var willAutoRenew: Bool?
    @Published private(set) var product: Product?
    @Published private(set) var eligibleForTrial = false
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    private var updates: Task<Void, Never>?
    private var expirationTimer: Timer?
    private var foreground: AnyCancellable?

    var hasAccess: Bool {
        [.trial, .active, .grace].contains(state) && (validUntil ?? .distantPast) > Date()
    }

    init(observeUpdates: Bool = true) {
        if observeUpdates {
            updates = Task { @MainActor [weak self] in
                for await result in Transaction.updates {
                    guard let self else { return }
                    if case .verified(let transaction) = result,
                       transaction.productID == Self.productID {
                        await transaction.finish()
                        await self.refresh()
                    }
                }
            }
            foreground = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
                .sink { [weak self] _ in Task { @MainActor in await self?.refresh() } }
            Task { @MainActor [weak self] in await self?.refresh() }
        }
    }

    deinit { updates?.cancel(); expirationTimer?.invalidate() }

    @MainActor
    func refresh() async {
        var latest: Transaction?
        if case .verified(let transaction)? = await Transaction.latest(for: Self.productID) {
            latest = transaction
        }
        // This sequence is available offline from StoreKit's signed transaction history.
        var active: Transaction?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.productID,
                  transaction.revocationDate == nil, !transaction.isUpgraded,
                  (transaction.expirationDate ?? .distantPast) > Date() else { continue }
            active = transaction
        }
        willAutoRenew = nil
        validUntil = active?.expirationDate ?? latest?.expirationDate
        if let active {
            state = active.offer?.paymentMode == .freeTrial ? .trial : .active
        } else if latest?.revocationDate != nil { state = .revoked }
        else { state = latest == nil ? .notSubscribed : .expired }

        do {
            if product == nil { product = try await Product.products(for: [Self.productID]).first }
            if let subscription = product?.subscription {
                eligibleForTrial = await subscription.isEligibleForIntroOffer
                let statuses = try await subscription.status
                for status in statuses {
                    guard case .verified(let transaction) = status.transaction,
                          transaction.productID == Self.productID,
                          case .verified(let renewal) = status.renewalInfo else { continue }
                    willAutoRenew = renewal.willAutoRenew
                    if status.state == .inGracePeriod,
                       transaction.revocationDate == nil,
                       let end = renewal.gracePeriodExpirationDate, end > Date() {
                        state = .grace; validUntil = end
                    } else if active == nil && status.state == .inBillingRetryPeriod {
                        state = .billingRetry
                    }
                }
            } else { eligibleForTrial = false }
        } catch {
            // A store/network failure never creates access or destroys a verified unexpired entitlement.
            message = tr("تعذّر تحديث معلومات المتجر. تحقق من الاتصال وحاول مجدداً.",
                         "Store information could not be updated. Check your connection and retry.")
        }
        expirationTimer?.invalidate()
        if hasAccess, let end = validUntil {
            expirationTimer = Timer.scheduledTimer(withTimeInterval: max(0.2, end.timeIntervalSinceNow), repeats: false) { [weak self] _ in
                Task { @MainActor in await self?.refresh() }
            }
        }
        if !hasAccess {
            PlaybackManager.shared.stop()
            WebViewPool.car.pauseAllMedia()
            WebViewPool.phone.pauseAllMedia()
        }
    }

    @MainActor
    func purchase() async {
        guard !busy, let product else { return }
        busy = true; message = nil
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refresh()
            case .success(.unverified):
                message = tr("لم يتم التحقق من عملية الشراء. لم تُفتح المزايا.", "Purchase verification failed. Access was not granted.")
            case .pending:
                message = tr("عملية الشراء بانتظار موافقة أبل.", "The purchase is pending approval.")
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = error.localizedDescription }
    }

    @MainActor
    func restore() async {
        guard !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refresh()
            message = hasAccess ? tr("تمت استعادة الاشتراك.", "Subscription restored.")
                                : tr("لا يوجد اشتراك نشط لهذا الحساب.", "No active subscription was found for this account.")
        } catch { message = error.localizedDescription }
    }
}
