import CoreML
import Vision

/// Shared singleton that loads the Core ML model once and reuses it across the app.
final class ModelService {

    static let shared = ModelService()
    private init() {}

    /// The Vision-wrapped Core ML model. Returns `nil` if the model file has not been
    /// added to the Xcode project yet. See `CircleDetectAR/Models/README.md`.
    lazy var visionModel: VNCoreMLModel? = {
        // Look for a compiled model first (.mlmodelc), then fall back to .mlmodel
        guard let modelURL = Bundle.main.url(forResource: "MobileNetV2", withExtension: "mlmodelc")
                          ?? Bundle.main.url(forResource: "MobileNetV2", withExtension: "mlmodel") else {
            print("⚠️  MobileNetV2.mlmodel not found. See CircleDetectAR/Models/README.md.")
            return nil
        }
        guard let compiledModel = try? MLModel(contentsOf: modelURL),
              let visionModel   = try? VNCoreMLModel(for: compiledModel) else {
            return nil
        }
        return visionModel
    }()
}
