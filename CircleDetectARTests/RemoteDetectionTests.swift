import XCTest
@testable import CircleDetectAR

final class RemoteDetectionTests: XCTestCase {

    // MARK: - JSON Decoding

    func testDecodesFullResponse() throws {
        let json = """
        {
            "detections": [
                {
                    "class_id": 0,
                    "class_name": "person",
                    "confidence": 0.9147,
                    "bbox_xyxy": [50.01, 401.54, 247.36, 903.75]
                },
                {
                    "class_id": 2,
                    "class_name": "car",
                    "confidence": 0.6312,
                    "bbox_xyxy": [10.0, 20.0, 110.0, 80.0]
                }
            ],
            "count": 2
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(RemoteDetectionResponse.self, from: json)
        XCTAssertEqual(response.count, 2)
        XCTAssertEqual(response.detections.count, 2)

        let first = response.detections[0]
        XCTAssertEqual(first.className, "person")
        XCTAssertEqual(first.classId, 0)
        XCTAssertEqual(first.confidence, 0.9147, accuracy: 0.0001)
        XCTAssertEqual(first.bboxXyxy.count, 4)
    }

    func testDecodesEmptyDetections() throws {
        let json = """
        { "detections": [], "count": 0 }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(RemoteDetectionResponse.self, from: json)
        XCTAssertTrue(response.detections.isEmpty)
        XCTAssertEqual(response.count, 0)
    }

    // MARK: - boundingRect helper

    func testBoundingRectComputed() throws {
        let json = """
        {
            "detections": [{
                "class_id": 1,
                "class_name": "dog",
                "confidence": 0.75,
                "bbox_xyxy": [10.0, 20.0, 110.0, 80.0]
            }],
            "count": 1
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(RemoteDetectionResponse.self, from: json)
        let det = response.detections[0]
        let rect = det.boundingRect

        XCTAssertEqual(rect.origin.x, 10,  accuracy: 0.01)
        XCTAssertEqual(rect.origin.y, 20,  accuracy: 0.01)
        XCTAssertEqual(rect.width,    100, accuracy: 0.01)
        XCTAssertEqual(rect.height,   60,  accuracy: 0.01)
    }

    func testCentreComputed() throws {
        let json = """
        {
            "detections": [{
                "class_id": 1,
                "class_name": "dog",
                "confidence": 0.75,
                "bbox_xyxy": [0.0, 0.0, 200.0, 100.0]
            }],
            "count": 1
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(RemoteDetectionResponse.self, from: json)
        let centre = response.detections[0].centre
        XCTAssertEqual(centre.x, 100, accuracy: 0.01)
        XCTAssertEqual(centre.y,  50, accuracy: 0.01)
    }

    func testBoundingRectWithEmptyBbox() throws {
        let json = """
        {
            "detections": [{
                "class_id": 0,
                "class_name": "x",
                "confidence": 0.5,
                "bbox_xyxy": []
            }],
            "count": 1
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(RemoteDetectionResponse.self, from: json)
        XCTAssertEqual(response.detections[0].boundingRect, .zero)
    }

    // MARK: - SettingsManager remote inference defaults

    func testUseRemoteInferenceDefaultIsFalse() {
        let mgr = SettingsManager(defaults: UserDefaults(suiteName: #file + "remote")!)
        XCTAssertFalse(mgr.useRemoteInference)
    }

    func testRemoteServerURLDefault() {
        let mgr = SettingsManager(defaults: UserDefaults(suiteName: #file + "url")!)
        XCTAssertEqual(mgr.remoteServerURL, "http://192.168.194.196:8000")
    }

    func testRemoteServerURLPersists() {
        let suite = UserDefaults(suiteName: #file + "urlpersist")!
        suite.removePersistentDomain(forName: #file + "urlpersist")
        let mgr = SettingsManager(defaults: suite)
        mgr.remoteServerURL = "http://10.0.0.5:8000"
        XCTAssertEqual(mgr.remoteServerURL, "http://10.0.0.5:8000")
    }
}
