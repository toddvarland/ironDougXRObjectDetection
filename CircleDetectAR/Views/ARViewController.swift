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

    /// "Draw a circle…" prompt shown after coaching completes and hidden after first use.
    private lazy var hintLabel: UILabel = {
        let label = UILabel()
        label.text = "Draw a circle around any object"
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        label.layer.cornerRadius = 14
        label.clipsToBounds = true
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// Whether the user has completed at least one successful circle gesture.
    private var hasCircledOnce = false

    /// Depth (metres) at the last circle centre — captured before async classify.
    private var lastCircleDepth: Float?

    /// Prevents stacking multiple "host unreachable" alerts if the user keeps drawing circles.
    private var isShowingRemoteErrorAlert = false

    #if DEBUG
    private var debugManager: DebugOverlayManager?
    #endif

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupOverlay()
        setupTrackingStatusLabel()
        setupHintLabel()
        setupGesture()
        setupCoachingOverlay()  // must come before toolbar so buttons sit above it
        setupToolbar()
        checkCameraPermission()
        impactFeedback.prepare()
        notificationFeedback.prepare()
        #if DEBUG
        setupDebugGesture()
        #endif
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
        #if DEBUG
        debugManager = DebugOverlayManager(arView: arView)
        #endif
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

    private func setupHintLabel() {
        view.addSubview(hintLabel)
        NSLayoutConstraint.activate([
            hintLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -68),
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.85),
            hintLabel.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupToolbar() {
        let historyButton = UIButton(type: .system)
        historyButton.setImage(UIImage(systemName: "clock"), for: .normal)
        historyButton.tintColor = .white
        historyButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        historyButton.layer.cornerRadius = 22
        historyButton.clipsToBounds = true
        historyButton.accessibilityLabel = "Detection History"
        historyButton.addTarget(self, action: #selector(showHistory), for: .touchUpInside)
        historyButton.translatesAutoresizingMaskIntoConstraints = false

        let settingsButton = UIButton(type: .system)
        settingsButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
        settingsButton.tintColor = .white
        settingsButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        settingsButton.layer.cornerRadius = 22
        settingsButton.clipsToBounds = true
        settingsButton.accessibilityLabel = "Settings"
        settingsButton.addTarget(self, action: #selector(showSettings), for: .touchUpInside)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(historyButton)
        view.addSubview(settingsButton)

        NSLayoutConstraint.activate([
            historyButton.widthAnchor.constraint(equalToConstant: 44),
            historyButton.heightAnchor.constraint(equalToConstant: 44),
            historyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            historyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            settingsButton.widthAnchor.constraint(equalToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 44),
            settingsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            settingsButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    @objc private func showHistory() {
        ResultHistoryViewController.show(from: self)
    }

    @objc private func showSettings() {
        SettingsViewController.show(from: self)
    }

    func showHint() {
        guard !hasCircledOnce else { return }
        UIView.animate(withDuration: 0.4) { self.hintLabel.alpha = 1 }
    }

    private func hideHintPermanently() {
        guard !hasCircledOnce else { return }
        hasCircledOnce = true
        UIView.animate(withDuration: 0.3) { self.hintLabel.alpha = 0 }
    }

    private func setupGesture() {
        let gesture = CircleGestureRecognizer(target: self,
                                              action: #selector(handleGestureStateChange(_:)))
        gesture.delegate = self
        view.addGestureRecognizer(gesture)
    }

    private func setupCoachingOverlay() {
        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.delegate = self
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coaching.frame = view.bounds
        coaching.goal = .anyPlane
        // Don't let the coaching overlay eat touches when it isn't active.
        // The delegate callbacks (below) toggle this as coaching starts/stops.
        coaching.isUserInteractionEnabled = false
        // Suppress during UI automation tests
        if CommandLine.arguments.contains("--uitesting") {
            coaching.isHidden = true
            showHint()
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
            if SettingsManager.shared.hapticsEnabled { impactFeedback.impactOccurred() }
            hideHintPermanently()
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

        // Capture LiDAR depth at circle centre
        lastCircleDepth = DepthService.readDepth(from: currentFrame,
                                                  at: lastCircleCenter,
                                                  viewSize: arView.bounds.size)

        if SettingsManager.shared.useRemoteInference {
            // ── Remote YOLO11 path ──────────────────────────────────────────
            RemoteInferenceService.shared.detect(in: arView, circleRect: rect) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let (label, confidence)):
                    self.handleInferenceResult(label: label, confidence: confidence)
                case .failure(let error):
                    self.handleRemoteInferenceError(error)
                }
            }
        } else {
            // ── On-device CoreML / Vision path ──────────────────────────────
            let viewSize = arView.bounds.size
            let normalizedROI = VNNormalizedRectForImageRect(rect,
                                                             Int(viewSize.width),
                                                             Int(viewSize.height))
            classificationService.classify(
                pixelBuffer: currentFrame.capturedImage,
                regionOfInterest: normalizedROI
            ) { [weak self] label, confidence in
                guard let self else { return }
                self.handleInferenceResult(label: label, confidence: confidence)
            }
        }
    }

    /// Common result handler shared by both inference paths (called on main thread).
    private func handleInferenceResult(label: String, confidence: Float) {
        // Respect confidence threshold
        guard confidence >= SettingsManager.shared.confidenceThreshold else { return }

        let depth = self.lastCircleDepth
        let item  = ResultItem(label: label,
                               confidence: confidence,
                               depth: SettingsManager.shared.showDepth ? depth : nil,
                               timestamp: Date())
        ResultHistoryManager.shared.add(item)
        anchorManager.placeLabel(item.displayText, at: lastCircleCenter, in: arView)
        if SettingsManager.shared.hapticsEnabled {
            notificationFeedback.notificationOccurred(.success)
        }
        UIAccessibility.post(notification: .announcement, argument: item.displayText)
    }

    /// Called on the main thread when the remote inference server is unreachable or returns an error.
    /// Shows a `UIAlertController` once at a time so repeated circles don't stack alerts.
    private func handleRemoteInferenceError(_ error: RemoteInferenceService.InferenceError) {
        guard !isShowingRemoteErrorAlert else { return }
        isShowingRemoteErrorAlert = true

        let title: String
        let message: String

        switch error {
        case .networkError(let underlying):
            title = "Remote Server Unreachable"
            let desc = (underlying as? URLError)?.localizedDescription ?? underlying.localizedDescription
            message = "Could not reach the inference server.\n\n\(desc)\n\nCheck that the server is running and the URL in Settings is correct."
        case .badResponse(let statusCode):
            title = "Server Error"
            message = "The inference server returned an unexpected response (HTTP \(statusCode)). Check the server logs."
        case .snapshotFailed:
            title = "Snapshot Failed"
            message = "Unable to capture the camera frame for remote inference."
        case .noDetections:
            // Not really an error worth alerting about — silently ignore.
            isShowingRemoteErrorAlert = false
            return
        case .decodingError:
            title = "Response Error"
            message = "The server response could not be decoded. The server may be running an incompatible version."
        }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Switch to On-Device", style: .default) { [weak self] _ in
            SettingsManager.shared.useRemoteInference = false
            self?.isShowingRemoteErrorAlert = false
        })
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel) { [weak self] _ in
            self?.isShowingRemoteErrorAlert = false
        })
        present(alert, animated: true)
    }

    // MARK: - Debug (DEBUG builds only)

    #if DEBUG
    private func setupDebugGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleDebugTripleTap(_:)))
        tap.numberOfTapsRequired = 3
        tap.numberOfTouchesRequired = 2   // two-finger triple-tap
        view.addGestureRecognizer(tap)
    }

    @objc private func handleDebugTripleTap(_ sender: UITapGestureRecognizer) {
        guard let manager = debugManager else { return }
        let state = manager.cycleState()
        let banner = UILabel()
        banner.text = "  \(state.label)  "
        banner.textColor = .white
        banner.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.85)
        banner.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        banner.layer.cornerRadius = 8
        banner.clipsToBounds = true
        banner.sizeToFit()
        banner.center = CGPoint(x: view.bounds.midX, y: view.safeAreaInsets.top + 60)
        view.addSubview(banner)
        UIView.animate(withDuration: 0.3, delay: 1.5, options: .curveEaseOut) {
            banner.alpha = 0
        } completion: { _ in
            banner.removeFromSuperview()
        }
    }
    #endif

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

// MARK: - ARCoachingOverlayViewDelegate

extension ARViewController: ARCoachingOverlayViewDelegate {

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        // Coaching finished — buttons should be tappable again.
        coachingOverlayView.isUserInteractionEnabled = false
        showHint()
    }

    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        // Coaching active — let the overlay receive touches so the user can interact with it.
        coachingOverlayView.isUserInteractionEnabled = true
        UIView.animate(withDuration: 0.3) { self.hintLabel.alpha = 0 }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ARViewController: UIGestureRecognizerDelegate {

    /// Allow the circle gesture to start — unless the touch lands on a UIControl
    /// (button, switch, etc.), in which case let the control handle it exclusively.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        // Walk up the hit-test chain; if we find a UIControl, refuse the touch.
        var hitView = touch.view
        while let v = hitView {
            if v is UIControl { return false }
            hitView = v.superview
        }
        return true
    }
}
