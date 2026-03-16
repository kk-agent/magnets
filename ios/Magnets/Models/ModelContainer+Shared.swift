import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import SwiftUI

enum SharedModelContainer {
    static let appGroupID = "group.com.magnets.shared"
    static let schema = Schema([
        Magnet.self,
        Post.self,
        MagnetMember.self,
    ])

    static let shared: ModelContainer = {
        do {
            return try makeContainer()
        } catch {
            fatalError("Unable to create Magnets model container: \(error)")
        }
    }()

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration

        if inMemory {
            configuration = ModelConfiguration(
                "Magnets",
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(
                "Magnets",
                schema: schema,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .none
            )
        }

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static var groupContainerURL: URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            fatalError("Missing App Group container for \(appGroupID)")
        }

        return url
    }
}

enum SharedMediaStore {
    static let mediaFolderName = "Media"

    static func saveImageData(_ data: Data) throws -> String {
        let directoryURL = SharedModelContainer.groupContainerURL
            .appendingPathComponent(mediaFolderName, isDirectory: true)

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let fileName = "\(UUID().uuidString.lowercased()).jpg"
        let fileURL = directoryURL.appendingPathComponent(fileName, isDirectory: false)

        try data.write(to: fileURL, options: .atomic)
        return "\(mediaFolderName)/\(fileName)"
    }

    static func fileURL(for relativePath: String?) -> URL? {
        guard let relativePath, !relativePath.isEmpty else {
            return nil
        }

        return SharedModelContainer.groupContainerURL.appendingPathComponent(relativePath)
    }

    static func loadCGImage(from relativePath: String?) -> CGImage? {
        guard let fileURL = fileURL(for: relativePath),
              let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil)
        else {
            return nil
        }

        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    }
}

enum MagnetPalette {
    static let postColors = [
        "#5A56F2",
        "#FF6B6B",
        "#0AB8A2",
        "#F9A826",
        "#3E8BFF",
        "#FF5F9E",
    ]

    static func randomPostHex() -> String {
        postColors.randomElement() ?? "#5A56F2"
    }
}

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(sanitized, radix: 16) ?? 0

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        switch sanitized.count {
        case 8:
            red = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue = Double((value >> 8) & 0xFF) / 255
            alpha = Double(value & 0xFF) / 255
        default:
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
            alpha = 1
        }

        self = Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
