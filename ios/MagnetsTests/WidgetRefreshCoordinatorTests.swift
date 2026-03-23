import XCTest
@testable import Magnets

@MainActor
final class WidgetRefreshCoordinatorTests: XCTestCase {
    func testFirstRequestFiresImmediately() {
        let coordinator = WidgetRefreshCoordinator(minimumInterval: 15)

        XCTAssertNil(coordinator.lastRefreshDate)

        coordinator.requestRefresh()

        XCTAssertNotNil(coordinator.lastRefreshDate, "First request should fire immediately")
    }

    func testRapidRequestsDoNotUpdateLastRefreshDate() {
        let coordinator = WidgetRefreshCoordinator(minimumInterval: 15)

        coordinator.requestRefresh()
        let firstRefresh = coordinator.lastRefreshDate

        // Rapid follow-up should be coalesced, not fire immediately
        coordinator.requestRefresh()
        coordinator.requestRefresh()
        coordinator.requestRefresh()

        XCTAssertEqual(
            coordinator.lastRefreshDate,
            firstRefresh,
            "Rapid requests within the cooldown should not change lastRefreshDate synchronously"
        )
    }

    func testTrailingRefreshFiresAfterCooldown() async throws {
        let coordinator = WidgetRefreshCoordinator(minimumInterval: 0.2)

        coordinator.requestRefresh()
        let firstRefresh = try XCTUnwrap(coordinator.lastRefreshDate)

        // Queue a trailing refresh
        coordinator.requestRefresh()

        // Wait for trailing to fire
        try await Task.sleep(for: .seconds(0.4))

        let secondRefresh = try XCTUnwrap(coordinator.lastRefreshDate)
        XCTAssertGreaterThan(
            secondRefresh,
            firstRefresh,
            "Trailing refresh should fire after the cooldown expires"
        )
    }

    func testMinimumIntervalIsRespected() {
        let interval: TimeInterval = 30
        let coordinator = WidgetRefreshCoordinator(minimumInterval: interval)

        XCTAssertEqual(coordinator.minimumInterval, interval)
    }
}
