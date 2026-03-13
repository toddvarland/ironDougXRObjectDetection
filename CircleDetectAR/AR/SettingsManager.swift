import Foundation

/// Persistent user preferences backed by UserDefaults.
/// Access settings from anywhere via `SettingsManager.shared`.
final class SettingsManager {

    static let shared = SettingsManager()
    private init() { self.defaults = .standard }

    /// Designated init for testing with a custom UserDefaults suite.
    init(defaults: UserDefaults) { self.defaults = defaults }

    private let defaults: UserDefaults

    // MARK: - Keys

    private enum Key: String {
        case showDepth             = "com.ironDoug.CircleDetectAR.showDepth"
        case confidenceThreshold   = "com.ironDoug.CircleDetectAR.confidenceThreshold"
        case hapticsEnabled        = "com.ironDoug.CircleDetectAR.hapticsEnabled"
        case maxHistoryItems       = "com.ironDoug.CircleDetectAR.maxHistoryItems"
        case useRemoteInference    = "com.ironDoug.CircleDetectAR.useRemoteInference"
        case remoteServerURL       = "com.ironDoug.CircleDetectAR.remoteServerURL"
    }

    // MARK: - Settings

    /// Append distance (from LiDAR) to the result label. Default: true.
    var showDepth: Bool {
        get { defaults.object(forKey: Key.showDepth.rawValue) == nil
                ? true
                : defaults.bool(forKey: Key.showDepth.rawValue) }
        set { defaults.set(newValue, forKey: Key.showDepth.rawValue) }
    }

    /// Minimum model confidence (0.0 – 1.0) to show a result. Default: 0.15.
    var confidenceThreshold: Float {
        get {
            let stored = defaults.float(forKey: Key.confidenceThreshold.rawValue)
            return stored == 0 ? 0.15 : stored
        }
        set { defaults.set(newValue, forKey: Key.confidenceThreshold.rawValue) }
    }

    /// Whether haptic feedback is enabled. Default: true.
    var hapticsEnabled: Bool {
        get { defaults.object(forKey: Key.hapticsEnabled.rawValue) == nil
                ? true
                : defaults.bool(forKey: Key.hapticsEnabled.rawValue) }
        set { defaults.set(newValue, forKey: Key.hapticsEnabled.rawValue) }
    }

    /// Number of recent results kept in ResultHistoryManager. Default: 20.
    var maxHistoryItems: Int {
        get {
            let stored = defaults.integer(forKey: Key.maxHistoryItems.rawValue)
            return stored == 0 ? 20 : stored
        }
        set { defaults.set(newValue, forKey: Key.maxHistoryItems.rawValue) }
    }

    /// Route classifications to the remote YOLO11 server instead of on-device CoreML. Default: false.
    var useRemoteInference: Bool {
        get { defaults.object(forKey: Key.useRemoteInference.rawValue) == nil
                ? false
                : defaults.bool(forKey: Key.useRemoteInference.rawValue) }
        set { defaults.set(newValue, forKey: Key.useRemoteInference.rawValue) }
    }

    /// Base URL of the YOLO11 inference server. Default: http://192.168.194.196:8000
    var remoteServerURL: String {
        get {
            let stored = defaults.string(forKey: Key.remoteServerURL.rawValue) ?? ""
            return stored.isEmpty ? "http://192.168.194.196:8000" : stored
        }
        set { defaults.set(newValue, forKey: Key.remoteServerURL.rawValue) }
    }
}
