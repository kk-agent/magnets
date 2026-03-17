import Foundation
import WidgetKit

@available(iOS 26.0, *)
struct MagnetsWidgetPushHandler: WidgetPushHandler {
    init() {}

    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {
        // Phase 2A persists the token locally so the app can inspect it now and
        // Phase 2B can forward the same state to CloudKit or a push broker.
        WidgetPushStateStore.update(pushToken: pushInfo.token, widgets: widgets)
    }
}
