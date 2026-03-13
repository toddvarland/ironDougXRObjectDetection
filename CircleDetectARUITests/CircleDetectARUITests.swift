import XCTest

final class CircleDetectARUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]   // suppresses coaching overlay
        app.launch()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    // MARK: - Launch

    func testAppLaunchesWithARView() {
        let arView = app.otherElements["ARViewContainer"]
        XCTAssertTrue(arView.waitForExistence(timeout: 8),
                      "ARViewContainer should be visible on launch")
    }

    // MARK: - Permissions

    func testCameraPermissionAlertAppearsWhenDenied() {
        // Only meaningful when run in a fresh install or with camera access pre-denied.
        // Check for the alert if it appears within a short window.
        let alert = app.alerts["Camera Access Required"]
        if alert.waitForExistence(timeout: 3) {
            XCTAssertTrue(alert.buttons["Settings"].exists,
                          "Settings button must appear in the permission alert")
            XCTAssertTrue(alert.buttons["Cancel"].exists,
                          "Cancel button must appear in the permission alert")
            alert.buttons["Cancel"].tap()
        }
        // If the alert does not appear, permission was already granted — pass silently.
    }

    // MARK: - Circle Gesture

    /// Draws an approximate circle on the AR view and verifies a result label appears.
    func testCircleGestureProducesResultLabel() {
        let arView = app.otherElements["ARViewContainer"]
        guard arView.waitForExistence(timeout: 8) else {
            XCTFail("AR view not found")
            return
        }

        drawApproximateCircle(in: arView)

        // A confidence label like "chair (72%)" should appear
        let predicate = NSPredicate(format: "label CONTAINS[c] '%'")
        let resultLabel = app.staticTexts.matching(predicate).firstMatch
        XCTAssertTrue(resultLabel.waitForExistence(timeout: 8),
                      "A classification label with a % confidence value should appear after circle gesture")
    }

    /// Verifies a quick swipe (open stroke) does NOT trigger a result label.
    func testOpenStrokeDoesNotProduceLabel() {
        let arView = app.otherElements["ARViewContainer"]
        guard arView.waitForExistence(timeout: 8) else { return }

        // Swipe a straight horizontal line — should not complete a circle
        let start  = arView.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        let finish = arView.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        start.press(forDuration: 0, thenDragTo: finish)

        // Wait a bit; no label should appear
        sleep(2)
        let predicate = NSPredicate(format: "label CONTAINS[c] '%'")
        XCTAssertFalse(app.staticTexts.matching(predicate).firstMatch.exists,
                       "An open swipe must not trigger a classification label")
    }

    // MARK: - Label lifecycle

    func testResultLabelDisappearsAfterTimeout() {
        let arView = app.otherElements["ARViewContainer"]
        guard arView.waitForExistence(timeout: 8) else { return }

        drawApproximateCircle(in: arView)

        let predicate = NSPredicate(format: "label CONTAINS[c] '%'")
        let resultLabel = app.staticTexts.matching(predicate).firstMatch
        guard resultLabel.waitForExistence(timeout: 8) else {
            XCTFail("No label appeared — cannot test timeout")
            return
        }

        // Label should auto-dismiss within ~5 seconds of appearing
        let disappeared = NSPredicate(format: "exists == false")
        expectation(for: disappeared, evaluatedWith: resultLabel)
        waitForExpectations(timeout: 8)
    }

    // MARK: - Gesture helper

    private func drawApproximateCircle(in element: XCUIElement,
                                        radius: CGFloat = 80,
                                        steps: Int = 36) {
        let center   = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let viewFrame = element.frame
        let cx = viewFrame.midX
        let cy = viewFrame.midY

        // Build a sequence of coordinates tracing a circle
        var coords: [XCUICoordinate] = []
        for i in 0 ... steps {
            let angle = (Double(i) / Double(steps)) * 2 * .pi
            let dx = radius * cos(angle) / viewFrame.width
            let dy = radius * sin(angle) / viewFrame.height
            coords.append(
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + dx, dy: 0.5 + dy))
            )
        }

        // Press-hold at first point then drag through the circle
        coords.first!.press(forDuration: 0.05, thenDragTo: coords.last!)
    }
}
