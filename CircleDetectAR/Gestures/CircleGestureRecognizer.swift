import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Recognizes a single-finger closed-loop circle gesture.
/// The gesture succeeds (`.ended`) only when the drawn path forms an approximate circle —
/// meaning the stroke closes back near its starting point and has sufficient length.
/// It fails (`.failed`) for open strokes or lines.
final class CircleGestureRecognizer: UIGestureRecognizer {

    // MARK: - Public read-only state

    /// The live bezier path of the stroke, updated during `.changed`.
    private(set) var circlePath = UIBezierPath()

    /// The bounding rect of the completed circle in the gesture's view coordinate space.
    private(set) var boundingRect: CGRect = .zero

    // MARK: - Private

    private var touchPoints: [CGPoint] = []

    // MARK: - UIGestureRecognizer overrides

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard touches.count == 1, let touch = touches.first else {
            state = .failed
            return
        }
        touchPoints = [touch.location(in: view)]
        circlePath = UIBezierPath()
        circlePath.move(to: touchPoints[0])
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        let point = touch.location(in: view)
        touchPoints.append(point)
        circlePath.addLine(to: point)
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        if isClosedCircle() {
            boundingRect = computeBoundingRect()
            state = .ended
        } else {
            state = .failed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        state = .cancelled
    }

    override func reset() {
        super.reset()
        touchPoints = []
        circlePath = UIBezierPath()
        boundingRect = .zero
    }

    // MARK: - Circle Detection

    /// Returns `true` when the accumulated stroke qualifies as a closed circle.
    func isClosedCircle() -> Bool {
        guard touchPoints.count > 20,
              let first = touchPoints.first,
              let last  = touchPoints.last else { return false }

        let totalLength    = pathLength()
        guard totalLength > 80 else { return false }

        let estimatedRadius  = totalLength / (2 * .pi)
        let closingDistance  = hypot(first.x - last.x, first.y - last.y)

        return closingDistance < estimatedRadius * 0.4
    }

    private func pathLength() -> CGFloat {
        var length: CGFloat = 0
        for i in 1 ..< touchPoints.count {
            let dx = touchPoints[i].x - touchPoints[i - 1].x
            let dy = touchPoints[i].y - touchPoints[i - 1].y
            length += hypot(dx, dy)
        }
        return length
    }

    func computeBoundingRect() -> CGRect {
        guard !touchPoints.isEmpty else { return .zero }
        let xs = touchPoints.map(\.x)
        let ys = touchPoints.map(\.y)
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

// MARK: - Debug / Test Helpers

#if DEBUG
extension CircleGestureRecognizer {
    func injectTouchPoints(_ points: [CGPoint]) {
        touchPoints = points
    }

    func testIsClosedCircle() -> Bool {
        isClosedCircle()
    }

    func testComputeBoundingRect() -> CGRect {
        computeBoundingRect()
    }
}
#endif
