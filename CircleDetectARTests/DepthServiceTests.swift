import XCTest
import CoreVideo
@testable import CircleDetectAR

final class DepthServiceTests: XCTestCase {

    // MARK: - Helpers

    private func makeDepthBuffer(value: Float32,
                                  width: Int = 32,
                                  height: Int = 32) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: false,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: false
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width, height,
            kCVPixelFormatType_DepthFloat32,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buf = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buf, [])
        let rowBytes = CVPixelBufferGetBytesPerRow(buf)
        guard let base = CVPixelBufferGetBaseAddress(buf) else {
            CVPixelBufferUnlockBaseAddress(buf, [])
            return nil
        }
        let floatPtr = base.assumingMemoryBound(to: Float32.self)
        for row in 0 ..< height {
            for col in 0 ..< width {
                floatPtr[row * (rowBytes / MemoryLayout<Float32>.size) + col] = value
            }
        }
        CVPixelBufferUnlockBaseAddress(buf, [])
        return buf
    }

    // MARK: - Tests

    func testExpectedDepthValueReturned() throws {
        let expected: Float32 = 1.5
        let buf = try XCTUnwrap(makeDepthBuffer(value: expected))
        let result = DepthService.readDepth(from: buf,
                                             at: CGPoint(x: 10, y: 10),
                                             viewSize: CGSize(width: 32, height: 32))
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, expected, accuracy: 0.001)
    }

    func testNaNDepthReturnsNil() throws {
        let buf = try XCTUnwrap(makeDepthBuffer(value: .nan))
        let result = DepthService.readDepth(from: buf,
                                             at: CGPoint(x: 10, y: 10),
                                             viewSize: CGSize(width: 32, height: 32))
        XCTAssertNil(result, "NaN depth values must map to nil")
    }

    func testInfiniteDepthReturnsNil() throws {
        let buf = try XCTUnwrap(makeDepthBuffer(value: .infinity))
        let result = DepthService.readDepth(from: buf,
                                             at: CGPoint(x: 10, y: 10),
                                             viewSize: CGSize(width: 32, height: 32))
        XCTAssertNil(result, "Infinite depth values must map to nil")
    }

    func testOutOfBoundsPointClampedSafely() throws {
        // A screen point far outside the buffer should clamp and not crash
        let buf = try XCTUnwrap(makeDepthBuffer(value: 2.0))
        let result = DepthService.readDepth(from: buf,
                                             at: CGPoint(x: 9999, y: 9999),
                                             viewSize: CGSize(width: 32, height: 32))
        XCTAssertNotNil(result)   // Clamps to last valid pixel
    }

    func testZeroDepth() throws {
        let buf = try XCTUnwrap(makeDepthBuffer(value: 0.0))
        let result = DepthService.readDepth(from: buf,
                                             at: CGPoint(x: 5, y: 5),
                                             viewSize: CGSize(width: 32, height: 32))
        // 0.0 is finite and valid — should return 0
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 0.0, accuracy: 0.0001)
    }
}
