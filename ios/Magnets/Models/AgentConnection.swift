import Foundation
import SwiftData

// MARK: - Agent Type

/// The kind of automated content an agent produces.
/// Raw values are CloudKit-safe strings.
enum AgentType: String, Codable, CaseIterable, Sendable, Identifiable {
    case morningBriefing
    case dailyQuote
    case weather
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morningBriefing: return "Morning Briefing"
        case .dailyQuote: return "Daily Quote"
        case .weather: return "Weather"
        case .custom: return "Custom"
        }
    }

    var symbolName: String {
        switch self {
        case .morningBriefing: return "sun.horizon.fill"
        case .dailyQuote: return "quote.opening"
        case .weather: return "cloud.sun.fill"
        case .custom: return "sparkles"
        }
    }

    var defaultPrompt: String {
        switch self {
        case .morningBriefing:
            return "Write a warm, concise morning greeting. Keep it under 280 characters."
        case .dailyQuote:
            return "Share an inspiring quote with brief context. Keep it under 280 characters."
        case .weather:
            return "Summarize today's weather. Keep it under 280 characters."
        case .custom:
            return ""
        }
    }

    var defaultScheduleHour: Int {
        switch self {
        case .morningBriefing: return 8
        case .dailyQuote: return 9
        case .weather: return 7
        case .custom: return 12
        }
    }
}

// MARK: - Agent Schedule

/// How often the agent posts.
enum AgentSchedule: String, Codable, CaseIterable, Sendable, Identifiable {
    case hourly
    case daily
    case weekly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hourly: return "Hourly"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }

    var symbolName: String {
        switch self {
        case .hourly: return "clock"
        case .daily: return "calendar"
        case .weekly: return "calendar.badge.clock"
        }
    }
}

// MARK: - Agent Connection Model

/// An AI agent connected to a Magnet that posts content on a schedule.
@Model
final class AgentConnection {
    var id: UUID = UUID()
    var name: String = ""

    /// Stored as raw `String` for CloudKit compatibility.
    @Attribute(originalName: "agentType")
    private var agentTypeValue: String = AgentType.morningBriefing.rawValue

    @Attribute(originalName: "schedule")
    private var scheduleValue: String = AgentSchedule.daily.rawValue

    /// Hour (0-23) for scheduled delivery in the user's local time.
    var scheduledHour: Int = 8
    /// Minute (0-59) for scheduled delivery.
    var scheduledMinute: Int = 0

    var isEnabled: Bool = true
    var customPrompt: String?
    var lastPostAt: Date?
    var lastPostPreview: String?
    var createdAt: Date = Date.now

    // Optional parent for CloudKit lazy edge resolution.
    var magnet: Magnet?

    // MARK: - Computed Properties

    var agentType: AgentType {
        get { AgentType(rawValue: agentTypeValue) ?? .morningBriefing }
        set { agentTypeValue = newValue.rawValue }
    }

    var schedule: AgentSchedule {
        get { AgentSchedule(rawValue: scheduleValue) ?? .daily }
        set { scheduleValue = newValue.rawValue }
    }

    /// The prompt to use for content generation — falls back to the type default.
    var effectivePrompt: String {
        if let customPrompt, !customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customPrompt
        }
        return agentType.defaultPrompt
    }

    /// Human-readable schedule description.
    var scheduleDescription: String {
        let timeString = String(format: "%d:%02d", scheduledHour, scheduledMinute)
        switch schedule {
        case .hourly:
            return "Every hour"
        case .daily:
            return "Daily at \(timeString)"
        case .weekly:
            return "Weekly at \(timeString)"
        }
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        name: String,
        agentType: AgentType,
        schedule: AgentSchedule = .daily,
        scheduledHour: Int? = nil,
        scheduledMinute: Int = 0,
        isEnabled: Bool = true,
        customPrompt: String? = nil,
        magnet: Magnet
    ) {
        self.id = id
        self.name = name
        self.agentTypeValue = agentType.rawValue
        self.scheduleValue = schedule.rawValue
        self.scheduledHour = scheduledHour ?? agentType.defaultScheduleHour
        self.scheduledMinute = scheduledMinute
        self.isEnabled = isEnabled
        self.customPrompt = customPrompt
        self.createdAt = .now
        self.magnet = magnet
    }
}
