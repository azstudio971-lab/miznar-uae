import XCTest

final class LaunchTests: XCTestCase {
    func test01PhoneColdLaunchAndForeground() {
        continueAfterFailure = false
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20), "Phone tabs must render after launch")
        let visible = NSPredicate(format: "hittable == true")
        expectation(for: visible, evaluatedWith: app.tabBars.firstMatch)
        waitForExpectations(timeout: 15)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Phone cold launch"
        shot.lifetime = .keepAlways
        add(shot)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "Phone tabs must survive background and foreground")
    }
    func test02CarWelcomeBrowserAndSettings() {
        continueAfterFailure = false
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launchArguments = ["--car-ui-preview"]
        app.launch()
        XCTAssertTrue(app.staticTexts["car.welcome"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["car.address"].exists, "Browser must not open at startup")
        app.buttons["car.entertainment"].tap()
        XCTAssertTrue(app.buttons["car.address"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["car.menu"].isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["shortcut.YouTube"].firstMatch.exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Compact car browser"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["car.menu"].tap()
        app.buttons["car.settings"].tap()
        XCTAssertTrue(app.segmentedControls["car.browserMode"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["car.browserMode"].buttons.element(boundBy: 0).isSelected, "Desktop must be the default")
        app.buttons["car.menu"].tap()
        app.buttons["car.xtream"].tap()
        XCTAssertTrue(app.navigationBars["Xtream Codes"].waitForExistence(timeout: 5))
    }
}
