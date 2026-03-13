import Foundation
import CoreGraphics

/// A single object detection returned by the remote YOLO11 server.
struct RemoteDetection: Codable {
    let classId: Int
    let className: String
    let confidence: Float
    /// Bounding box as [x_min, y_min, x_max, y_max] in image pixel coordinates.
    let bboxXyxy: [Float]

    enum CodingKeys: String, CodingKey {
        case classId    = "class_id"
        case className  = "class_name"
        case confidence
        case bboxXyxy   = "bbox_xyxy"
    }

    /// Bounding box as a CGRect in image pixel coordinates.
    var boundingRect: CGRect {
        guard bboxXyxy.count == 4 else { return .zero }
        let x = CGFloat(bboxXyxy[0])
        let y = CGFloat(bboxXyxy[1])
        return CGRect(x: x, y: y,
                      width:  CGFloat(bboxXyxy[2]) - x,
                      height: CGFloat(bboxXyxy[3]) - y)
    }

    /// Centre of the bounding box.
    var centre: CGPoint {
        let r = boundingRect
        return CGPoint(x: r.midX, y: r.midY)
    }
}

/// Top-level response envelope from `/detect`.
struct RemoteDetectionResponse: Codable {
    let detections: [RemoteDetection]
    let count: Int
}
