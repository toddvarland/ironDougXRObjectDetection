import Foundation
import CoreGraphics

/// A single object identification result.
struct ResultItem {
    let label: String
    let confidence: Float
    /// Distance to object in metres, if LiDAR data was available.
    let depth: Float?
    let timestamp: Date

    /// The formatted string shown in the AR label and history list.
    var displayText: String {
        var parts = ["\(label) (\(Int(confidence * 100))%)"]
        if let d = depth {
            parts.append("\(String(format: "%.1f", d))m")
        }
        return parts.joined(separator: " · ")
    }

    /// Short elapsed time string for history display ("just now", "5s ago", etc.)
    var relativeTime: String {
        let elapsed = Date().timeIntervalSince(timestamp)
        switch elapsed {
        case ..<2:    return "just now"
        case ..<60:   return "\(Int(elapsed))s ago"
        default:      return "\(Int(elapsed / 60))m ago"
        }
    }
}

/// Keeps a capped list of recent classification results.
/// All mutations are thread-safe (serialised on a private queue).
final class ResultHistoryManager {

    static let shared = ResultHistoryManager()
    private init() { self.maxItems = SettingsManager.shared.maxHistoryItems }

    /// Init for unit tests — pass an explicit cap instead of reading SettingsManager.
    init(maxItems: Int) { self.maxItems = maxItems }

    private let queue = DispatchQueue(label: "com.ironDoug.CircleDetectAR.resultHistory")
    private var _items: [ResultItem] = []
    private let maxItems: Int

    var items: [ResultItem] {
        queue.sync { _items }
    }

    func add(_ item: ResultItem) {
        queue.async { [weak self] in
            guard let self else { return }
            self._items.insert(item, at: 0)
            if self._items.count > self.maxItems {
                self._items = Array(self._items.prefix(self.maxItems))
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .resultHistoryDidUpdate, object: nil)
            }
        }
    }

    func clear() {
        queue.async { [weak self] in
            self?._items.removeAll()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .resultHistoryDidUpdate, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let resultHistoryDidUpdate = Notification.Name("com.ironDoug.CircleDetectAR.resultHistoryDidUpdate")
}
