import UIKit
import RealityKit

/// Sends a cropped snapshot to the local YOLO11 inference server and returns
/// the best-matching detection as a `(label, confidence)` pair.
///
/// Server API (from ios-connection.md):
///   POST  http://<host>/detect   multipart/form-data, field "file", JPEG
///   Response: { "detections": [...], "count": N }
final class RemoteInferenceService {

    static let shared = RemoteInferenceService()
    private init() {}

    // MARK: - Public

    enum InferenceError: Error {
        case snapshotFailed
        case noDetections
        case networkError(Error)
        case badResponse(Int)
        case decodingError(Error)
    }

    /// Renders a snapshot of `view`, crops to `circleRect`, and POSTs to the
    /// YOLO11 `/detect` endpoint. Calls `completion` on the main thread.
    ///
    /// - Parameters:
    ///   - view:       The ARView to snapshot (already in screen orientation).
    ///   - circleRect: Circle bounding rect in view coordinates.
    ///   - completion: `(label, confidence)` on success; `("Error", 0)` on failure.
    func detect(
        in view: ARView,
        circleRect: CGRect,
        completion: @escaping (String, Float) -> Void
    ) {
        // Render view to image (synchronous, on main thread)
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        let snapshot = renderer.image { ctx in
            view.layer.render(in: ctx.cgContext)
        }

        // Crop to the circle's bounding rect
        guard let cgFull = snapshot.cgImage,
              let cgCrop = cgFull.cropping(to: circleRect),
              let jpegData = UIImage(cgImage: cgCrop).jpegData(compressionQuality: 0.85) else {
            DispatchQueue.main.async { completion("Error", 0) }
            return
        }

        post(jpegData: jpegData) { result in
            switch result {
            case .success(let response):
                guard let best = response.detections
                    .max(by: { $0.confidence < $1.confidence }) else {
                    DispatchQueue.main.async { completion("No objects", 0) }
                    return
                }
                DispatchQueue.main.async { completion(best.className, best.confidence) }

            case .failure:
                DispatchQueue.main.async { completion("Server error", 0) }
            }
        }
    }

    // MARK: - Private

    private func post(
        jpegData: Data,
        completion: @escaping (Result<RemoteDetectionResponse, InferenceError>) -> Void
    ) {
        let serverURL = SettingsManager.shared.remoteServerURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: serverURL + "/detect") else {
            completion(.failure(.networkError(URLError(.badURL))))
            return
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")

        var body = Data()
        let crlf = "\r\n"
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"frame.jpg\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(jpegData)
        body.append("\(crlf)--\(boundary)--\(crlf)".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(.networkError(error)))
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                completion(.failure(.badResponse(http.statusCode)))
                return
            }
            guard let data else {
                completion(.failure(.noDetections))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(RemoteDetectionResponse.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }.resume()
    }
}
