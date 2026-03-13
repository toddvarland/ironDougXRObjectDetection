import XCTest
import CoreVideo
@testable import CircleDetectAR

final class CircleGestureRecognizerTests: XCTestCase {

    // MARK: - Helpers

    /// Generate evenly-spaced points around a circle.
    private func circlePoints(center: CGPoint = CGPoint(x: 200, y: 200),
                               radius: CGFloat = 80,
                               steps: Int = 42) -> [CGPoint] {
        (0 ... steps).map { i in
            let angle = (CGFloat(i) / CGFloat(steps)) * 2 * .pi
            return CGPoint(x: center.x + radius * cos(angle),
                           y: center.y + radius * sin(angle))
        }
    }

    // MARK: - Closed-circle detection

    func testClosedCircleIsDetected() {
        let r = CircleGestureRecognizer()
        r.injectTouchPoints(circlePoints())
        XCTAssertTrue(r.testIsClosedCircle(),
                      "A complete circular path should be recognised as closed")
    }

    func testStraightLineIsNotCircle() {
        let r = CircleGestureRecognizer()
        let points = (0 ... 30).map { CGPoint(x: CGFloat($0) * 10, y: 100) }
        r.injectTouchPoints(points)
        XCTAssertFalse(r.testIsClosedCircle(), "A straight line must not register as a circle")
    }

    func testOpenArcIsNotCircle() {
        let r = CircleGestureRecognizer()
        // Three-quarter arc — does not close
        let points: [CGPoint] = (0 ... 30).map { i in
            let angle = (CGFloat(i) / 30) * 1.5 * .pi
            return CGPoint(x: 200 + 80 * cos(angle),
                           y: 200 + 80 * sin(angle))
        }
        r.injectTouchPoints(points)
        XCTAssertFalse(r.testIsClosedCircle(), "An open arc must not register as a circle")
    }

    func testTooFewPointsIsNotCircle() {
        let r = CircleGestureRecognizer()
        r.injectTouchPoints(circlePoints(steps: 10))   // only 11 points
        XCTAssertFalse(r.testIsClosedCircle(), "Too few points should fail the circle check")
    }

    func testVerySmallCircleIsNotCircle() {
        let r = CircleGestureRecognizer()
        // Radius of 5 pts → circumference ~31 pts, well below the 80 pt minimum
        r.injectTouchPoints(circlePoints(radius: 5))
        XCTAssertFalse(r.testIsClosedCircle(), "A circle too small to meet path-length threshold should fail")
    }

    // MARK: - Bounding rect

    func testBoundingRectCorners() {
        let r = CircleGestureRecognizer()
        let points = [CGPoint(x: 50, y: 100),
                      CGPoint(x: 150, y: 100),
                      CGPoint(x: 150, y: 220),
                      CGPoint(x: 50, y: 220),
                      CGPoint(x: 50, y: 100)]
        r.injectTouchPoints(points)
        let rect = r.testComputeBoundingRect()
        XCTAssertEqual(rect.minX, 50)
        XCTAssertEqual(rect.minY, 100)
        XCTAssertEqual(rect.width,  100, accuracy: 0.5)
        XCTAssertEqual(rect.height, 120, accuracy: 0.5)
    }

    func testBoundingRectEmptyPoints() {
        let r = CircleGestureRecognizer()
        r.injectTouchPoints([])
        XCTAssertEqual(r.testComputeBoundingRect(), .zero,
                       "Empty touch points should yield CGRect.zero")
    }
}
