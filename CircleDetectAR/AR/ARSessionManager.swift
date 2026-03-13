import ARKit
import RealityKit

/// Configures and manages the ARKit session for world-tracking with LiDAR support.
final class ARSessionManager {

    private let arView: ARView

    init(arView: ARView) {
        self.arView = arView
    }

    func start() {
        arView.session.run(makeConfiguration(), options: [.resetTracking, .removeExistingAnchors])
    }

    func pause() {
        arView.session.pause()
    }

    // MARK: - Private

    private func makeConfiguration() -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
        }

        var semantics: ARConfiguration.FrameSemantics = []
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            semantics.insert(.sceneDepth)
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            semantics.insert(.smoothedSceneDepth)
        }
        if !semantics.isEmpty {
            config.frameSemantics = semantics
        }

        selectHighResFormat(for: config)
        return config
    }

    private func selectHighResFormat(for config: ARWorldTrackingConfiguration) {
        let formats = ARWorldTrackingConfiguration.supportedVideoFormats
        if let hiRes = formats.first(where: { $0.imageResolution.width >= 1920 }) {
            config.videoFormat = hiRes
        }
    }
}
