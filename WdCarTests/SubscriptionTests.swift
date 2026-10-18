import XCTest
import StoreKit
import StoreKitTest
@testable import WdCar

@MainActor
final class SubscriptionTests: XCTestCase {
    func testOfficialStoreKitTrialRenewalCancellationExpiryRestoreAndRefund() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "WudCar", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.clearTransactions()
        let store = SubscriptionStore(observeUpdates: false)
        await store.refresh()
        XCTAssertFalse(store.hasAccess)
        let product = try XCTUnwrap(store.product)
        XCTAssertEqual(product.price, 24)
        XCTAssertEqual(product.subscription?.subscriptionPeriod.unit, .month)
        XCTAssertEqual(product.subscription?.introductoryOffer?.paymentMode, .freeTrial)
        XCTAssertEqual(product.subscription?.introductoryOffer?.period.value, 3)
        XCTAssertTrue(store.eligibleForTrial)
        await store.purchase()
        XCTAssertTrue(store.hasAccess)
        XCTAssertEqual(store.state, .trial)
        XCTAssertNotNil(store.validUntil)
        let trialTransaction = try XCTUnwrap(session.allTransactions().last)
        try session.disableAutoRenewForTransaction(identifier: trialTransaction.identifier)
        await store.refresh()
        XCTAssertEqual(store.willAutoRenew, false)
        XCTAssertTrue(store.hasAccess, "Cancellation retains access to the paid/trial expiration date")
        let restored = SubscriptionStore(observeUpdates: false)
        await restored.restore()
        XCTAssertTrue(restored.hasAccess)
        try session.expireSubscription(productIdentifier: SubscriptionStore.productID)
        await store.refresh()
        XCTAssertFalse(store.hasAccess)
        XCTAssertEqual(store.state, .expired)
        _ = try await session.buyProduct(identifier: SubscriptionStore.productID)
        await store.refresh()
        XCTAssertTrue(store.hasAccess)
        XCTAssertEqual(store.state, .active, "A returning subscriber does not get another introductory trial")
        try session.forceRenewalOfSubscription(productIdentifier: SubscriptionStore.productID)
        await store.refresh()
        XCTAssertEqual(store.state, .active)
        let transactions = session.allTransactions().filter { $0.productIdentifier == SubscriptionStore.productID }
        let last = try XCTUnwrap(transactions.last)
        try session.refundTransaction(identifier: last.identifier)
        await store.refresh()
        XCTAssertFalse(store.hasAccess)
        XCTAssertEqual(store.state, .revoked)
    }
}
