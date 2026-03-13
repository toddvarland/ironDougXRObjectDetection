import ARKit
import RealityKit

#if DEBUG

/// Manages the ARView debug visualization overlays.
/// Only compiled in DEBUG builds. Access via the triple-tap gesture in ARViewController.
final class DebugOverlayManager {

    enum State: CaseIterable {
        case off
        case featurePoints
        case sceneUnderstanding
        case all

        var label: String {
            switch self {
            case .off:                 return "Debug: Off"
            case .featurePoints:       return "Debug: Feature Points"
            case .sceneUnderstanding:  return "Debug: Scene Mesh"
            case .all:                 return "Debug: All"
            }
        }

        var debugOptions: ARView.DebugOptions {
            switch self {
            case .off:                 return []
            case .featurePoints:       return [.showFeaturePoints]
            case .sceneUnderstanding:  return [.showSceneUnderstanding]
            case .all:                 return [.showFeaturePoints, .showSceneUnderstanding, .showWorldOrigin]
            }
        }
    }

    private var currentIndex = 0
    private let arView: ARView

    init(arView: ARView) {
        self.arView = arView
    }

    /// Cycles to the next debug state and applies it.
    @discardableResult
    func cycleState() -> State {
        currentIndex = (currentIndex + 1) % State.allCases.count
        let state = State.allCases[currentIndex]
        arView.debugOptions = state.debugOptions
        return state
    }

    var currentState: State { State.allCases[currentIndex] }
}

#endif
