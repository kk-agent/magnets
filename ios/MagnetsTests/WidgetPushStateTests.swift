import Foundation
import XCTest
@testable import Magnets

final class WidgetPushStateTests: XCTestCase {
    func testEmptyStateHasNilTokenAndNoWidgets() {
        XCTAssertNil(WidgetPushState.empty.tokenHex)
        XCTAssertNil(WidgetPushState.empty.lastTokenUpdateAt)
        XCTAssertTrue(WidgetPushState.empty.widgets.isEmpty)
    }

    func testCodableRoundTripPreservesValue() throws {
        let state = WidgetPushState(
            tokenHex: "00112233445566778899AABBCCDDEEFF",
            lastTokenUpdateAt: Date(timeIntervalSince1970: 1_717_171_700),
            widgets: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let encoded = try encoder.encode(state)
        let decoded = try decoder.decode(WidgetPushState.self, from: encoded)

        XCTAssertEqual(decoded, state)
    }

    func testTokenPreviewTruncatesLongTokens() {
        let state = WidgetPushState(
            tokenHex: "1234567890abcdef1234567890abcdef",
            lastTokenUpdateAt: nil,
            widgets: []
        )

        XCTAssertEqual(state.tokenPreview, "12345678…90abcdef")
    }

    func testHasPushTokenMatchesTokenPresence() {
        let nilTokenState = WidgetPushState(tokenHex: nil, lastTokenUpdateAt: nil, widgets: [])
        let emptyTokenState = WidgetPushState(tokenHex: "", lastTokenUpdateAt: nil, widgets: [])
        let validTokenState = WidgetPushState(tokenHex: "abcd", lastTokenUpdateAt: nil, widgets: [])

        XCTAssertFalse(nilTokenState.hasPushToken)
        XCTAssertFalse(emptyTokenState.hasPushToken)
        XCTAssertTrue(validTokenState.hasPushToken)
    }
}
