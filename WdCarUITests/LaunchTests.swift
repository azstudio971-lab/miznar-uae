import XCTest

final class LaunchTests: XCTestCase {
    func testPhoneColdLaunchAndForeground() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20), "Phone tabs must render after launch")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Phone cold launch"
        shot.lifetime = .keepAlways
        add(shot)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "Phone tabs must survive background and foreground")
    }
}
