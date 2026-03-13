import CoreVideo
import ARKit

/// Reads LiDAR depth values from an ARFrame or raw CVPixelBuffer.
enum DepthService {

    /// Returns the metric depth (in metres) at `screenPoint` from the ARFrame's scene depth map.
    /// Returns `nil` if a depth map is unavailable or the sampled value is invalid.
    static func readDepth(from frame: ARFrame,
                          at screenPoint: CGPoint,
                          viewSize: CGSize) -> Float? {
        guard let depthMap = frame.sceneDepth?.depthMap else { return nil }
        return readDepth(from: depthMap, at: screenPoint, viewSize: viewSize)
    }

    /// Reads the depth value directly from a Float32 depth `CVPixelBuffer`.
    static func readDepth(from depthMap: CVPixelBuffer,
                          at screenPoint: CGPoint,
                          viewSize: CGSize) -> Float? {
        let bufferWidth  = CVPixelBufferGetWidth(depthMap)
        let bufferHeight = CVPixelBufferGetHeight(depthMap)

        let x = Int((screenPoint.x / viewSize.width)  * CGFloat(bufferWidth))
                    .clamped(to: 0 ..< bufferWidth)
        let y = Int((screenPoint.y / viewSize.height) * CGFloat(bufferHeight))
                    .clamped(to: 0 ..< bufferHeight)

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddr = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let rowBytes    = CVPixelBufferGetBytesPerRow(depthMap)
        let floatBuffer = baseAddr.assumingMemoryBound(to: Float32.self)
        let depth       = floatBuffer[y * (rowBytes / MemoryLayout<Float32>.size) + x]

        return (depth.isNaN || depth.isInfinite) ? nil : depth
    }
}

// MARK: - Helpers

private extension Int {
    func clamped(to range: Range<Int>) -> Int {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound - 1))
    }
}
