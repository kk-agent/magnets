import Foundation
import SwiftData

@Model
final class Magnet {
    var id: UUID = UUID()
    var name: String = ""
    var inviteCode: String = Magnet.makeInviteCode()
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Post.magnet)
    var posts: [Post] = []

    @Relationship(deleteRule: .cascade, inverse: \MagnetMember.magnet)
    var members: [MagnetMember] = []

    init(
        id: UUID = UUID(),
        name: String,
        inviteCode: String = Magnet.makeInviteCode(),
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
        self.createdAt = createdAt
    }
}

extension Magnet {
    var sortedPosts: [Post] {
        posts.sorted { $0.createdAt > $1.createdAt }
    }

    var inviteURL: URL {
        MagnetsDeepLink.join(inviteCode: inviteCode).url
    }

    var deepLinkURL: URL {
        MagnetsDeepLink.magnet(id: id, inviteCode: inviteCode).url
    }

    var inviteShareText: String {
        "Join \(name) on Magnets with invite code \(inviteCode)\n\(inviteURL.absoluteString)"
    }

    var recentPosts: [Post] {
        Array(sortedPosts.prefix(3))
    }

    var latestPost: Post? {
        sortedPosts.first
    }

    var ownerDisplayName: String {
        if let owner = members.first(where: { $0.role == .owner }) {
            return owner.displayName
        }

        return members.first?.displayName ?? "You"
    }

    var primaryColorHex: String {
        latestPost?.backgroundColor ?? MagnetPalette.postColors.first ?? "#5A56F2"
    }

    private static func makeInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<8).map { _ in alphabet.randomElement() ?? "M" })
    }

    /// Generate an invite code guaranteed unique among all existing Magnets in the given context.
    static func makeUniqueInviteCode(in context: ModelContext) throws -> String {
        let existingCodes = Set(
            try context.fetch(FetchDescriptor<Magnet>()).map {
                $0.inviteCode.uppercased()
            }
        )
        for _ in 0..<100 {
            let candidate = makeInviteCode()
            if !existingCodes.contains(candidate.uppercased()) {
                return candidate
            }
        }
        // Effectively unreachable with 32^8 ≈ 1.1T possibilities, but fail explicitly.
        return makeInviteCode()
    }
}
