import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import SwiftUI
import WidgetKit

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
        // Phase 2A keeps the live store local inside the shared App Group so the
        // Phase 1 build stays deterministic while the schema is shaped for CloudKit.
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

enum MagnetsDeepLink: Hashable, Sendable {
    static let scheme = "magnets"

    case home
    case magnet(id: UUID, inviteCode: String?)
    case join(inviteCode: String)

    init?(url: URL) {
        let pathSegments = url.pathComponents.filter { $0 != "/" }
        let lowercasedScheme = url.scheme?.lowercased()
        let lowercasedHost = url.host?.lowercased()
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if lowercasedScheme == Self.scheme {
            switch lowercasedHost {
            case nil, "", "home":
                self = .home
            case "magnet":
                guard let rawIdentifier = pathSegments.first,
                      let magnetID = UUID(uuidString: rawIdentifier)
                else {
                    return nil
                }

                let inviteCode = components?.queryItems?
                    .first(where: { $0.name == "invite" })?
                    .value?
                    .trimmedOrNil

                self = .magnet(id: magnetID, inviteCode: inviteCode)
            case "join":
                guard let inviteCode = pathSegments.first?.trimmedOrNil else {
                    return nil
                }

                self = .join(inviteCode: inviteCode)
            default:
                return nil
            }

            return
        }

        let routeHead = (pathSegments.first ?? url.host ?? "").lowercased()

        switch routeHead {
        case "", "home":
            self = .home
        case "magnet":
            guard pathSegments.count >= 2,
                  let magnetID = UUID(uuidString: pathSegments[1])
            else {
                return nil
            }

            let inviteCode = components?.queryItems?
                .first(where: { $0.name == "invite" })?
                .value?
                .trimmedOrNil

            self = .magnet(id: magnetID, inviteCode: inviteCode)
        case "join":
            let inviteCode = pathSegments.dropFirst().first ?? components?.queryItems?
                .first(where: { $0.name == "code" })?
                .value

            guard let inviteCode = inviteCode?.trimmedOrNil else {
                return nil
            }

            self = .join(inviteCode: inviteCode)
        default:
            return nil
        }
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme

        switch self {
        case .home:
            components.host = "home"
        case let .magnet(id, inviteCode):
            components.host = "magnet"
            components.path = "/\(id.uuidString.lowercased())"

            if let inviteCode {
                components.queryItems = [
                    URLQueryItem(name: "invite", value: inviteCode),
                ]
            }
        case let .join(inviteCode):
            components.host = "join"
            components.path = "/\(inviteCode)"
        }

        return components.url ?? URL(string: "\(Self.scheme)://home")!
    }
}

struct StoredWidgetConfiguration: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let kind: String
    let family: String
    let sequence: Int
    let configurationType: String?
    let configurationDescription: String?

    init(widgetInfo: WidgetInfo, sequence: Int) {
        let configurationDescription = widgetInfo.configuration.map { String(describing: $0) }

        self.id = "\(widgetInfo.kind)::\(widgetInfo.family)::\(sequence)"
        self.kind = widgetInfo.kind
        self.family = String(describing: widgetInfo.family)
        self.sequence = sequence
        self.configurationType = widgetInfo.configuration.map { NSStringFromClass(type(of: $0)) }
        self.configurationDescription = configurationDescription?.trimmedOrNil
    }
}

struct WidgetPushState: Codable, Equatable, Sendable {
    var tokenHex: String?
    var lastTokenUpdateAt: Date?
    var widgets: [StoredWidgetConfiguration]

    static let empty = WidgetPushState(
        tokenHex: nil,
        lastTokenUpdateAt: nil,
        widgets: []
    )

    var hasPushToken: Bool {
        tokenHex?.isEmpty == false
    }

    var tokenPreview: String? {
        guard let tokenHex, tokenHex.count > 16 else {
            return tokenHex
        }

        return "\(tokenHex.prefix(8))…\(tokenHex.suffix(8))"
    }
}

enum WidgetPushStateStore {
    private static let fileName = "widget-push-state.json"

    static var fileURL: URL {
        SharedModelContainer.groupContainerURL.appendingPathComponent(fileName, isDirectory: false)
    }

    static func load() -> WidgetPushState {
        guard let data = try? Data(contentsOf: fileURL) else {
            return .empty
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return (try? decoder.decode(WidgetPushState.self, from: data)) ?? .empty
    }

    @discardableResult
    static func update(
        pushToken: Data?,
        widgets: [WidgetInfo]? = nil,
        preserveExistingToken: Bool = true,
        now: Date = .now
    ) -> WidgetPushState {
        let existingState = load()
        let storedWidgets = widgets.map { currentWidgets in
            currentWidgets.enumerated().map { index, widgetInfo in
                StoredWidgetConfiguration(widgetInfo: widgetInfo, sequence: index)
            }
        } ?? existingState.widgets

        let incomingTokenHex = pushToken?.hexString
        let effectiveTokenHex = incomingTokenHex ?? (preserveExistingToken ? existingState.tokenHex : nil)
        let didChangeToken = incomingTokenHex.map { $0 != existingState.tokenHex } ?? false

        let newState = WidgetPushState(
            tokenHex: effectiveTokenHex,
            lastTokenUpdateAt: didChangeToken ? now : existingState.lastTokenUpdateAt,
            widgets: storedWidgets
        )

        guard newState != existingState else {
            return existingState
        }

        save(newState)
        return newState
    }

    @discardableResult
    static func refreshFromSystem() async -> WidgetPushState {
        let currentPushInfo = await WidgetCenter.shared.currentPushInfo
        let widgets = try? await WidgetCenter.shared.currentConfigurations()

        return update(
            pushToken: currentPushInfo?.token,
            widgets: widgets,
            preserveExistingToken: true
        )
    }

    private static func save(_ state: WidgetPushState) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(state) else {
            return
        }

        try? data.write(to: fileURL, options: .atomic)
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

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private extension String {
    var trimmedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
