import XCTest
@testable import Magnets

final class AgentPostServiceTests: XCTestCase {

    // MARK: - Fallback Content Generation

    func testFallbackContentMorningBriefingIsNonEmpty() async throws {
        let text = try await AgentPostService.generateContentFromValues(
            prompt: "Write a morning greeting",
            agentType: .morningBriefing,
            magnetName: "Test Magnet"
        )
        XCTAssertFalse(text.isEmpty, "Morning briefing fallback should produce non-empty text")
    }

    func testFallbackContentDailyQuoteIsNonEmpty() async throws {
        let text = try await AgentPostService.generateContentFromValues(
            prompt: "Write a daily quote",
            agentType: .dailyQuote,
            magnetName: "Test Magnet"
        )
        XCTAssertFalse(text.isEmpty, "Daily quote fallback should produce non-empty text")
    }

    func testFallbackContentWeatherIsNonEmpty() async throws {
        let text = try await AgentPostService.generateContentFromValues(
            prompt: "Summarize today's weather",
            agentType: .weather,
            magnetName: "Test Magnet"
        )
        XCTAssertFalse(text.isEmpty, "Weather fallback should produce non-empty text")
    }

    func testFallbackContentCustomIsNonEmpty() async throws {
        let text = try await AgentPostService.generateContentFromValues(
            prompt: "Write something fun",
            agentType: .custom,
            magnetName: "Test Magnet"
        )
        XCTAssertFalse(text.isEmpty, "Custom fallback should produce non-empty text")
    }

    // MARK: - Error Cases

    func testEmptyPromptThrows() async {
        do {
            _ = try await AgentPostService.generateContentFromValues(
                prompt: "",
                agentType: .custom,
                magnetName: "Test"
            )
            XCTFail("Expected AgentPostError.emptyPrompt")
        } catch {
            XCTAssertEqual(
                (error as? AgentPostError),
                AgentPostError.emptyPrompt,
                "Should throw emptyPrompt for empty prompt string"
            )
        }
    }

    // MARK: - Error Descriptions

    func testAgentPostErrorDescriptions() {
        XCTAssertNotNil(AgentPostError.emptyPrompt.errorDescription)
        XCTAssertNotNil(AgentPostError.emptyResponse.errorDescription)
        XCTAssertNotNil(AgentPostError.noMagnetAttached.errorDescription)
    }

    func testAgentPostErrorEmptyPromptDescription() {
        let desc = AgentPostError.emptyPrompt.errorDescription ?? ""
        XCTAssertTrue(desc.lowercased().contains("prompt"), "Error description should mention prompt")
    }

    func testAgentPostErrorNoMagnetDescription() {
        let desc = AgentPostError.noMagnetAttached.errorDescription ?? ""
        XCTAssertTrue(desc.lowercased().contains("magnet"), "Error description should mention magnet")
    }
}

// Conform to Equatable for test assertions
extension AgentPostError: Equatable {
    public static func == (lhs: AgentPostError, rhs: AgentPostError) -> Bool {
        switch (lhs, rhs) {
        case (.emptyPrompt, .emptyPrompt): return true
        case (.emptyResponse, .emptyResponse): return true
        case (.noMagnetAttached, .noMagnetAttached): return true
        default: return false
        }
    }
}
