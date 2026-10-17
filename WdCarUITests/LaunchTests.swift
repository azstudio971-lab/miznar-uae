import XCTest

final class LaunchTests: XCTestCase {
    func test01PhoneColdLaunchAndForeground() {
        continueAfterFailure = false
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        print("PHONE: launch")
        app.launch()
        print("PHONE: launched")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20), "Phone tabs must render after launch")
        let visible = NSPredicate(format: "hittable == true")
        expectation(for: visible, evaluatedWith: app.tabBars.buttons.element(boundBy: 0))
        waitForExpectations(timeout: 15)
        print("PHONE: first tab is hittable")
        XCTAssertEqual(app.tabBars.buttons.count, 4)
        for index in 0..<4 {
            let button = app.tabBars.buttons.element(boundBy: index)
            XCTAssertTrue(button.isHittable)
            button.tap()
            XCTAssertTrue(button.isSelected)
        }
        app.tabBars.buttons.element(boundBy: 0).tap()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Phone cold launch"
        shot.lifetime = .keepAlways
        add(shot)
        print("PHONE: background")
        XCUIDevice.shared.press(.home)
        print("PHONE: foreground")
        app.activate()
        print("PHONE: foreground complete")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "Phone tabs must survive background and foreground")
    }
}
