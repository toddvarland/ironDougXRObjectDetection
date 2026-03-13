import ARKit
import RealityKit
import UIKit

/// Creates floating AR text labels anchored to real-world surfaces via raycasting,
/// with a 2D HUD label fallback when no surface is detected.
final class LabelAnchorManager {

    private var activeAnchors: [AnchorEntity] = []
    private let displayDuration: TimeInterval = 4.0

    /// Places a label at the given screen point. Dispatches to main automatically.
    func placeLabel(_ text: String, at screenPoint: CGPoint, in arView: ARView) {
        DispatchQueue.main.async { [weak self] in
            self?.placeLabelOnMain(text, at: screenPoint, in: arView)
        }
    }

    func removeAllLabels(from arView: ARView) {
        activeAnchors.forEach { $0.removeFromParent() }
        activeAnchors.removeAll()
    }

    // MARK: - Private

    private func placeLabelOnMain(_ text: String, at screenPoint: CGPoint, in arView: ARView) {
        let results = arView.raycast(from: screenPoint,
                                     allowing: .estimatedPlane,
                                     alignment: .any)
        if let hit = results.first {
            place3DLabel(text, transform: hit.worldTransform, in: arView)
        } else {
            show2DLabel(text, at: screenPoint, in: arView)
        }
    }

    private func place3DLabel(_ text: String, transform: simd_float4x4, in arView: ARView) {
        let textMesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.04),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        let material = SimpleMaterial(color: .white, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [material])
        if #available(iOS 18.0, *) {
            textEntity.components[BillboardComponent.self] = BillboardComponent()
        }

        let anchor = AnchorEntity(world: transform)
        anchor.addChild(textEntity)
        arView.scene.addAnchor(anchor)
        activeAnchors.append(anchor)

        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) { [weak self] in
            anchor.removeFromParent()
            self?.activeAnchors.removeAll { $0 === anchor }
        }
    }

    private func show2DLabel(_ text: String, at point: CGPoint, in arView: ARView) {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.font = .boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        label.sizeToFit()
        // Expand frame to add visual padding
        label.frame = label.frame.insetBy(dx: -10, dy: -6)
        label.center = point
        arView.addSubview(label)

        UIView.animate(withDuration: 0.3, delay: displayDuration, options: .curveEaseOut) {
            label.alpha = 0
        } completion: { _ in
            label.removeFromSuperview()
        }
    }
}
