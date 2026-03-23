import Foundation
import SwiftData

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Handles generating AI content and creating posts for connected agents.
/// Uses on-device Foundation Models when available, with a curated fallback
/// for Simulator and devices without Apple Intelligence.
enum AgentPostService {

    // MARK: - Content Generation

    /// Generate content using on-device AI or a curated fallback.
    /// All parameters are plain Sendable values — safe to call from any isolation domain.
    static func generateContentFromValues(
        prompt: String,
        agentType: AgentType,
        magnetName: String
    ) async throws -> String {
        guard !prompt.isEmpty else {
            throw AgentPostError.emptyPrompt
        }

        #if canImport(FoundationModels)
        if #available(iOS 18.0, *) {
            let availability = SystemLanguageModel.default.availability
            if availability == .available {
                do {
                    return try await generateWithFoundationModels(
                        prompt: prompt,
                        magnetName: magnetName
                    )
                } catch {
                    // Foundation Models available but generation failed (e.g. Simulator
                    // without an on-device model). Fall through to curated content.
                    #if DEBUG
                    print("⚠️ Foundation Models generation failed, using fallback: \(error)")
                    #endif
                }
            }
        }
        #endif

        return generateFallbackContent(for: agentType)
    }

    #if canImport(FoundationModels)
    @available(iOS 18.0, *)
    private static func generateWithFoundationModels(
        prompt: String,
        magnetName: String
    ) async throws -> String {
        let session = LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: """
            You are an AI agent posting to a shared widget called \(magnetName) \
            in the Magnets app. Write one short, natural post. Keep it under 220 \
            characters. Return only the final text with no title, bullets, or \
            quotation marks.
            """
        )

        let response = try await session.respond(to: prompt)
        let trimmed = response.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\u{201C}\u{201D}\u{0022}"))

        guard !trimmed.isEmpty else {
            throw AgentPostError.emptyResponse
        }

        return trimmed
    }
    #endif

    /// Curated fallback content when Foundation Models is unavailable.
    private static func generateFallbackContent(for agentType: AgentType) -> String {
        switch agentType {
        case .morningBriefing:
            return [
                "Good morning! ☀️ Hope today brings something great.",
                "Rise and shine! 🌅 New day, new possibilities.",
                "Morning! ☕ Here's to making today count.",
                "Hey, good morning! 🌞 Let's make it a good one.",
                "Top of the morning! 🌻 Let's do something we're proud of today.",
            ].randomElement()!
        case .dailyQuote:
            return [
                "\"The best time to plant a tree was 20 years ago. The second best time is now.\"",
                "\"Do something today that your future self will thank you for.\"",
                "\"Small steps every day lead to big changes over time.\"",
                "\"The only way to do great work is to love what you do.\"",
                "\"What you do makes a difference, and you have to decide what kind of difference you want to make.\"",
            ].randomElement()!
        case .weather:
            return "🌤 Check your local forecast — stay prepared for whatever the day brings!"
        case .custom:
            return "✨ A moment from your Magnets agent."
        }
    }

    // MARK: - Local Post Creation

    /// Run an agent: generate content and create a local Post in SwiftData.
    /// Returns the generated text on success.
    @MainActor
    static func runAgentLocally(
        _ agent: AgentConnection,
        in context: ModelContext
    ) async throws -> String {
        guard let magnet = agent.magnet else {
            throw AgentPostError.noMagnetAttached
        }

        // Capture values from the model on the main actor before crossing isolation.
        let prompt = agent.effectivePrompt
        let agentType = agent.agentType
        let magnetName = magnet.name
        let generatedText = try await generateContentFromValues(
            prompt: prompt,
            agentType: agentType,
            magnetName: magnetName
        )

        let post = Post(
            contentType: .aiGenerated,
            textContent: generatedText,
            backgroundColor: MagnetPalette.randomPostHex(),
            magnet: magnet
        )

        context.insert(post)
        try context.save()

        // Update agent metadata.
        agent.lastPostAt = .now
        agent.lastPostPreview = String(generatedText.prefix(100))
        try context.save()

        // Trigger widget refresh through the debounced coordinator.
        WidgetRefreshCoordinator.shared.requestRefresh()

        return generatedText
    }
}

// MARK: - Errors

enum AgentPostError: LocalizedError {
    case emptyPrompt
    case emptyResponse
    case noMagnetAttached

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            return "Agent has no prompt configured."
        case .emptyResponse:
            return "The AI model returned an empty response."
        case .noMagnetAttached:
            return "Agent is not connected to a Magnet."
        }
    }
}
