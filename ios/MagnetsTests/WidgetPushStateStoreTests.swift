import Foundation
import Testing
@testable import Magnets

@Suite(.serialized)
struct WidgetPushStateStoreTests {
    @Test
    func updatePreservesExistingTokenWhenNilTokenProvided() throws {
        cleanupStoreFileIfNeeded()
        defer { cleanupStoreFileIfNeeded() }

        let initialDate = Date(timeIntervalSince1970: 1_717_171_700)
        let updatedDate = Date(timeIntervalSince1970: 1_717_171_800)

        _ = WidgetPushStateStore.update(
            pushToken: Data([0x01, 0x02, 0x03]),
            widgets: nil,
            preserveExistingToken: false,
            now: initialDate
        )

        let updatedState = WidgetPushStateStore.update(
            pushToken: nil,
            widgets: nil,
            preserveExistingToken: true,
            now: updatedDate
        )

        #expect(updatedState.tokenHex?.isEmpty == false)
        #expect(updatedState.lastTokenUpdateAt == initialDate)
    }

    @Test
    func updateClearsTokenWhenPreserveExistingTokenIsFalse() throws {
        cleanupStoreFileIfNeeded()
        defer { cleanupStoreFileIfNeeded() }

        let initialDate = Date(timeIntervalSince1970: 1_717_171_700)

        _ = WidgetPushStateStore.update(
            pushToken: Data([0xAA, 0xBB, 0xCC]),
            widgets: nil,
            preserveExistingToken: false,
            now: initialDate
        )

        let clearedState = WidgetPushStateStore.update(
            pushToken: nil,
            widgets: nil,
            preserveExistingToken: false,
            now: initialDate.addingTimeInterval(10)
        )

        #expect(clearedState.tokenHex == nil)
    }

    @Test
    func updateRefreshesTimestampWhenTokenChanges() throws {
        cleanupStoreFileIfNeeded()
        defer { cleanupStoreFileIfNeeded() }

        let initialDate = Date(timeIntervalSince1970: 1_717_171_700)
        let nextDate = Date(timeIntervalSince1970: 1_717_171_900)

        _ = WidgetPushStateStore.update(
            pushToken: Data([0x01, 0x02, 0x03]),
            widgets: nil,
            preserveExistingToken: false,
            now: initialDate
        )

        let updatedState = WidgetPushStateStore.update(
            pushToken: Data([0x04, 0x05, 0x06]),
            widgets: nil,
            preserveExistingToken: true,
            now: nextDate
        )

        #expect(updatedState.lastTokenUpdateAt == nextDate)
    }

    private func cleanupStoreFileIfNeeded() {
        let fileURL = WidgetPushStateStore.fileURL
        try? FileManager.default.removeItem(at: fileURL)
    }
}
