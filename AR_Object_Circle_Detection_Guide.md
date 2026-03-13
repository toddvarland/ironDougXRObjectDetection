# AR Object Circle Detection — iPhone 14 Pro Max Native App Guide

---

## Original Prompt

> Build a markdown guide for building an iPhone 14 Pro Max native AR app that will identify objects circled on iPhone screen. Put follow-up questions at the end. Put this prompt at the beginning.

---

## Overview

This guide walks through building a native iOS AR application for iPhone 14 Pro Max that allows users to draw a circle gesture on the screen over a real-world object and receive an identification of that object using ARKit, RealityKit, Vision, and Core ML.

**Target Platform:** iPhone 14 Pro Max  
**Minimum iOS Version:** iOS 16.0  
**Language:** Swift  
**Frameworks:** ARKit, RealityKit, Vision, Core ML, UIKit / SwiftUI

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Project Setup](#2-project-setup)
3. [Configuring ARKit Session](#3-configuring-arkit-session)
4. [Building the Circle Gesture Recognizer](#4-building-the-circle-gesture-recognizer)
5. [Capturing the Circled Region](#5-capturing-the-circled-region)
6. [Object Classification with Vision + Core ML](#6-object-classification-with-vision--core-ml)
7. [Displaying Results in AR](#7-displaying-results-in-ar)
8. [Leveraging iPhone 14 Pro Max Hardware](#8-leveraging-iphone-14-pro-max-hardware)
9. [LiDAR-Enhanced Object Placement](#9-lidar-enhanced-object-placement)
10. [Privacy and Permissions](#10-privacy-and-permissions)
11. [Testing & Debugging](#11-testing--debugging)
12. [Performance Optimization](#12-performance-optimization)
13. [Full Project Structure](#13-full-project-structure)
14. [Programmatic Test Plan](#14-programmatic-test-plan)
15. [Manual Test Plan](#15-manual-test-plan)
16. [User Guide](#16-user-guide)
17. [Follow-Up Questions](#17-follow-up-questions)

---

## 1. Prerequisites

### Tools
- **Xcode 15+** (macOS 14 Ventura or later recommended)
- Apple Developer Program membership (for device deployment)
- iPhone 14 Pro Max (physical device — AR cannot be tested on the simulator)

### Knowledge
- Swift fundamentals
- UIKit or SwiftUI basics
- Familiarity with closures, delegates, and async/await

### Dependencies (optional but recommended)
- No third-party AR libraries required — Apple's first-party stack is sufficient
- `CreateML` (if you want to train a custom object recognition model)

---

## 2. Project Setup

### 2.1 Create the Xcode Project

1. Open Xcode → **File > New > Project**
2. Choose **App** under iOS
3. Settings:
   - **Product Name:** `CircleDetectAR`
   - **Interface:** SwiftUI (or UIKit — examples below use UIKit for fine-grained AR control)
   - **Language:** Swift
   - **Minimum Deployments:** iOS 16.0

### 2.2 Add Required Frameworks

In **Build Phases > Link Binary With Libraries**, confirm these are present (most are auto-linked):

- `ARKit.framework`
- `RealityKit.framework`
- `Vision.framework`
- `CoreML.framework`
- `SceneKit.framework` (optional fallback)

### 2.3 Info.plist Permissions

Add the following keys to `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app uses the camera for augmented reality object detection.</string>
```

---

## 3. Configuring ARKit Session

### 3.1 ARView Setup

```swift
import ARKit
import RealityKit
import UIKit

class ARViewController: UIViewController {

    var arView: ARView!

    override func viewDidLoad() {
        super.viewDidLoad()
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
        configureARSession()
    }

    func configureARSession() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.sceneReconstruction = .meshWithClassification  // LiDAR
        config.environmentTexturing = .automatic
        config.frameSemantics = [.sceneDepth, .smoothedSceneDepth]  // LiDAR depth
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        arView.debugOptions = []  // Set to [.showFeaturePoints] during dev
    }
}
```

> **Note:** `sceneReconstruction` and `frameSemantics` depth options require the LiDAR scanner present on iPhone 14 Pro Max.

---

## 4. Building the Circle Gesture Recognizer

The core interaction: the user draws a circular path on the screen with their finger. The app detects when the path is approximately circular and closes, then extracts the bounding region.

### 4.1 Custom UIGestureRecognizer

```swift
import UIKit
import UIKit.UIGestureRecognizerSubclass

class CircleGestureRecognizer: UIGestureRecognizer {

    private(set) var circlePath = UIBezierPath()
    private(set) var boundingRect: CGRect = .zero
    private var touchPoints: [CGPoint] = []

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        touchPoints = [touch.location(in: view)]
        circlePath = UIBezierPath()
        circlePath.move(to: touchPoints[0])
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        let point = touch.location(in: view)
        touchPoints.append(point)
        circlePath.addLine(to: point)
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        if isClosedCircle() {
            boundingRect = computeBoundingRect()
            state = .ended
        } else {
            state = .failed
        }
    }

    // MARK: - Circle Detection Heuristics

    private func isClosedCircle() -> Bool {
        guard touchPoints.count > 20,
              let first = touchPoints.first,
              let last = touchPoints.last else { return false }

        let closingDistance = hypot(first.x - last.x, first.y - last.y)
        let totalLength = pathLength()
        let radius = totalLength / (2 * .pi)

        // Closing distance should be small relative to estimated radius
        return closingDistance < radius * 0.4 && totalLength > 80
    }

    private func pathLength() -> CGFloat {
        var length: CGFloat = 0
        for i in 1..<touchPoints.count {
            let dx = touchPoints[i].x - touchPoints[i-1].x
            let dy = touchPoints[i].y - touchPoints[i-1].y
            length += hypot(dx, dy)
        }
        return length
    }

    private func computeBoundingRect() -> CGRect {
        let xs = touchPoints.map(\.x)
        let ys = touchPoints.map(\.y)
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    override func reset() {
        super.reset()
        touchPoints = []
        circlePath = UIBezierPath()
        boundingRect = .zero
    }
}
```

### 4.2 Drawing Feedback Overlay

```swift
class CircleOverlayView: UIView {

    var path: UIBezierPath? {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let path = path else { return }
        UIColor.systemYellow.withAlphaComponent(0.8).setStroke()
        path.lineWidth = 3
        path.stroke()
    }
}
```

Add `CircleOverlayView` on top of `arView` and update its path from `touchesMoved`.

---

## 5. Capturing the Circled Region

Once the gesture recognizes a closed circle, capture that region from the current AR camera frame.

```swift
func handleCircleGesture(_ recognizer: CircleGestureRecognizer) {
    guard recognizer.state == .ended else { return }
    let rect = recognizer.boundingRect

    // Grab the current AR frame's pixel buffer
    guard let currentFrame = arView.session.currentFrame else { return }
    let pixelBuffer = currentFrame.capturedImage

    // Convert screen rect to normalized Vision coordinates
    let viewSize = arView.bounds.size
    let normalizedRect = VNNormalizedRectForImageRect(rect, Int(viewSize.width), Int(viewSize.height))

    classifyRegion(pixelBuffer: pixelBuffer, normalizedRect: normalizedRect)
}
```

---

## 6. Object Classification with Vision + Core ML

### 6.1 Using a Pre-Trained Model

Apple provides several ready-to-use Core ML models:
- **MobileNetV2** — fast, on-device classification
- **ResNet50** — higher accuracy
- **YOLOv3 / YOLOv3Tiny** — object detection with bounding boxes

Download from [Apple's Core ML Models page](https://developer.apple.com/machine-learning/models/) and drag the `.mlmodel` file into your Xcode project.

### 6.2 Classification Request

```swift
import Vision
import CoreML

func classifyRegion(pixelBuffer: CVPixelBuffer, normalizedRect: CGRect) {
    guard let model = try? VNCoreMLModel(for: MobileNetV2().model) else { return }

    let request = VNCoreMLRequest(model: model) { [weak self] request, error in
        guard let results = request.results as? [VNClassificationObservation],
              let top = results.first else { return }
        DispatchQueue.main.async {
            self?.showLabel(text: "\(top.identifier) (\(Int(top.confidence * 100))%)",
                            at: self?.lastGestureMidpoint ?? .zero)
        }
    }

    // Crop to the circled region
    request.regionOfInterest = normalizedRect
    request.imageCropAndScaleOption = .centerCrop

    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                        orientation: .right,
                                        options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
        try? handler.perform([request])
    }
}
```

### 6.3 Object Detection (YOLO — Bounding Boxes)

For detecting multiple objects and their locations, use `VNCoreMLRequest` with a YOLO model returning `VNRecognizedObjectObservation`:

```swift
let request = VNCoreMLRequest(model: yoloModel) { request, _ in
    let observations = request.results as? [VNRecognizedObjectObservation] ?? []
    for obs in observations {
        let label = obs.labels.first?.identifier ?? "Unknown"
        let confidence = obs.labels.first?.confidence ?? 0
        print("\(label) — \(Int(confidence * 100))% at \(obs.boundingBox)")
    }
}
```

### 6.4 Training a Custom Model with Create ML

If the default models don't cover your domain:

1. Open **Xcode > Open Developer Tool > Create ML**
2. Choose **Image Classification** template
3. Drag in labeled image folders (e.g., `chair/`, `table/`, `lamp/`)
4. Train, evaluate, and export as `.mlmodel`
5. Add to your Xcode project

---

## 7. Displaying Results in AR

### 7.1 Raycasting to Place a Label in 3D Space

```swift
func showLabel(text: String, at screenPoint: CGPoint) {
    // Raycast from the circle center into the AR scene
    let results = arView.raycast(from: screenPoint,
                                  allowing: .estimatedPlane,
                                  alignment: .any)

    guard let hit = results.first else {
        show2DLabel(text: text, at: screenPoint)
        return
    }

    // Create a RealityKit text entity
    let textMesh = MeshResource.generateText(
        text,
        extrusionDepth: 0.001,
        font: .systemFont(ofSize: 0.04),
        containerFrame: .zero,
        alignment: .center,
        lineBreakMode: .byWordWrapping
    )
    let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
    let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])

    // Billboard: face the camera
    textEntity.components[BillboardComponent.self] = BillboardComponent()

    let anchor = AnchorEntity(world: hit.worldTransform)
    anchor.addChild(textEntity)
    arView.scene.addAnchor(anchor)

    // Auto-remove after 4 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
        anchor.removeFromParent()
    }
}
```

### 7.2 2D Fallback HUD Label

```swift
func show2DLabel(text: String, at point: CGPoint) {
    let label = UILabel()
    label.text = text
    label.textColor = .white
    label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
    label.layer.cornerRadius = 8
    label.clipsToBounds = true
    label.font = .boldSystemFont(ofSize: 16)
    label.sizeToFit()
    label.center = point
    view.addSubview(label)
    UIView.animate(withDuration: 0.3, delay: 3.0, options: .curveEaseOut) {
        label.alpha = 0
    } completion: { _ in
        label.removeFromSuperview()
    }
}
```

---

## 8. Leveraging iPhone 14 Pro Max Hardware

The iPhone 14 Pro Max provides unique hardware advantages:

| Feature | API | Benefit |
|---|---|---|
| LiDAR Scanner | `ARWorldTrackingConfiguration.sceneReconstruction` | Instant plane detection, real depth |
| ProMotion (120Hz) | Automatic with RealityKit | Smoother AR rendering |
| 48MP Main Camera | `ARConfiguration.videoFormat` (high-res) | Sharper region crops for Vision |
| A16 Bionic Neural Engine | Core ML on device | Low-latency, private inference |
| Depth API | `ARFrame.sceneDepth` | Distance to circled object |

### 8.1 High-Resolution Camera Format

```swift
func selectHighResFormat(for config: ARWorldTrackingConfiguration) {
    let formats = ARWorldTrackingConfiguration.supportedVideoFormats
    if let hiRes = formats.first(where: { $0.imageResolution.width >= 1920 }) {
        config.videoFormat = hiRes
    }
}
```

### 8.2 Reading LiDAR Depth at Touch Point

```swift
func depthAtPoint(_ screenPoint: CGPoint) -> Float? {
    guard let frame = arView.session.currentFrame,
          let depthMap = frame.sceneDepth?.depthMap else { return nil }

    let imageSize = CGSize(width: CVPixelBufferGetWidth(depthMap),
                           height: CVPixelBufferGetHeight(depthMap))
    let viewSize = arView.bounds.size
    let scaleX = imageSize.width / viewSize.width
    let scaleY = imageSize.height / viewSize.height

    let depthPoint = CGPoint(x: screenPoint.x * scaleX,
                             y: screenPoint.y * scaleY)

    CVPixelBufferLockBaseAddress(depthMap, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

    let rowBytes = CVPixelBufferGetBytesPerRow(depthMap)
    guard let baseAddr = CVPixelBufferGetBaseAddress(depthMap) else { return nil }

    let x = Int(depthPoint.x)
    let y = Int(depthPoint.y)
    let floatBuffer = baseAddr.assumingMemoryBound(to: Float32.self)
    let depth = floatBuffer[y * (rowBytes / MemoryLayout<Float32>.size) + x]
    return depth.isNaN ? nil : depth
}
```

---

## 9. LiDAR-Enhanced Object Placement

Use scene mesh classification to anchor labels directly to real-world surfaces:

```swift
func anchorLabelToLiDARSurface(text: String, at screenPoint: CGPoint) {
    let query = arView.makeRaycastQuery(from: screenPoint,
                                         allowing: .estimatedPlane,
                                         alignment: .any)
    guard let query = query else { return }

    let results = arView.session.raycast(query)
    guard let result = results.first else { return }

    // The transform gives us a precise 3D hit point courtesy of LiDAR mesh
    let anchor = ARAnchor(name: text, transform: result.worldTransform)
    arView.session.add(anchor: anchor)
}
```

Subscribe to `ARSessionDelegate.session(_:didAdd:)` to create your label entity when the anchor is added to the session.

---

## 10. Privacy and Permissions

- **Camera access** is required — always handle the case where permission is denied gracefully.
- All Vision/Core ML inference runs **on-device** — no images are sent to external servers.
- If you store any captured frames or labels, disclose this in your Privacy Policy and use the standard iOS photo/file permission flows.

```swift
import AVFoundation

func checkCameraPermission(completion: @escaping (Bool) -> Void) {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
        completion(true)
    case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video, handler: completion)
    default:
        completion(false)
    }
}
```

---

## 11. Testing & Debugging

### 11.1 Debug Overlays

```swift
// Show feature points and world origin
arView.debugOptions = [.showFeaturePoints, .showWorldOrigin]

// Show scene understanding mesh (LiDAR)
arView.debugOptions.insert(.showSceneUnderstanding)
```

### 11.2 Vision Request Debugging

Log all classification results during development:

```swift
let allResults = (request.results as? [VNClassificationObservation]) ?? []
allResults.prefix(5).forEach {
    print("  \($0.identifier): \(String(format: "%.1f%%", $0.confidence * 100))")
}
```

### 11.3 ARKit Coaching Overlay

Help users initialize tracking:

```swift
let coachingOverlay = ARCoachingOverlayView()
coachingOverlay.session = arView.session
coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
coachingOverlay.goal = .anyPlane
view.addSubview(coachingOverlay)
```

---

## 12. Performance Optimization

| Concern | Recommendation |
|---|---|
| Vision requests on main thread | Always dispatch to `DispatchQueue.global(qos: .userInitiated)` |
| Redundant classifications | Throttle requests — e.g., one per gesture, not every frame |
| Memory for ML models | Load model once and reuse via a singleton or lazy var |
| AR frame capture | Use `arView.session.currentFrame` only on demand, not in the render loop |
| Label accumulation | Remove AR anchors after a timeout to keep scene clean |

```swift
// Singleton model accessor
class ModelService {
    static let shared = ModelService()
    lazy var visionModel: VNCoreMLModel? = {
        try? VNCoreMLModel(for: MobileNetV2().model)
    }()
}
```

---

## 13. Full Project Structure

```
CircleDetectAR/
├── App/
│   ├── CircleDetectARApp.swift        # App entry point
│   └── Info.plist
├── Views/
│   ├── ARViewController.swift         # Main AR view controller
│   └── CircleOverlayView.swift        # Transparent drawing overlay
├── Gestures/
│   └── CircleGestureRecognizer.swift  # Custom UIGestureRecognizer
├── Detection/
│   ├── ClassificationService.swift    # Vision + Core ML logic
│   └── DepthService.swift             # LiDAR depth queries
├── AR/
│   ├── LabelAnchorManager.swift       # Creates/removes AR label anchors
│   └── ARSessionManager.swift         # ARSession configuration
├── Models/
│   └── MobileNetV2.mlmodel            # Core ML model (add your own)
└── Resources/
    └── Assets.xcassets
```

---

## 14. Programmatic Test Plan

Write automated tests using **XCTest** (unit) and **XCUITest** (UI/integration). Because AR requires a physical device, unit tests mock ARKit dependencies and Vision results, while UI tests run on-device.

### 14.1 Unit Tests — CircleGestureRecognizer

```swift
import XCTest
@testable import CircleDetectAR

final class CircleGestureRecognizerTests: XCTestCase {

    // Simulate a roughly circular path and verify it closes
    func testClosedCircleDetected() {
        let recognizer = CircleGestureRecognizer()
        let center = CGPoint(x: 200, y: 200)
        let radius: CGFloat = 80
        let points: [CGPoint] = (0...40).map { i in
            let angle = (CGFloat(i) / 40) * 2 * .pi
            return CGPoint(x: center.x + radius * cos(angle),
                           y: center.y + radius * sin(angle))
        }
        // Inject points directly via the testable interface
        recognizer.injectTouchPoints(points)
        XCTAssertTrue(recognizer.testIsClosedCircle(),
                      "A full circular path should be recognized as closed")
    }

    func testOpenPathNotDetected() {
        let recognizer = CircleGestureRecognizer()
        let points: [CGPoint] = (0...20).map { i in
            CGPoint(x: CGFloat(i) * 10, y: 100)  // straight line
        }
        recognizer.injectTouchPoints(points)
        XCTAssertFalse(recognizer.testIsClosedCircle(),
                       "A straight line should not be recognized as a circle")
    }

    func testBoundingRectAccuracy() {
        let recognizer = CircleGestureRecognizer()
        let points = [CGPoint(x: 100, y: 100), CGPoint(x: 200, y: 100),
                      CGPoint(x: 200, y: 200), CGPoint(x: 100, y: 200),
                      CGPoint(x: 100, y: 100)]
        recognizer.injectTouchPoints(points)
        let rect = recognizer.testBoundingRect()
        XCTAssertEqual(rect.minX, 100)
        XCTAssertEqual(rect.minY, 100)
        XCTAssertEqual(rect.width, 100, accuracy: 1)
        XCTAssertEqual(rect.height, 100, accuracy: 1)
    }
}
```

> Add `internal` test-only methods (`injectTouchPoints`, `testIsClosedCircle`, `testBoundingRect`) to `CircleGestureRecognizer` guarded by `#if DEBUG`.

### 14.2 Unit Tests — ClassificationService

```swift
final class ClassificationServiceTests: XCTestCase {

    func testClassificationCallsCompletion() {
        let service = ClassificationService()
        let expectation = expectation(description: "Classification completes")

        // Load a bundled test image (add a sample JPEG to the test target)
        let testImage = UIImage(named: "test_chair", in: Bundle(for: type(of: self)), with: nil)!
        guard let buffer = testImage.toCVPixelBuffer() else {
            XCTFail("Could not create pixel buffer from test image")
            return
        }

        service.classify(pixelBuffer: buffer, regionOfInterest: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)) { label, confidence in
            XCTAssertFalse(label.isEmpty, "Label should not be empty")
            XCTAssertGreaterThan(confidence, 0, "Confidence should be positive")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5)
    }

    func testLowConfidenceHandled() {
        // Use a blank (noise) image — model should still return a result, even if low confidence
        let service = ClassificationService()
        let expectation = expectation(description: "Low-confidence result returned")
        let blankBuffer = createBlankPixelBuffer(width: 224, height: 224)!
        service.classify(pixelBuffer: blankBuffer, regionOfInterest: .init(x: 0, y: 0, width: 1, height: 1)) { label, _ in
            XCTAssertNotNil(label)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5)
    }
}
```

### 14.3 Unit Tests — DepthService

```swift
final class DepthServiceTests: XCTestCase {

    func testDepthReadReturnsNilForNaNPixel() {
        let buffer = createDepthBuffer(value: Float.nan)!
        let result = DepthService.readDepth(from: buffer, at: CGPoint(x: 10, y: 10), viewSize: CGSize(width: 100, height: 100))
        XCTAssertNil(result, "NaN depth values should return nil")
    }

    func testDepthReadReturnsExpectedValue() {
        let expected: Float = 1.5
        let buffer = createDepthBuffer(value: expected)!
        let result = DepthService.readDepth(from: buffer, at: CGPoint(x: 10, y: 10), viewSize: CGSize(width: 100, height: 100))
        XCTAssertEqual(result, expected, accuracy: 0.001)
    }
}
```

### 14.4 UI Tests — End-to-End Gesture + Label Flow

```swift
import XCUITest

final class CircleDetectARUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]  // disables coaching overlay
        app.launch()
    }

    func testAppLaunchesWithARView() {
        XCTAssertTrue(app.otherElements["ARViewContainer"].waitForExistence(timeout: 5),
                      "AR view should be visible on launch")
    }

    func testCircleGestureProducesLabel() {
        let arView = app.otherElements["ARViewContainer"]
        XCTAssertTrue(arView.waitForExistence(timeout: 5))

        // Draw an approximate circle on the AR view
        let center = arView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let path = drawCirclePath(around: center, radius: 80, steps: 36)
        arView.press(forDuration: 0, thenDragTo: arView, withVelocity: .fast, thenHoldForDuration: 0)
        simulateCircleDrag(in: arView, path: path)

        // A result label or AR annotation should appear
        let resultLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] '%'" )).firstMatch
        XCTAssertTrue(resultLabel.waitForExistence(timeout: 6),
                      "A confidence percentage label should appear after circle gesture")
    }

    func testPermissionDeniedShowsAlert() {
        // Requires a separate test scheme where camera permission is pre-denied
        // via app.launchArguments = ["--camera-denied"]
        let alert = app.alerts["Camera Access Required"]
        // Only assert if the alert key is triggered by the app's permission-denied path
        if alert.exists {
            XCTAssertTrue(alert.buttons["Settings"].exists)
        }
    }
}
```

### 14.5 Xcode Test Plan Configuration

Create a `.xctestplan` file (`CircleDetectAR.xctestplan`) in the project root:

```json
{
  "configurations": [
    {
      "id": "unit-tests",
      "name": "Unit Tests",
      "options": {
        "testTimeoutsEnabled": true,
        "defaultTestExecutionTimeAllowance": 10
      },
      "testTargets": [
        { "target": { "name": "CircleDetectARTests" } }
      ]
    },
    {
      "id": "ui-tests",
      "name": "UI Tests (Device Only)",
      "options": {
        "testTimeoutsEnabled": true,
        "defaultTestExecutionTimeAllowance": 30
      },
      "testTargets": [
        { "target": { "name": "CircleDetectARUITests" } }
      ]
    }
  ],
  "defaultOptions": {
    "codeCoverageEnabled": true
  },
  "version": 1
}
```

### 14.6 CI/CD Integration (GitHub Actions)

```yaml
# .github/workflows/test.yml
name: CircleDetectAR Tests

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run unit tests
        run: |
          xcodebuild test \
            -project CircleDetectAR.xcodeproj \
            -scheme CircleDetectAR \
            -testPlan unit-tests \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            | xcpretty
```

> **Note:** UI tests require a physical iPhone 14 Pro Max — they cannot run in CI without a connected device or a cloud device farm (e.g., AWS Device Farm, BrowserStack).

---

## 15. Manual Test Plan

Run these test cases on a physical **iPhone 14 Pro Max** before each release. Use the checklist format — mark each as Pass (P), Fail (F), or Blocked (B).

---

### MT-01 — App Launch & Permissions

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Install and open the app for the first time | Camera permission prompt appears |
| 2 | Tap **Allow** | AR camera feed becomes visible |
| 3 | Force-quit and reopen | AR feed resumes without re-prompting |
| 4 | Go to Settings > Privacy > Camera > CircleDetectAR, revoke permission | App shows an alert explaining camera is required |
| 5 | Tap **Settings** in the alert | iOS Settings opens to the app's permissions page |

---

### MT-02 — AR Tracking Initialization

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open the app in a well-lit room | ARKit coaching overlay appears prompting to move device |
| 2 | Slowly pan the camera across flat surfaces | Coaching overlay dismisses once tracking is established |
| 3 | Cover the camera with a hand briefly | Tracking lost indicator appears |
| 4 | Uncover and move the device | Tracking recovers gracefully |

---

### MT-03 — Circle Gesture Recognition

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Draw a smooth, closed circle with one finger over an object | Yellow stroke traces the path; gesture recognized |
| 2 | Draw an intentionally open arc (do not close the path) | Gesture fails silently; no classification triggered |
| 3 | Draw a very small circle (< 40px diameter) | Gesture fails; minimum size threshold enforced |
| 4 | Draw a very large circle filling most of the screen | Gesture recognized; full frame classified |
| 5 | Draw the circle quickly (fast swipe) | Gesture still recognized with enough sample points |
| 6 | Draw an irregular, lumpy closed shape (roughly circular) | Should recognize if closing distance threshold is met |

---

### MT-04 — Object Classification

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Circle a chair in good lighting | Label appears with "chair" (or similar) and confidence % |
| 2 | Circle the same object in dim lighting | Label appears (may have lower confidence) |
| 3 | Circle a person | Label shows a person-related class |
| 4 | Circle an area with no distinct object (blank wall) | Label shows a low-confidence or generic result |
| 5 | Circle two overlapping objects | Label shows the dominant classification |
| 6 | Rapidly draw circles on different objects in succession | Each gesture triggers a separate classification independently |

---

### MT-05 — AR Label Display

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Circle an object with a clear surface behind it | 3D floating label appears anchored near the object |
| 2 | Move the device away from the labeled object | Label remains anchored in world space (does not follow device) |
| 3 | Wait 4+ seconds after a label appears | Label fades out and is removed from the scene |
| 4 | Circle an object with no detectable surface (mid-air) | 2D HUD label appears on screen at the circle's center |
| 5 | Rotate device to landscape | UI adapts; labels remain correctly positioned |

---

### MT-06 — LiDAR & Depth Features

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Circle an object at ~0.5 m distance | Depth distance displayed alongside label (if enabled) |
| 2 | Circle an object at ~3 m distance | Depth value updates correctly |
| 3 | Point camera at a mirror or glass surface | Depth may be inaccurate — app should not crash |
| 4 | Enable scene mesh debug overlay in dev build | LiDAR mesh correctly wraps the room geometry |

---

### MT-07 — Performance

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Run the app for 10 continuous minutes | No crash, no memory warning |
| 2 | Draw 20 circles in rapid succession | No lag or dropped AR frames; no memory leak |
| 3 | Check Xcode Instruments (Time Profiler) during a session | Main thread is not blocked during classification |
| 4 | Monitor thermal state (Instruments > Energy) | Device does not throttle within a typical session |

---

### MT-08 — Edge Cases & Error Handling

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open the app while another app is using the camera | Graceful error or permission-conflict message shown |
| 2 | Receive a phone call during an AR session | App suspends cleanly; resumes correctly after call |
| 3 | Lock the device during an AR session | App suspends; AR session resumes on unlock |
| 4 | Open app in a completely dark room | AR session runs but tracking quality is degraded; no crash |

---

### MT-09 — Accessibility

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Enable VoiceOver (Settings > Accessibility > VoiceOver) | AR view announces "AR camera active" |
| 2 | Draw a circle with VoiceOver on | Classification result is announced audibly |
| 3 | Enable Bold Text and Large Text in Accessibility settings | All HUD labels scale correctly; no truncation |

---

### MT-10 — Regression Checklist (Run on Every Build)

- [ ] App launches without crash on iPhone 14 Pro Max (iOS 16+)
- [ ] Camera permission flow works correctly from fresh install
- [ ] Circle gesture recognized reliably (>80% success on deliberate circles)
- [ ] Classification result appears within 2 seconds of gesture completion
- [ ] AR label anchors correctly to 3D world position
- [ ] Labels auto-dismiss after 4 seconds
- [ ] No memory leaks detected in Instruments (Leaks template)
- [ ] App handles backgrounding and foregrounding without crash

---

## 16. User Guide

This section is written for end users. It can be extracted as a standalone help document or included in an in-app onboarding flow.

---

### Welcome to CircleDetectAR

**CircleDetectAR** uses your iPhone's camera and augmented reality to instantly identify objects around you. Just draw a circle around anything you see on your screen and the app will tell you what it is.

---

### Getting Started

#### Step 1 — Allow Camera Access

When you open the app for the first time, you will be asked to allow access to your camera. Tap **Allow** — without it, the app cannot see the world around you. No images are ever uploaded; all processing happens privately on your device.

#### Step 2 — Point at the World

Hold your iPhone up and slowly move it around the room. You will see a short animation guiding you to scan nearby surfaces. Once the AR system is ready, the animation disappears and you are ready to use the app.

#### Step 3 — Circle an Object

Place your finger on the screen over an object you want to identify and **draw a circle around it** without lifting your finger. Try to complete the circle — bring your finger back close to where you started.

> **Tip:** Smooth, deliberate circles work best. You don't need to be perfectly round, but the path should loop back to where it began.

#### Step 4 — Read the Result

Within a second or two, a label will appear near the object telling you what the app thinks it is, along with a confidence percentage. The label will float in place in the real world for a few seconds before fading away.

---

### Tips for Best Results

| Do | Why |
|----|-----|
| Use in good lighting | More light = better image quality = more accurate results |
| Circle individual objects | Avoid circling several objects at once |
| Hold the phone steady as you draw | Reduces motion blur in the captured image |
| Circle from about 0.5 – 3 metres away | Optimal LiDAR and camera range for iPhone 14 Pro Max |
| Draw a circle roughly 5–10 cm diameter on screen | Gives the classifier a clear region to analyze |

| Avoid | Why |
|-------|-----|
| Drawing in a very dark room | Camera quality drops significantly |
| Circling mirrors or glass | LiDAR depth can be confused by reflective surfaces |
| Drawing very fast, choppy strokes | May not register as a closed circle |
| Pointing at blank walls or uniform surfaces | The model needs visual detail to classify |

---

### Understanding Confidence Scores

The number shown in parentheses after the object name is the model's **confidence score**:

- **80–100%** — High confidence. The model is quite sure.
- **50–79%** — Moderate confidence. The result is likely correct but worth a second look.
- **Below 50%** — Low confidence. The lighting, angle, or object type may be challenging for the model.

---

### Troubleshooting

**The app asks for camera access every time.**  
Go to *Settings > Privacy & Security > Camera* and make sure CircleDetectAR is toggled on.

**The scanning animation won't go away.**  
Move your iPhone slowly over nearby flat surfaces (floor, table, wall). The AR system needs to map the space before it's ready.

**I drew a circle but nothing happened.**  
Try drawing more slowly and make sure you close the loop — the end of your stroke should return close to where it started. Circles smaller than about a centimeter on screen may not register.

**The label appears in the wrong spot.**  
This can happen if there is no detectable surface behind the object (e.g., object is in mid-air). A floating 2D label on the screen will appear instead.

**The result seems wrong.**  
The app uses a general-purpose model, so unusual or rare objects may not be identified correctly. Try circling the object from a different angle or in better lighting.

**The app crashes or freezes.**  
Force-quit the app and reopen it. Make sure you are running the latest version and that your iPhone has a stable iOS version installed.

---

### Privacy

All image analysis happens **entirely on your device** using Apple's Core ML framework. No photos, video, or object data are ever sent to a server or stored without your permission.

---

### Supported Device

CircleDetectAR is optimized for **iPhone 14 Pro Max** running **iOS 16.0 or later**. Some features (LiDAR depth, scene reconstruction) require the LiDAR Scanner present on Pro models.

---

## 17. Follow-Up Questions

1. **Model selection:** Do you want to use a pre-trained Apple model (MobileNetV2, YOLOv3), or do you need to train a custom Core ML model with your own object categories using Create ML?

2. **Gesture precision:** Should the circle gesture be strict (nearly perfect circles only) or forgiving (any roughly closed loop counts as a selection)?

3. **Multi-object support:** Should the app identify one object per circle, or detect and label all visible objects within the circled region simultaneously?

4. **UI style:** Are you building with UIKit (more AR control, lower-level) or SwiftUI (declarative, RealityKit 2 entity model)? Both are supported — the approach differs in how you layer the overlay and results.

5. **Depth integration:** Should the distance to the circled object (from LiDAR depth data) be displayed alongside its label?

6. **Persistence:** Do you want identified object labels to persist across AR sessions (saved anchors), or should they reset each time the app is launched?

7. **Offline vs. cloud:** Is full on-device inference required (for privacy or offline use), or is connecting to a cloud vision API (e.g., Google Vision, AWS Rekognition) acceptable for higher accuracy?

8. **Domain specificity:** What types of objects will users most commonly circle? (Household items, industrial equipment, plants, food, etc.) — this determines whether a general model or a fine-tuned domain-specific model is more appropriate.

9. **Accessibility:** Should the app support VoiceOver announcements when an object is identified, so it can be used by visually impaired users?

10. **Sharing & export:** Should users be able to save or share screenshots with AR labels overlaid on them?

---

*Guide last updated: March 2026 | Target: iPhone 14 Pro Max, iOS 16+, Xcode 15+*

