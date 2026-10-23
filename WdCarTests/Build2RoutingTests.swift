import XCTest
import UIKit
import SwiftUI
import CarPlay
@testable import WdCar

@MainActor
final class Build2RoutingTests: XCTestCase {
    private func scene() throws -> UIWindowScene {
        try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    }
    private func resetConnection() {
        CarExternalDisplaySceneDelegate.returnToTemplates()
        AppState.shared.externalDisplayDisconnected()
        AppState.shared.carDisconnected()
        AppState.shared.showLocationExplanation = false
        AppState.shared.showCarScreenHelp = false
    }
    override func tearDown() {
        resetConnection()
        super.tearDown()
    }
    func testExternalConnectionDoesNotMountLegacyDashboardOrBrowser() throws {
        resetConnection()
        let delegate = CarExternalDisplaySceneDelegate()
        let windowScene = try scene()
        delegate.connect(to: windowScene, interactive: true)
        defer { delegate.sceneDidDisconnect(windowScene) }
        XCTAssertNil(delegate.window, "A media connection must not cover the official CarPlay template UI")
        XCTAssertTrue(AppState.shared.isCarConnected)
        XCTAssertFalse(AppState.shared.carScreenActive)
        XCTAssertFalse(AppState.shared.showLocationExplanation, "Connection alone must not open a permission explanation")
        XCTAssertFalse(AppState.shared.showCarScreenHelp)
        XCTAssertEqual(AppState.shared.carStatusText, tr("متصل", "Connected"))
        XCTAssertEqual(AppState.shared.toast, tr("تم الاتصال", "Connected"))
    }
    func testBrowserIsExplicitAndReturningKeepsMediaConnection() throws {
        resetConnection()
        let delegate = CarExternalDisplaySceneDelegate()
        let windowScene = try scene()
        delegate.connect(to: windowScene, interactive: true)
        defer { delegate.sceneDidDisconnect(windowScene) }
        XCTAssertTrue(CarExternalDisplaySceneDelegate.presentBrowserIfConnected())
        XCTAssertTrue(delegate.window?.rootViewController is CarBrowserViewController)
        XCTAssertTrue(AppState.shared.carScreenActive)
        CarExternalDisplaySceneDelegate.returnToTemplates()
        XCTAssertNil(delegate.window)
        XCTAssertFalse(AppState.shared.carScreenActive)
        XCTAssertTrue(AppState.shared.isCarConnected)
        XCTAssertEqual(AppState.shared.carStatusText, tr("متصل", "Connected"))
    }
    func testPhonePreferenceCannotUnlockMovingCarVideo() {
        for preference in [false, true] {
            XCTAssertTrue(PlaybackManager.blocksVideo(isMoving: true, carConnected: true, phonePreference: preference))
            XCTAssertFalse(PlaybackManager.blocksVideo(isMoving: false, carConnected: true, phonePreference: preference))
        }
        XCTAssertFalse(PlaybackManager.blocksVideo(isMoving: true, carConnected: false, phonePreference: false))
        XCTAssertTrue(PlaybackManager.blocksVideo(isMoving: true, carConnected: false, phonePreference: true))
    }
    func testNativeTabOrderAndNoImplicitPlayback() {
        let library = CPListTemplate(title: "library", sections: [])
        let tv = CPListTemplate(title: "tv", sections: [])
        let favorites = CPListTemplate(title: "favorites", sections: [])
        let settings = CPListTemplate(title: "settings", sections: [])
        let tabs = CarTemplateUI.makeTabBar(library: library, tv: tv, favorites: favorites, settings: settings)
        XCTAssertEqual(tabs.templates.count, 4)
        for (actual, expected) in zip(tabs.templates, [library, tv, favorites, settings]) { XCTAssertTrue(actual === expected) }
        XCTAssertFalse(CarScreenLauncher.shared.isLaunching)
    }
    func testCastWithoutMediaDoesNotLaunchBrowserOrBootstrapVideo() {
        PlaybackManager.shared.stop()
        XCTAssertFalse(PlaybackManager.shared.castCurrentMedia())
        XCTAssertNil(PlaybackManager.shared.current)
        XCTAssertFalse(CarScreenLauncher.shared.isLaunching)
        XCTAssertNotNil(PlaybackManager.shared.errorMessage)
        PlaybackManager.shared.stop()
    }
    func testConnectedCardAndCastNativeSnapshots() async throws {
        resetConnection()
        AppState.shared.carConnected(mode: .templates)
        let windowScene = try scene()
        for (name, view) in [("302-connection-card", AnyView(CarConnectionCard().padding())), ("302-cast", AnyView(CastView()))] {
            let host = UIHostingController(rootView: view.environmentObject(AppState.shared))
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer { window.isHidden = true; window.rootViewController = nil }
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(400))
            let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
                host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
    }
}
