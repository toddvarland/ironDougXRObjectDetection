import XCTest
import CoreVideo
@testable import CircleDetectAR

/// Tests for ClassificationService.
/// Note: when no Core ML model is present, the service returns "Add model →" — tests
/// handle both the model-present and model-absent paths.
final class ClassificationServiceTests: XCTestCase {

    private let service = ClassificationService()

    // MARK: - Helpers

    private func makeBlankPixelBuffer(width: Int = 224, height: Int = 224) -> CVPixelBuffer? {
        var buf: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32BGRA, nil, &buf
        )
        return buf
    }

    // MARK: - Tests

    func testClassificationAlwaysCallsCompletion() throws {
        let buf = try XCTUnwrap(makeBlankPixelBuffer())
        let exp = expectation(description: "Completion called")

        service.classify(
            pixelBuffer: buf,
            regionOfInterest: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        ) { label, confidence in
            XCTAssertFalse(label.isEmpty, "Label must not be empty")
            XCTAssertGreaterThanOrEqual(confidence, 0, "Confidence must be non-negative")
            exp.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    func testClassificationCompletesOnMainThread() throws {
        let buf = try XCTUnwrap(makeBlankPixelBuffer())
        let exp = expectation(description: "Completion on main thread")

        service.classify(
            pixelBuffer: buf,
            regionOfInterest: CGRect(x: 0, y: 0, width: 1, height: 1)
        ) { _, _ in
            XCTAssertTrue(Thread.isMainThread, "Completion must be called on the main thread")
            exp.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    func testClassificationConfidenceRange() throws {
        let buf = try XCTUnwrap(makeBlankPixelBuffer())
        let exp = expectation(description: "Confidence in [0, 1]")

        service.classify(
            pixelBuffer: buf,
            regionOfInterest: CGRect(x: 0, y: 0, width: 1, height: 1)
        ) { _, confidence in
            XCTAssertGreaterThanOrEqual(confidence, 0)
            XCTAssertLessThanOrEqual(confidence, 1)
            exp.fulfill()
        }

        waitForExpectations(timeout: 10)
    }
}
