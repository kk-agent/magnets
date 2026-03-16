import Foundation
import SwiftData

enum PostContentType: String, Codable, CaseIterable, Sendable {
    case text
    case photo
    case aiGenerated
}

@Model
final class Post {
    var id: UUID
    var contentType: PostContentType
    var textContent: String?
    var mediaURL: String?
    var backgroundColor: String
    var createdAt: Date
    var magnet: Magnet

    init(
        id: UUID = UUID(),
        contentType: PostContentType,
        textContent: String? = nil,
        mediaURL: String? = nil,
        backgroundColor: String = MagnetPalette.randomPostHex(),
        createdAt: Date = .now,
        magnet: Magnet
    ) {
        self.id = id
        self.contentType = contentType
        self.textContent = textContent
        self.mediaURL = mediaURL
        self.backgroundColor = backgroundColor
        self.createdAt = createdAt
        self.magnet = magnet
    }
}

extension Post {
    var displayText: String {
        let trimmed = textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !trimmed.isEmpty {
            return trimmed
        }

        switch contentType {
        case .photo:
            return "Shared a photo"
        case .aiGenerated:
            return "AI update"
        case .text:
            return "New post"
        }
    }

    var authorDisplayName: String {
        magnet.ownerDisplayName
    }
}
