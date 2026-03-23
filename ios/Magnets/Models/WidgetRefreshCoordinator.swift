import Foundation
import WidgetKit

/// Debounces `WidgetCenter.shared.reloadAllTimelines()` calls to prevent iOS
/// from throttling widget refreshes during burst activity (rapid posts, agent
/// flows, widget quick-actions fired in succession).
///
/// Default minimum interval: 15 seconds. iOS internally throttles at roughly
/// once per minute, so coalescing on our side keeps us well within budget and
/// avoids silently dropped refreshes.
@MainActor
final class WidgetRefreshCoordinator {
    static let shared = WidgetRefreshCoordinator()

    /// Minimum seconds between actual `reloadAllTimelines()` calls.
    let minimumInterval: TimeInterval

    /// Timestamp of the last refresh that actually fired.
    private(set) var lastRefreshDate: Date?

    /// Whether a trailing refresh is already scheduled.
    private var pendingTask: Task<Void, Never>?

    init(minimumInterval: TimeInterval = 15) {
        self.minimumInterval = minimumInterval
    }

    /// Request a widget timeline reload. If the last reload was less than
    /// `minimumInterval` ago, the request is coalesced into a single trailing
    /// reload that fires when the interval expires.
    func requestRefresh() {
        let now = Date()

        if let last = lastRefreshDate, now.timeIntervalSince(last) < minimumInterval {
            // Still inside the cooldown — schedule a trailing refresh if
            // one isn't already pending.
            scheduleTrailingRefreshIfNeeded(from: last)
            return
        }

        // No recent refresh — fire immediately.
        fireRefresh(at: now)
    }

    // MARK: - Internal

    private func fireRefresh(at date: Date) {
        pendingTask?.cancel()
        pendingTask = nil
        lastRefreshDate = date
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func scheduleTrailingRefreshIfNeeded(from lastFire: Date) {
        guard pendingTask == nil else { return }

        let delay = minimumInterval - Date().timeIntervalSince(lastFire)

        pendingTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(delay, 0.1)))

            guard !Task.isCancelled, let self else { return }

            self.fireRefresh(at: Date())
        }
    }
}
