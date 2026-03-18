import Foundation
import SwiftData
import WidgetKit

struct WidgetPostSnapshot: Identifiable, Hashable {
    let id: UUID
    let contentType: PostContentType
    let textContent: String?
    let mediaURL: String?
    let backgroundColor: String
    let authorName: String
    let createdAt: Date

    init(
        id: UUID,
        contentType: PostContentType,
        textContent: String?,
        mediaURL: String?,
        backgroundColor: String,
        authorName: String,
        createdAt: Date
    ) {
        self.id = id
        self.contentType = contentType
        self.textContent = textContent
        self.mediaURL = mediaURL
        self.backgroundColor = backgroundColor
        self.authorName = authorName
        self.createdAt = createdAt
    }

    init(post: Post) {
        self.init(
            id: post.id,
            contentType: post.contentType,
            textContent: post.textContent,
            mediaURL: post.mediaURL,
            backgroundColor: post.backgroundColor,
            authorName: post.authorDisplayName,
            createdAt: post.createdAt
        )
    }

    var displayText: String {
        let trimmed = textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !trimmed.isEmpty {
            return trimmed
        }

        switch contentType {
        case .photo:
            return "Photo drop"
        case .aiGenerated:
            return "AI update"
        case .text:
            return "New post"
        }
    }
}

struct MagnetsEntry: TimelineEntry {
    let date: Date
    let magnetID: UUID?
    let magnetName: String
    let inviteCode: String
    let latestPost: WidgetPostSnapshot?
    let recentPosts: [WidgetPostSnapshot]

    var destinationURL: URL {
        if let magnetID {
            return MagnetsDeepLink.magnet(id: magnetID, inviteCode: inviteCode).url
        }

        return MagnetsDeepLink.home.url
    }

    static let placeholder = MagnetsEntry(
        date: .now,
        magnetID: UUID(),
        magnetName: "Weekend Crew",
        inviteCode: "MAGN3TS",
        latestPost: WidgetPostSnapshot(
            id: UUID(),
            contentType: .photo,
            textContent: "Sunset drop from the lake.",
            mediaURL: nil,
            backgroundColor: "#5A56F2",
            authorName: "You",
            createdAt: .now
        ),
        recentPosts: [
            WidgetPostSnapshot(
                id: UUID(),
                contentType: .photo,
                textContent: "Sunset drop from the lake.",
                mediaURL: nil,
                backgroundColor: "#5A56F2",
                authorName: "You",
                createdAt: .now
            ),
            WidgetPostSnapshot(
                id: UUID(),
                contentType: .text,
                textContent: "Dinner moved to 7:30.",
                mediaURL: nil,
                backgroundColor: "#FF6B6B",
                authorName: "You",
                createdAt: .now.addingTimeInterval(-1800)
            ),
            WidgetPostSnapshot(
                id: UUID(),
                contentType: .aiGenerated,
                textContent: "Agent summary: clear weather, easy drive, bring a jacket.",
                mediaURL: nil,
                backgroundColor: "#0AB8A2",
                authorName: "Orbit",
                createdAt: .now.addingTimeInterval(-3600)
            ),
        ]
    )

    static let empty = MagnetsEntry(
        date: .now,
        magnetID: nil,
        magnetName: "Magnets",
        inviteCode: "--------",
        latestPost: nil,
        recentPosts: []
    )
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> MagnetsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (MagnetsEntry) -> Void) {
        completion(loadEntry() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MagnetsEntry>) -> Void) {
        let entry = loadEntry() ?? .empty
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadEntry() -> MagnetsEntry? {
        do {
            let container = try SharedModelContainer.makeContainer()
            let context = ModelContext(container)

            var descriptor = FetchDescriptor<Magnet>(
                sortBy: [SortDescriptor(\Magnet.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 1

            guard let magnet = try context.fetch(descriptor).first else {
                return .empty
            }

            let posts = Array(magnet.sortedPosts.prefix(3)).map(WidgetPostSnapshot.init(post:))

            return MagnetsEntry(
                date: .now,
                magnetID: magnet.id,
                magnetName: magnet.name,
                inviteCode: magnet.inviteCode,
                latestPost: posts.first,
                recentPosts: posts
            )
        } catch {
            return .empty
        }
    }
}
