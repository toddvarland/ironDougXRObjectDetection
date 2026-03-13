import XCTest
@testable import CircleDetectAR

final class SettingsManagerTests: XCTestCase {

    // Use an isolated UserDefaults suite so tests don't stomp on real prefs.
    private var testDefaults: UserDefaults!
    private var manager: SettingsManager!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: #file)!
        testDefaults.removePersistentDomain(forName: #file)
        manager = SettingsManager(defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: #file)
        super.tearDown()
    }

    // MARK: - Default values

    func testDefaultShowDepthIsTrue() {
        XCTAssertTrue(manager.showDepth)
    }

    func testDefaultHapticsEnabledIsTrue() {
        XCTAssertTrue(manager.hapticsEnabled)
    }

    func testDefaultConfidenceThresholdIs15Percent() {
        XCTAssertEqual(manager.confidenceThreshold, 0.15, accuracy: 0.001)
    }

    func testDefaultMaxHistoryItemsIs20() {
        XCTAssertEqual(manager.maxHistoryItems, 20)
    }

    // MARK: - Persistence round-trips

    func testShowDepthPersists() {
        manager.showDepth = false
        XCTAssertFalse(manager.showDepth)
        manager.showDepth = true
        XCTAssertTrue(manager.showDepth)
    }

    func testHapticsEnabledPersists() {
        manager.hapticsEnabled = false
        XCTAssertFalse(manager.hapticsEnabled)
    }

    func testConfidenceThresholdPersists() {
        manager.confidenceThreshold = 0.40
        XCTAssertEqual(manager.confidenceThreshold, 0.40, accuracy: 0.001)
    }

    func testMaxHistoryItemsPersists() {
        manager.maxHistoryItems = 50
        XCTAssertEqual(manager.maxHistoryItems, 50)
    }
}
