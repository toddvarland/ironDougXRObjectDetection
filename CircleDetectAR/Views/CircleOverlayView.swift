import UIKit

/// Transparent overlay view that draws the live circle stroke as the user's finger moves.
final class CircleOverlayView: UIView {

    /// Set this to update the drawn path. Setting to `nil` clears the overlay.
    var path: UIBezierPath? {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    override func draw(_ rect: CGRect) {
        guard let path else { return }
        UIColor.systemYellow.withAlphaComponent(0.85).setStroke()
        path.lineWidth = 3
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }
}
