import WidgetKit

@available(iOS 26.0, *)
struct MagnetsWidgetPushHandler: WidgetPushHandler {
    init() {}

    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {
        // Phase 2 will register this token with the backend so pushes can refresh widgets instantly.
    }
}
