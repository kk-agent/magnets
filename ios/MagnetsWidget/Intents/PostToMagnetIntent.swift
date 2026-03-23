import AppIntents
import Foundation
import SwiftData
import WidgetKit

struct PostToMagnetIntent: AppIntent {
    static let title: LocalizedStringResource = "Post to Magnet"
    static let description = IntentDescription("Adds a quick preset post to a Magnet without opening the app.")
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @Parameter(title: "Magnet ID")
    var magnetID: String

    @Parameter(title: "Quick Message")
    var quickMessage: String

    init() {}

    init(magnetID: String, quickMessage: String) {
        self.magnetID = magnetID
        self.quickMessage = quickMessage
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmedMessage = normalizedQuickMessage(quickMessage)

        guard !trimmedMessage.isEmpty else {
            return .result(dialog: IntentDialog("Quick post was empty."))
        }

        guard let magnetUUID = UUID(uuidString: magnetID) else {
            return .result(dialog: IntentDialog("That Magnet is unavailable right now."))
        }

        do {
            let container = try SharedModelContainer.makeContainer()
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<Magnet>(
                predicate: #Predicate { magnet in
                    magnet.id == magnetUUID
                }
            )

            guard let magnet = try context.fetch(descriptor).first else {
                return .result(dialog: IntentDialog("That Magnet could not be found."))
            }

            let post = Post(
                contentType: .text,
                textContent: trimmedMessage,
                backgroundColor: MagnetPalette.randomPostHex(),
                magnet: magnet
            )

            context.insert(post)
            try context.save()
            WidgetRefreshCoordinator.shared.requestRefresh()

            return .result(dialog: IntentDialog("Posted \(trimmedMessage) to \(magnet.name)."))
        } catch {
            return .result(dialog: IntentDialog("Couldn't post right now."))
        }
    }

    private func normalizedQuickMessage(_ message: String) -> String {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        switch trimmedMessage {
        case "👋":
            return "👋 Wave"
        case "❤️":
            return "❤️ Sent love"
        default:
            return trimmedMessage
        }
    }
}
