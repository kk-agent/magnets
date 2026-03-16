import Foundation
import SwiftData

enum MemberRole: String, Codable, CaseIterable, Sendable {
    case owner
    case member
    case agent
}

@Model
final class MagnetMember {
    var id: UUID
    var displayName: String
    var role: MemberRole
    var joinedAt: Date
    var magnet: Magnet

    init(
        id: UUID = UUID(),
        displayName: String,
        role: MemberRole,
        joinedAt: Date = .now,
        magnet: Magnet
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.joinedAt = joinedAt
        self.magnet = magnet
    }
}
