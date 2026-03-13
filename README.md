# CircleDetectAR

A native iOS augmented reality app for **iPhone 14 Pro Max** that identifies real-world objects you circle with your finger on screen.

Point your camera at any object, draw a closed circle around it, and a floating AR label appears in the world telling you what the app thinks it is.

---

## Features

- **Circle gesture recognition** — draw a closed loop over any object; the app detects the gesture and classifies the enclosed region
- **On-device ML** — Vision + Core ML inference runs entirely on the A16 Bionic Neural Engine; no images leave the device
- **LiDAR integration** — uses the iPhone 14 Pro Max LiDAR scanner for instant plane detection, scene reconstruction, and metric depth readings
- **3D world-anchored labels** — classification results are placed in AR space via raycasting, floating in front of the real object
- **Tracking state banner** — colour-coded top banner shows AR tracking quality (normal / limited / unavailable) with human-readable reasons
- **Haptic feedback** — medium impact on gesture acceptance; success notification when result arrives
- **VoiceOver support** — classification results are announced via `UIAccessibility`
- **Debug overlay** (DEBUG builds) — two-finger triple-tap cycles through feature points → scene mesh → all → off

---

## Requirements

| Item | Version |
|---|---|
| Device | iPhone 14 Pro Max (LiDAR required for full feature set) |
| iOS | 16.0+ |
| Xcode | 15.0+ |
| macOS | 14.0+ (Ventura) |
| Swift | 5.9 |
| Tools | [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) |

---

## Project Structure

```
CircleDetectAR/
├── App/
│   ├── AppDelegate.swift          @main entry, UIScene lifecycle
│   ├── SceneDelegate.swift        Sets ARViewController as root
│   └── Info.plist                 Camera permission, ARKit requirement
├── Views/
│   ├── ARViewController.swift     Central coordinator
│   └── CircleOverlayView.swift    Live yellow stroke overlay
├── Gestures/
│   └── CircleGestureRecognizer.swift  Closed-loop detection
├── AR/
│   ├── ARSessionManager.swift     ARKit config (LiDAR + high-res)
│   ├── LabelAnchorManager.swift   3D world labels + 2D HUD fallback
│   ├── ModelService.swift         Lazy CoreML singleton
│   └── DebugOverlayManager.swift  Debug visualizations (#if DEBUG)
├── Detection/
│   ├── ClassificationService.swift  Vision + CoreML on cropped region
│   └── DepthService.swift           LiDAR depth sampling
└── Models/
    └── README.md                  ← download instructions
```

---

## Getting Started

### 1. Clone

```bash
git clone https://github.com/ironDoug/CircleDetectAR.git
cd CircleDetectAR
```

### 2. Download the Core ML model

```bash
bash Scripts/download_model.sh
```

This downloads `MobileNetV2.mlmodel` (~25 MB) from Apple's CDN into `CircleDetectAR/Models/`.

> **Alternatively:** visit [developer.apple.com/machine-learning/models](https://developer.apple.com/machine-learning/models/) and download any compatible `.mlmodel` manually.

### 3. Generate the Xcode project

```bash
xcodegen generate
```

### 4. Add the model to the Xcode target

1. Open `CircleDetectAR.xcodeproj` in Xcode
2. In the Project Navigator, drag `CircleDetectAR/Models/MobileNetV2.mlmodel` into the **Models** group
3. In the dialog, ensure **"Add to target: CircleDetectAR"** is checked

### 5. Build & run

Select your **iPhone 14 Pro Max** as the destination and press **⌘R**.

> AR requires a physical device. The app will not function on the Simulator.

---

## Usage

1. Open the app and **grant camera access** when prompted
2. Slowly pan your iPhone around the room until the coaching animation disappears
3. **Draw a closed circle** with your finger around any object on screen
4. A floating label appears in the world with the object name and confidence score
5. Labels auto-dismiss after ~4 seconds

### Tips

- Use in good lighting for best accuracy
- Circle individual objects rather than groups
- Hold the device steady as you draw
- Optimal range: 0.5 – 3 metres from the object

### Debug overlay (DEBUG builds only)

Two-finger triple-tap cycles through:
`Off → Feature Points → Scene Mesh → All → Off`

---

## Running Tests

### Unit tests (Simulator)

```bash
xcodebuild test \
  -project CircleDetectAR.xcodeproj \
  -scheme CircleDetectAR \
  -only-testing:CircleDetectARTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

15 unit tests across `CircleGestureRecognizerTests`, `ClassificationServiceTests`, and `DepthServiceTests`.

### UI tests (Physical device required)

UI tests require a connected iPhone. Connect your device, trust it, then:

```bash
xcodebuild test \
  -project CircleDetectAR.xcodeproj \
  -scheme CircleDetectAR \
  -only-testing:CircleDetectARUITests \
  -destination 'id=<YOUR_DEVICE_UDID>'
```

Find your device UDID with `xcrun xctrace list devices`.

---

## Swapping the Model

The app uses **MobileNetV2** by default (image classification, 1000 ImageNet classes). To use a different model:

| Model | Type | Notes |
|---|---|---|
| MobileNetV2 | Classification | Default; fast, ~25 MB |
| ResNet50 | Classification | More accurate, ~100 MB |
| YOLOv3Tiny | Object Detection | Bounding boxes, ~34 MB |
| YOLOv3 | Object Detection | Best accuracy, ~248 MB |
| Custom (Create ML) | Either | Train in Xcode > Create ML |

1. Add your `.mlmodel` to `CircleDetectAR/Models/` and the Xcode target
2. Update `ModelService.swift` to use the new filename

---

## Architecture

```
ARViewController
    │
    ├── CircleGestureRecognizer  ← detects closed-loop touch path
    ├── CircleOverlayView        ← renders live stroke
    ├── ARSessionManager         ← configures & restarts ARKit session
    │
    ├── ClassificationService    ← Vision request on cropped pixel buffer
    │       └── ModelService     ← lazy singleton VNCoreMLModel
    │
    ├── DepthService             ← samples LiDAR depth at a screen point
    └── LabelAnchorManager       ← places/removes 3D AR labels
```

---

## Privacy

All image analysis runs **entirely on-device** using Apple's Core ML framework. No images, video frames, or classification results are transmitted to any external server or stored without explicit user action.

---

## License

MIT — see [LICENSE](LICENSE) for details.
