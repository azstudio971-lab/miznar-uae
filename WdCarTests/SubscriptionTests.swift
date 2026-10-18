import XCTest
import StoreKit
import StoreKitTest
import SwiftUI
import UIKit
@testable import WdCar

@MainActor
final class SubscriptionTests: XCTestCase {
    private func waitFor(_ store: SubscriptionStore, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(15)
        repeat {
            await store.refresh()
            if condition() { return }
            try await Task.sleep(for: .milliseconds(300))
        } while Date() < deadline
    }

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
        await SubscriptionStore.shared.refresh()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = UIHostingController(rootView: NavigationStack { SubscriptionView() }
            .environment(\.colorScheme, .light).environment(\.layoutDirection, .rightToLeft))
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(700))
        let renderer = UIGraphicsImageRenderer(size: window.bounds.size)
        let image = renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: image)
        attachment.name = "update14-subscription-actual-iphone"
        attachment.lifetime = .keepAlways
        add(attachment)
        window.isHidden = true
        window.rootViewController = nil
        await store.purchase()
        XCTAssertTrue(store.hasAccess)
        XCTAssertEqual(store.state, .trial)
        XCTAssertNotNil(store.validUntil)
        let trialTransaction = try XCTUnwrap(session.allTransactions().last)
        try session.disableAutoRenewForTransaction(identifier: trialTransaction.identifier)
        try await waitFor(store) { store.willAutoRenew == false }
        XCTAssertEqual(store.willAutoRenew, false)
        XCTAssertTrue(store.hasAccess, "Cancellation retains access to the paid/trial expiration date")
        let restored = SubscriptionStore(observeUpdates: false)
        await restored.restore()
        XCTAssertTrue(restored.hasAccess)
        try session.expireSubscription(productIdentifier: SubscriptionStore.productID)
        try await waitFor(store) { store.state == .expired && !store.hasAccess }
        XCTAssertFalse(store.hasAccess)
        XCTAssertEqual(store.state, .expired)
        await store.purchase()
        try await waitFor(store) { store.hasAccess && store.state == .active }
        XCTAssertTrue(store.hasAccess)
        XCTAssertEqual(store.state, .active, "A returning subscriber does not get another introductory trial")
        try session.forceRenewalOfSubscription(productIdentifier: SubscriptionStore.productID)
        try await waitFor(store) { store.hasAccess && store.state == .active }
        XCTAssertEqual(store.state, .active)
        let transactions = session.allTransactions().filter { $0.productIdentifier == SubscriptionStore.productID }
        let last = try XCTUnwrap(transactions.last)
        try session.refundTransaction(identifier: last.identifier)
        try await waitFor(store) { !store.hasAccess && store.state == .revoked }
        XCTAssertFalse(store.hasAccess)
        XCTAssertEqual(store.state, .revoked)
    }
}
