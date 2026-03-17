import Foundation
import SwiftData

enum MemberRole: String, Codable, CaseIterable, Sendable {
    case owner
    case member
    case agent
}

@Model
final class MagnetMember {
    var id: UUID = UUID()
    var displayName: String = ""
    @Attribute(originalName: "role")
    private var roleValue: String = MemberRole.owner.rawValue
    var joinedAt: Date = Date.now
    // Keep the parent relationship optional so CloudKit can hydrate records out of order later.
    var magnet: Magnet?

    var role: MemberRole {
        get { MemberRole(rawValue: roleValue) ?? .owner }
        set { roleValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        displayName: String,
        role: MemberRole,
        joinedAt: Date = .now,
        magnet: Magnet
    ) {
        self.id = id
        self.displayName = displayName
        self.roleValue = role.rawValue
        self.joinedAt = joinedAt
        self.magnet = magnet
    }
}
