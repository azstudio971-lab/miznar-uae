import XCTest

final class WudCarBrowserUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func tapWebLink(_ title: String, in app: XCUIApplication) {
        let link = app.webViews.links[title]
        XCTAssertTrue(link.waitForExistence(timeout: 15))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: link)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        // WebKit's synthesized activation point can lag the first layout. Use
        // the link's current frame, not that stale activation point (CI tapped
        // x:24,y:186 while the link was at x:52,y:272).
        link.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
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
        tapWebLink("Next page", in: app)
        XCTAssertTrue(app.webViews.staticTexts["Second page"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["browser.back"].isEnabled)
        app.buttons["browser.back"].tap()
        XCTAssertTrue(app.webViews.staticTexts["First page"].waitForExistence(timeout: 5))
        tapWebLink("Open new tab", in: app)
        XCTAssertTrue(app.webViews.staticTexts["Second page"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["browser.tabs"].value as? String, "2")
        screenshot("browser-webkit-navigation")
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
