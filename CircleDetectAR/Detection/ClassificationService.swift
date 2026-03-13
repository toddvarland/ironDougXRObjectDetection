import CoreVideo
import Vision
import CoreML

/// Runs object classification or detection on a cropped region of an ARFrame pixel buffer.
final class ClassificationService {

    typealias ClassificationCompletion = (_ label: String, _ confidence: Float) -> Void

    private lazy var visionModel: VNCoreMLModel? = ModelService.shared.visionModel

    /// Classify the region of `pixelBuffer` described by `regionOfInterest` (normalised Vision coords).
    /// The completion is always called on the **main thread**.
    func classify(pixelBuffer: CVPixelBuffer,
                  regionOfInterest: CGRect,
                  completion: @escaping ClassificationCompletion) {
        guard let model = visionModel else {
            // Model not yet added — return a placeholder so the UI still responds.
            DispatchQueue.main.async { completion("Add model →", 0) }
            return
        }

        let request = VNCoreMLRequest(model: model) { request, error in
            if let error {
                print("ClassificationService error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion("Error", 0) }
                return
            }
            if let results = request.results as? [VNClassificationObservation],
               let top = results.first {
                DispatchQueue.main.async { completion(top.identifier, top.confidence) }
            } else if let results = request.results as? [VNRecognizedObjectObservation],
                      let top = results.first,
                      let label = top.labels.first {
                DispatchQueue.main.async { completion(label.identifier, label.confidence) }
            } else {
                DispatchQueue.main.async { completion("Unknown", 0) }
            }
        }
        request.regionOfInterest = regionOfInterest
        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                             orientation: .right,
                                             options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("VNImageRequestHandler error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion("Error", 0) }
            }
        }
    }
}
