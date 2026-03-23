import SwiftData
import XCTest
@testable import Magnets

final class AgentConnectionTests: XCTestCase {

    // MARK: - AgentType

    func testAgentTypeDisplayNames() {
        XCTAssertEqual(AgentType.morningBriefing.displayName, "Morning Briefing")
        XCTAssertEqual(AgentType.dailyQuote.displayName, "Daily Quote")
        XCTAssertEqual(AgentType.weather.displayName, "Weather")
        XCTAssertEqual(AgentType.custom.displayName, "Custom")
    }

    func testAgentTypeSymbolNames() {
        XCTAssertEqual(AgentType.morningBriefing.symbolName, "sun.horizon.fill")
        XCTAssertEqual(AgentType.dailyQuote.symbolName, "quote.opening")
        XCTAssertEqual(AgentType.weather.symbolName, "cloud.sun.fill")
        XCTAssertEqual(AgentType.custom.symbolName, "sparkles")
    }

    func testAgentTypeDefaultPrompts() {
        // Predefined types have non-empty prompts
        XCTAssertFalse(AgentType.morningBriefing.defaultPrompt.isEmpty)
        XCTAssertFalse(AgentType.dailyQuote.defaultPrompt.isEmpty)
        XCTAssertFalse(AgentType.weather.defaultPrompt.isEmpty)

        // Custom type has empty default prompt
        XCTAssertTrue(AgentType.custom.defaultPrompt.isEmpty)
    }

    func testAgentTypeDefaultScheduleHours() {
        XCTAssertEqual(AgentType.weather.defaultScheduleHour, 7)
        XCTAssertEqual(AgentType.morningBriefing.defaultScheduleHour, 8)
        XCTAssertEqual(AgentType.dailyQuote.defaultScheduleHour, 9)
        XCTAssertEqual(AgentType.custom.defaultScheduleHour, 12)
    }

    func testAgentTypeRawValuesAreCloudKitSafe() {
        // Raw values must be plain strings (no spaces) for CloudKit
        for type in AgentType.allCases {
            XCTAssertFalse(type.rawValue.contains(" "), "\(type) rawValue contains spaces")
            // Must start with a lowercase letter (camelCase)
            let first = type.rawValue.first!
            XCTAssertTrue(first.isLowercase, "\(type) rawValue should start lowercase")
        }
    }

    func testAgentTypeIdentifiable() {
        // id should be the raw value for Identifiable conformance
        for type in AgentType.allCases {
            XCTAssertEqual(type.id, type.rawValue)
        }
    }

    func testAgentTypeCaseIterable() {
        XCTAssertEqual(AgentType.allCases.count, 4)
    }

    // MARK: - AgentSchedule

    func testAgentScheduleDisplayNames() {
        XCTAssertEqual(AgentSchedule.hourly.displayName, "Hourly")
        XCTAssertEqual(AgentSchedule.daily.displayName, "Daily")
        XCTAssertEqual(AgentSchedule.weekly.displayName, "Weekly")
    }

    func testAgentScheduleSymbolNames() {
        XCTAssertEqual(AgentSchedule.hourly.symbolName, "clock")
        XCTAssertEqual(AgentSchedule.daily.symbolName, "calendar")
        XCTAssertEqual(AgentSchedule.weekly.symbolName, "calendar.badge.clock")
    }

    func testAgentScheduleIdentifiable() {
        for schedule in AgentSchedule.allCases {
            XCTAssertEqual(schedule.id, schedule.rawValue)
        }
    }

    func testAgentScheduleCaseIterable() {
        XCTAssertEqual(AgentSchedule.allCases.count, 3)
    }

    // MARK: - AgentConnection defaults

    @MainActor
    func testAgentConnectionDefaults() throws {
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let magnet = Magnet(name: "Test Magnet")
        context.insert(magnet)

        let agent = AgentConnection(
            name: "Morning Bot",
            agentType: .morningBriefing,
            magnet: magnet
        )
        context.insert(agent)

        XCTAssertEqual(agent.name, "Morning Bot")
        XCTAssertEqual(agent.agentType, .morningBriefing)
        XCTAssertEqual(agent.schedule, .daily)
        XCTAssertEqual(agent.scheduledHour, 8, "Should use morningBriefing's default hour")
        XCTAssertEqual(agent.scheduledMinute, 0)
        XCTAssertTrue(agent.isEnabled)
        XCTAssertNil(agent.customPrompt)
        XCTAssertNil(agent.lastPostAt)
        XCTAssertNil(agent.lastPostPreview)
        XCTAssertNotNil(agent.magnet)
    }

    @MainActor
    func testAgentConnectionCustomSchedule() throws {
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let magnet = Magnet(name: "Family")
        context.insert(magnet)

        let agent = AgentConnection(
            name: "Weather Bot",
            agentType: .weather,
            schedule: .hourly,
            scheduledHour: 14,
            scheduledMinute: 30,
            magnet: magnet
        )
        context.insert(agent)

        XCTAssertEqual(agent.schedule, .hourly)
        XCTAssertEqual(agent.scheduledHour, 14)
        XCTAssertEqual(agent.scheduledMinute, 30)
    }

    // MARK: - effectivePrompt

    @MainActor
    func testEffectivePromptFallsBackToTypeDefault() throws {
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let magnet = Magnet(name: "Test")
        context.insert(magnet)

        let agent = AgentConnection(
            name: "Quote Bot",
            agentType: .dailyQuote,
            magnet: magnet
        )
        context.insert(agent)

        // No custom prompt → should use default
        XCTAssertEqual(agent.effectivePrompt, AgentType.dailyQuote.defaultPrompt)
    }

    @MainActor
    func testEffectivePromptUsesCustomWhenSet() throws {
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let magnet = Magnet(name: "Test")
        context.insert(magnet)

        let agent = AgentConnection(
            name: "Custom Bot",
            agentType: .custom,
            customPrompt: "Tell me a fun fact about Kansas.",
            magnet: magnet
        )
        context.insert(agent)

        XCTAssertEqual(agent.effectivePrompt, "Tell me a fun fact about Kansas.")
    }

    @MainActor
    func testEffectivePromptIgnoresWhitespaceOnlyCustom() throws {
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let magnet = Magnet(name: "Test")
        context.insert(magnet)

        let agent = AgentConnection(
            name: "Briefing Bot",
            agentType: .morningBriefing,
            customPrompt: "   \n  ",
            magnet: magnet
        )
        context.insert(agent)

        // Whitespace-only custom prompt should fall back to type default
        XCTAssertEqual(agent.effectivePrompt, AgentType.morningBriefing.defaultPrompt)
    }

    // MARK: - scheduleDescription

    @MainActor
    func testScheduleDescriptionDaily() throws {
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let magnet = Magnet(name: "Test")
        context.insert(magnet)

        let agent = AgentConnection(
            name: "Bot",
            agentType: .morningBriefing,
            schedule: .daily,
            scheduledHour: 8,
            scheduledMinute: 0,
            magnet: magnet
        )
        context.insert(agent)

        XCTAssertEqual(agent.scheduleDescription, "Daily at 8:00")
    }

    @MainActor
    func testScheduleDescriptionHourly() throws {
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let magnet = Magnet(name: "Test")
        context.insert(magnet)

        let agent = AgentConnection(
            name: "Bot",
            agentType: .weather,
            schedule: .hourly,
            magnet: magnet
        )
        context.insert(agent)

        XCTAssertEqual(agent.scheduleDescription, "Every hour")
    }

    @MainActor
    func testScheduleDescriptionWeekly() throws {
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let magnet = Magnet(name: "Test")
        context.insert(magnet)

        let agent = AgentConnection(
            name: "Bot",
            agentType: .dailyQuote,
            schedule: .weekly,
            scheduledHour: 10,
            scheduledMinute: 15,
            magnet: magnet
        )
        context.insert(agent)

        XCTAssertEqual(agent.scheduleDescription, "Weekly at 10:15")
    }

    // MARK: - Magnet ↔ Agent relationship

    @MainActor
    func testMagnetAgentsRelationship() throws {
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let magnet = Magnet(name: "Family Hub")
        context.insert(magnet)

        let agent1 = AgentConnection(name: "Morning", agentType: .morningBriefing, magnet: magnet)
        let agent2 = AgentConnection(name: "Weather", agentType: .weather, magnet: magnet)
        context.insert(agent1)
        context.insert(agent2)

        try context.save()

        XCTAssertEqual(magnet.agents.count, 2)
        XCTAssertTrue(magnet.agents.contains(where: { $0.name == "Morning" }))
        XCTAssertTrue(magnet.agents.contains(where: { $0.name == "Weather" }))
    }

    @MainActor
    func testDeletingMagnetCascadesToAgents() throws {
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let magnet = Magnet(name: "Ephemeral")
        context.insert(magnet)

        let agent = AgentConnection(name: "Bot", agentType: .custom, customPrompt: "Hello", magnet: magnet)
        context.insert(agent)
        try context.save()

        let agentID = agent.id

        context.delete(magnet)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<AgentConnection>())
        XCTAssertFalse(remaining.contains(where: { $0.id == agentID }),
                       "Agent should be cascade-deleted with its Magnet")
    }
}
