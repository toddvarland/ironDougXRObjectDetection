import XCTest
@testable import CircleDetectAR

final class ResultHistoryManagerTests: XCTestCase {

    private var manager: ResultHistoryManager!

    override func setUp() {
        super.setUp()
        manager = ResultHistoryManager(maxItems: 5)
    }

    private func makeItem(label: String = "cat", confidence: Float = 0.9) -> ResultItem {
        ResultItem(label: label, confidence: confidence, depth: nil, timestamp: Date())
    }

    // MARK: - Basic add / read

    func testAddSingleItem() {
        manager.add(makeItem(label: "dog"))
        XCTAssertEqual(manager.items.count, 1)
        XCTAssertEqual(manager.items.first?.label, "dog")
    }

    func testItemsOrderedNewestFirst() {
        manager.add(makeItem(label: "first"))
        manager.add(makeItem(label: "second"))
        XCTAssertEqual(manager.items[0].label, "second")
        XCTAssertEqual(manager.items[1].label, "first")
    }

    // MARK: - Cap

    func testHistoryCappedAtMaxItems() {
        for i in 1...7 { manager.add(makeItem(label: "item\(i)")) }
        XCTAssertEqual(manager.items.count, 5)
        // Newest items should be retained
        XCTAssertEqual(manager.items.first?.label, "item7")
    }

    // MARK: - Clear

    func testClearEmptiesList() {
        manager.add(makeItem())
        manager.clear()
        XCTAssertTrue(manager.items.isEmpty)
    }

    // MARK: - Notification posted on main thread

    func testAddPostsNotificationOnMainThread() {
        let expectation = XCTestExpectation(description: "Notification received on main thread")
        let token = NotificationCenter.default.addObserver(
            forName: .resultHistoryDidUpdate,
            object: nil,
            queue: nil
        ) { _ in
            XCTAssertTrue(Thread.isMainThread, "Notification must be on main thread")
            expectation.fulfill()
        }
        manager.add(makeItem())
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(token)
    }

    func testClearPostsNotificationOnMainThread() {
        let expectation = XCTestExpectation(description: "Clear notification on main thread")
        let token = NotificationCenter.default.addObserver(
            forName: .resultHistoryDidUpdate,
            object: nil,
            queue: nil
        ) { _ in
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        }
        manager.clear()
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(token)
    }

    // MARK: - ResultItem displayText

    func testDisplayTextWithoutDepth() {
        let item = ResultItem(label: "chair", confidence: 0.85, depth: nil, timestamp: Date())
        XCTAssertEqual(item.displayText, "chair (85%)")
    }

    func testDisplayTextWithDepth() {
        let item = ResultItem(label: "chair", confidence: 0.85, depth: 1.2, timestamp: Date())
        XCTAssertEqual(item.displayText, "chair (85%) · 1.2m")
    }
}
