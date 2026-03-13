import ARKit
import RealityKit
import Vision
import AVFoundation
import UIKit

/// Root view controller. Owns the ARView, overlay, gesture, and coordinates
/// classification + label display via the service/manager layer.
final class ARViewController: UIViewController {

    // MARK: - Properties

    private var arView: ARView!
    private var overlayView: CircleOverlayView!
    private var sessionManager: ARSessionManager!
    private let classificationService = ClassificationService()
    private let anchorManager = LabelAnchorManager()

    /// Centre point of the last completed circle gesture, in arView coordinates.
    private var lastCircleCenter: CGPoint = .zero

    /// Subtle status banner shown when tracking quality degrades.
    private lazy var trackingStatusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        label.font = .boldSystemFont(ofSize: 13)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupOverlay()
        setupTrackingStatusLabel()
        setupGesture()
        setupCoachingOverlay()
        checkCameraPermission()
        impactFeedback.prepare()
        notificationFeedback.prepare()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionManager.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionManager.pause()
    }

    // MARK: - Setup

    private func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.accessibilityIdentifier = "ARViewContainer"
        view.addSubview(arView)
        sessionManager = ARSessionManager(arView: arView)
        arView.session.delegate = self
    }

    private func setupOverlay() {
        overlayView = CircleOverlayView(frame: view.bounds)
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(overlayView)
    }

    private func setupTrackingStatusLabel() {
        view.addSubview(trackingStatusLabel)
        NSLayoutConstraint.activate([
            trackingStatusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            trackingStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            trackingStatusLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.9),
            trackingStatusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])
        trackingStatusLabel.layoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
    }

    private func setupGesture() {
        let gesture = CircleGestureRecognizer(target: self,
                                              action: #selector(handleGestureStateChange(_:)))
        view.addGestureRecognizer(gesture)
    }

    private func setupCoachingOverlay() {
        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coaching.frame = view.bounds
        coaching.goal = .anyPlane
        // Suppress during UI automation tests
        if CommandLine.arguments.contains("--uitesting") {
            coaching.isHidden = true
        }
        view.addSubview(coaching)
    }

    // MARK: - Gesture Handling

    @objc private func handleGestureStateChange(_ recognizer: CircleGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            overlayView.path = recognizer.circlePath

        case .ended:
            overlayView.path = nil
            impactFeedback.impactOccurred()   // short tap confirms gesture accepted
            processCircle(from: recognizer)

        case .failed, .cancelled:
            overlayView.path = nil

        default:
            break
        }
    }

    private func processCircle(from recognizer: CircleGestureRecognizer) {
        let rect = recognizer.boundingRect
        lastCircleCenter = CGPoint(x: rect.midX, y: rect.midY)

        guard let currentFrame = arView.session.currentFrame else { return }

        // Log depth to circled object if LiDAR is available
        if let depth = DepthService.readDepth(from: currentFrame,
                                               at: lastCircleCenter,
                                               viewSize: arView.bounds.size) {
            print("Depth to object: \(String(format: "%.2f", depth)) m")
        }

        // Convert screen rect → normalised Vision ROI
        let viewSize = arView.bounds.size
        let normalizedROI = VNNormalizedRectForImageRect(rect,
                                                         Int(viewSize.width),
                                                         Int(viewSize.height))

        classificationService.classify(
            pixelBuffer: currentFrame.capturedImage,
            regionOfInterest: normalizedROI
        ) { [weak self] label, confidence in
            guard let self else { return }
            let text = "\(label) (\(Int(confidence * 100))%)"
            self.anchorManager.placeLabel(text, at: self.lastCircleCenter, in: self.arView)
            self.notificationFeedback.notificationOccurred(.success)
            UIAccessibility.post(notification: .announcement, argument: text)
        }
    }

    // MARK: - Camera Permission

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if !granted {
                    DispatchQueue.main.async { self?.showCameraPermissionAlert() }
                }
            }
        default:
            showCameraPermissionAlert()
        }
    }

    private func showCameraPermissionAlert() {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "CircleDetectAR needs camera access to enable augmented reality. Please allow access in Settings.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - ARSessionDelegate

extension ARViewController: ARSessionDelegate {

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            hideTrackingStatus()
        case .notAvailable:
            showTrackingStatus("AR tracking unavailable", color: .systemRed)
        case .limited(let reason):
            showTrackingStatus(trackingMessage(for: reason), color: .systemOrange)
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        showTrackingStatus("AR session error — restarting…", color: .systemRed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.sessionManager.start()
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        showTrackingStatus("Session interrupted", color: .systemOrange)
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        hideTrackingStatus()
        sessionManager.start()
    }

    // MARK: Private helpers

    private func showTrackingStatus(_ message: String, color: UIColor) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.trackingStatusLabel.text = "  \(message)  "
            self.trackingStatusLabel.backgroundColor = color.withAlphaComponent(0.8)
            self.trackingStatusLabel.isHidden = false
        }
    }

    private func hideTrackingStatus() {
        DispatchQueue.main.async { [weak self] in
            self?.trackingStatusLabel.isHidden = true
        }
    }

    private func trackingMessage(for reason: ARCamera.TrackingState.Reason) -> String {
        switch reason {
        case .initializing:          return "Initializing AR…"
        case .relocalizing:          return "Relocalizing…"
        case .excessiveMotion:       return "Slow down — too much motion"
        case .insufficientFeatures:  return "Point at a textured surface"
        @unknown default:            return "Limited tracking"
        }
    }
}
