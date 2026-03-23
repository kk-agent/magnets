import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct AIComposeContext: Sendable {
    let magnetName: String
    let primaryColorHex: String
    let recentPostSnippets: [String]
}

enum AIComposePreset: String, CaseIterable, Identifiable {
    case morningGreeting
    case dailyQuote
    case summarizeRecent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morningGreeting:
            return "Morning greeting"
        case .dailyQuote:
            return "Daily quote"
        case .summarizeRecent:
            return "Summarize recent"
        }
    }

    var subtitle: String {
        switch self {
        case .morningGreeting:
            return "Generate a warm good-morning note for the widget."
        case .dailyQuote:
            return "Create a short inspirational line that feels fresh."
        case .summarizeRecent:
            return "Condense the latest posts into one quick recap."
        }
    }

    var iconName: String {
        switch self {
        case .morningGreeting:
            return "sun.max.fill"
        case .dailyQuote:
            return "quote.bubble.fill"
        case .summarizeRecent:
            return "text.redaction"
        }
    }

    func isEnabled(in context: AIComposeContext) -> Bool {
        switch self {
        case .summarizeRecent:
            return !context.recentPostSnippets.isEmpty
        case .morningGreeting, .dailyQuote:
            return true
        }
    }

    var disabledMessage: String {
        switch self {
        case .summarizeRecent:
            return "Share a few posts first so AI has something to summarize."
        case .morningGreeting, .dailyQuote:
            return ""
        }
    }
}

struct AIComposeAvailability: Equatable {
    enum State: Equatable {
        case available
        case unavailable(String)
        case unsupportedFramework
    }

    let state: State

    var shouldShowButton: Bool {
        state != .unsupportedFramework
    }

    var isAvailable: Bool {
        state == .available
    }

    var unavailableMessage: String? {
        guard case let .unavailable(message) = state else {
            return nil
        }

        return message
    }

    var helpText: String {
        switch state {
        case .available:
            return "Generate a short on-device draft."
        case let .unavailable(message):
            return message
        case .unsupportedFramework:
            return "Foundation Models isn’t available in this build."
        }
    }
}

enum AIComposeError: LocalizedError {
    case unavailable(String)
    case emptyCustomPrompt
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case let .unavailable(message):
            return message
        case .emptyCustomPrompt:
            return "Add a short custom prompt first."
        case .emptyResponse:
            return "The model returned an empty draft. Try again."
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 18.0, *)
extension AIComposeAvailability {
    init(systemAvailability: SystemLanguageModel.Availability) {
        switch systemAvailability {
        case .available:
            self.init(state: .available)
        case .unavailable(.deviceNotEligible):
            self.init(state: .unavailable("Requires Apple Intelligence on a supported device."))
        case .unavailable(.appleIntelligenceNotEnabled):
            self.init(state: .unavailable("Turn on Apple Intelligence to use AI Compose."))
        case .unavailable(.modelNotReady):
            self.init(state: .unavailable("Apple Intelligence is still getting ready."))
        @unknown default:
            self.init(state: .unavailable("Apple Intelligence isn’t available right now."))
        }
    }
}
#endif
