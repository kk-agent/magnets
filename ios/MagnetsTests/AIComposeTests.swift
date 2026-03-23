import XCTest
@testable import Magnets

final class AIComposeTests: XCTestCase {
    func testAvailabilityAvailableState() {
        let availability = AIComposeAvailability(state: .available)

        XCTAssertTrue(availability.isAvailable)
        XCTAssertTrue(availability.shouldShowButton)
        XCTAssertNil(availability.unavailableMessage)
    }

    func testAvailabilityUnavailableState() {
        let availability = AIComposeAvailability(state: .unavailable("msg"))

        XCTAssertFalse(availability.isAvailable)
        XCTAssertTrue(availability.shouldShowButton)
        XCTAssertEqual(availability.unavailableMessage, "msg")
    }

    func testAvailabilityUnsupportedFrameworkState() {
        let availability = AIComposeAvailability(state: .unsupportedFramework)

        XCTAssertFalse(availability.isAvailable)
        XCTAssertFalse(availability.shouldShowButton)
        XCTAssertNil(availability.unavailableMessage)
    }

    func testAvailabilityHelpTextForEachState() {
        XCTAssertEqual(
            AIComposeAvailability(state: .available).helpText,
            "Generate a short on-device draft."
        )
        XCTAssertEqual(
            AIComposeAvailability(state: .unavailable("msg")).helpText,
            "msg"
        )
        XCTAssertEqual(
            AIComposeAvailability(state: .unsupportedFramework).helpText,
            "Foundation Models isn’t available in this build."
        )
    }

    func testSummarizeRecentRequiresRecentPosts() {
        let emptyContext = AIComposeContext(
            magnetName: "Kitchen",
            primaryColorHex: "#FFAA00",
            recentPostSnippets: []
        )
        let populatedContext = AIComposeContext(
            magnetName: "Kitchen",
            primaryColorHex: "#FFAA00",
            recentPostSnippets: ["Coffee is ready"]
        )

        XCTAssertFalse(AIComposePreset.summarizeRecent.isEnabled(in: emptyContext))
        XCTAssertTrue(AIComposePreset.summarizeRecent.isEnabled(in: populatedContext))
    }

    func testAlwaysEnabledPresetsIgnoreRecentPosts() {
        let context = AIComposeContext(
            magnetName: "Kitchen",
            primaryColorHex: "#FFAA00",
            recentPostSnippets: []
        )

        XCTAssertTrue(AIComposePreset.morningGreeting.isEnabled(in: context))
        XCTAssertTrue(AIComposePreset.dailyQuote.isEnabled(in: context))
    }

    func testDisabledMessageOnlyExistsForSummarizeRecent() {
        XCTAssertEqual(
            AIComposePreset.summarizeRecent.disabledMessage,
            "Share a few posts first so AI has something to summarize."
        )
        XCTAssertTrue(AIComposePreset.morningGreeting.disabledMessage.isEmpty)
        XCTAssertTrue(AIComposePreset.dailyQuote.disabledMessage.isEmpty)
    }

    func testAIComposeErrorDescriptions() {
        XCTAssertEqual(
            AIComposeError.unavailable("Nope").errorDescription,
            "Nope"
        )
        XCTAssertEqual(
            AIComposeError.emptyCustomPrompt.errorDescription,
            "Add a short custom prompt first."
        )
        XCTAssertEqual(
            AIComposeError.emptyResponse.errorDescription,
            "The model returned an empty draft. Try again."
        )
    }
}
