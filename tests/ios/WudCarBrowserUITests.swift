import XCTest

final class WudCarBrowserUITests: XCTestCase {
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--browser-ui-tests"] + extra
        app.launch()
        app.tabBars.buttons[extra.contains("--arabic") ? "الترفيه" : "Entertainment"].tap()
        app.buttons["entertainment.browser"].tap()
        XCTAssertTrue(app.buttons["browser.tabs"].waitForExistence(timeout: 10))
        return app
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testStartersAndTabLimit() {
        let app = launch()
        XCTAssertTrue(app.buttons["browser.site.wudcar-youtube"].exists)
        XCTAssertTrue(app.buttons["browser.site.wudcar-tiktok"].exists)
        XCTAssertFalse(app.buttons["browser.site.wudcar-shahid"].exists)
        screenshot("browser-dark-english")
        for _ in 1..<8 {
            app.buttons["browser.tabs"].tap()
            app.buttons["tabs.add"].tap()
        }
        app.buttons["browser.tabs"].tap()
        XCTAssertFalse(app.buttons["tabs.add"].isEnabled)
        screenshot("eight-tabs")
        app.buttons.matching(identifier: "tabs.close").firstMatch.tap()
        XCTAssertTrue(app.buttons["tabs.add"].isEnabled)
        app.buttons["tabs.done"].tap()
        app.buttons["browser.close"].tap()
        app.buttons["entertainment.browser"].tap()
        XCTAssertEqual(app.buttons["browser.tabs"].value as? String, "7")
    }

    func testRejectUnsafeAddressAndSaveShortcut() {
        let app = launch()
        let field = app.textFields["browser.address"]
        field.tap()
        field.typeText("javascript:alert(1)")
        app.buttons["browser.go"].tap()
        XCTAssertTrue(app.staticTexts["browser.error"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["browser.site.wudcar-youtube"].exists)
        app.buttons["browser.addShortcut"].tap()
        app.textFields["shortcut.name"].tap()
        app.textFields["shortcut.name"].typeText("Example")
        app.textFields["shortcut.url"].tap()
        app.textFields["shortcut.url"].typeText("example.com")
        app.buttons["shortcut.save"].tap()
        XCTAssertTrue(app.buttons["Example"].waitForExistence(timeout: 3))
    }

    func testWebNavigationPopupAndHome() {
        let app = launch(["--browser-fixture"])
        XCTAssertTrue(app.webViews.staticTexts["First page"].waitForExistence(timeout: 10))
        app.webViews.links["Next page"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Second page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["browser.back"].isEnabled)
        app.buttons["browser.back"].tap()
        XCTAssertTrue(app.webViews.staticTexts["First page"].waitForExistence(timeout: 5))
        app.webViews.links["Open new tab"].tap()
        XCTAssertEqual(app.buttons["browser.tabs"].value as? String, "2")
        XCTAssertTrue(app.webViews.staticTexts["Second page"].waitForExistence(timeout: 5))
        app.buttons["browser.home"].tap()
        XCTAssertTrue(app.buttons["browser.site.wudcar-youtube"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["browser.reload"].isEnabled)
    }

    func testArabicLightLayout() {
        let app = launch(["--arabic", "--light"])
        XCTAssertTrue(app.buttons["browser.site.wudcar-tiktok"].exists)
        screenshot("browser-light-arabic")
        app.buttons["browser.menu"].tap()
        XCTAssertTrue(app.buttons["طلب موقع سطح المكتب"].waitForExistence(timeout: 3))
        screenshot("browser-arabic-menu")
    }
}
