import CloudKit
import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

enum SharedModelContainer {
    static let appGroupID = "group.com.magnets.shared"
    static let cloudKitContainerIdentifier = "iCloud.com.groupthinking.magnets"
    static let schema = Schema([
        Magnet.self,
        Post.self,
        MagnetMember.self,
        AgentConnection.self,
    ])

    static let shared: ModelContainer = {
        do {
            return try makeContainer()
        } catch {
            fatalError("Unable to create Magnets model container: \(error)")
        }
    }()

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let prefersCloudKit = shouldUseCloudKit(inMemory: inMemory)

        if prefersCloudKit {
            do {
                return try ModelContainer(
                    for: schema,
                    configurations: [configuration(inMemory: inMemory, cloudKitEnabled: true)]
                )
            } catch {
                #if DEBUG
                print(
                    """
                    ⚠️ CloudKit store setup failed for \(cloudKitContainerIdentifier). \
                    Falling back to the shared local store until the Apple Developer \
                    container + entitlements are provisioned on a signed-in device: \(error)
                    """
                )
                #endif
            }
        }

        do {
            return try ModelContainer(
                for: schema,
                configurations: [configuration(inMemory: inMemory, cloudKitEnabled: false)]
            )
        } catch {
            // Schema-incompatible store on disk — nuke it and retry once.
            print("⚠️ ModelContainer failed (\(error)). Deleting store and retrying…")
            deleteExistingStore()
            return try ModelContainer(
                for: schema,
                configurations: [configuration(inMemory: inMemory, cloudKitEnabled: false)]
            )
        }
    }

    /// Remove the on-disk SwiftData store so a fresh one can be created.
    private static func deleteExistingStore() {
        let storeName = "Magnets"
        let storeDir: URL

        if isAppGroupAvailable,
           let groupURL = FileManager.default.containerURL(
               forSecurityApplicationGroupIdentifier: appGroupID
           ) {
            storeDir = groupURL
        } else {
            storeDir = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        }

        let extensions = ["store", "store-shm", "store-wal"]
        for ext in extensions {
            let fileURL = storeDir.appendingPathComponent("\(storeName).\(ext)")
            try? FileManager.default.removeItem(at: fileURL)
        }

        // Also check the default SwiftData path
        let defaultDir = storeDir.appendingPathComponent("default.store")
        try? FileManager.default.removeItem(at: defaultDir)
    }

    /// Whether the App Group container is available in this process.
    /// Returns `false` for unsigned Simulator test hosts and CI builds.
    static var isAppGroupAvailable: Bool {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) != nil
    }

    static var groupContainerURL: URL {
        if let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            return url
        }

        // Fallback for Simulator test hosts without the App Group entitlement.
        // Uses the app's Documents directory so the rest of the code can proceed
        // without crashing; data won't be shared with the widget in this mode.
        #if DEBUG
        let fallback = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MagnetsFallbackGroup", isDirectory: true)
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
        #else
        fatalError("Missing App Group container for \(appGroupID)")
        #endif
    }

    private static func configuration(
        inMemory: Bool,
        cloudKitEnabled: Bool
    ) -> ModelConfiguration {
        if inMemory {
            return ModelConfiguration(
                "Magnets",
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        }

        let groupSetting: ModelConfiguration.GroupContainer =
            isAppGroupAvailable ? .identifier(appGroupID) : .automatic
        return ModelConfiguration(
            "Magnets",
            schema: schema,
            groupContainer: groupSetting,
            // SwiftData reads the actual iCloud container binding from entitlements.
            // The app + widget both need Apple Developer provisioning for
            // iCloud.com.groupthinking.magnets before device sync/sharing is real.
            cloudKitDatabase: cloudKitEnabled ? .automatic : .none
        )
    }

    private static func shouldUseCloudKit(inMemory: Bool) -> Bool {
        guard !inMemory else {
            return false
        }

        #if targetEnvironment(simulator)
        // Keep simulator builds on the deterministic local store until a signed-in
        // device is available to validate the real CloudKit path.
        return false
        #else
        return true
        #endif
    }
}

enum SharedMediaStore {
    static let mediaFolderName = "Media"
    nonisolated(unsafe) private static let imageCache: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>()
        cache.countLimit = 60
        return cache
    }()

    static func saveImageData(_ data: Data) throws -> String {
        let directoryURL = SharedModelContainer.groupContainerURL
            .appendingPathComponent(mediaFolderName, isDirectory: true)

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let fileExtension = preferredImageFileExtension(for: data)
        let fileName = "\(UUID().uuidString.lowercased()).\(fileExtension)"
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

    static func loadCGImage(from relativePath: String?, maxPixelSize: Int? = nil) -> CGImage? {
        guard let relativePath, let fileURL = fileURL(for: relativePath) else {
            return nil
        }

        let cacheKey = cacheKey(for: relativePath, maxPixelSize: maxPixelSize)
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }

        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            return nil
        }

        let image: CGImage?
        if let maxPixelSize {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            ]
            image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
        } else {
            image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        }

        if let image {
            imageCache.setObject(image, forKey: cacheKey)
        }

        return image
    }

    private static func cacheKey(for relativePath: String, maxPixelSize: Int?) -> NSString {
        let suffix = maxPixelSize.map { "thumb-\($0)" } ?? "full"
        return "\(relativePath)|\(suffix)" as NSString
    }

    private static func preferredImageFileExtension(for data: Data) -> String {
        guard
            let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
            let typeIdentifier = CGImageSourceGetType(imageSource),
            let fileExtension = UTType(typeIdentifier as String)?.preferredFilenameExtension
        else {
            return "jpg"
        }

        return fileExtension.lowercased()
    }
}

enum CloudKitSyncStatus: Equatable, Sendable {
    case localOnly
    case checking
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case unavailable(String?)

    var symbolName: String {
        switch self {
        case .localOnly:
            return "icloud.slash"
        case .checking:
            return "icloud"
        case .available:
            return "icloud.fill"
        case .noAccount:
            return "person.crop.circle.badge.exclamationmark"
        case .restricted:
            return "exclamationmark.icloud"
        case .temporarilyUnavailable:
            return "icloud.bolt"
        case .unavailable:
            return "icloud.slash"
        }
    }

    var tintColor: Color {
        switch self {
        case .available:
            return Color(hex: "#0AB8A2")
        case .checking:
            return Color(hex: "#3E8BFF")
        case .temporarilyUnavailable:
            return Color(hex: "#F9A826")
        case .localOnly, .noAccount, .restricted, .unavailable:
            return .secondary
        }
    }

    var shortLabel: String {
        switch self {
        case .localOnly:
            return "Local"
        case .checking:
            return "Checking"
        case .available:
            return "Synced"
        case .noAccount:
            return "No iCloud"
        case .restricted:
            return "Restricted"
        case .temporarilyUnavailable:
            return "Retrying"
        case .unavailable:
            return "Unavailable"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .localOnly:
            return "Cloud sync is using the simulator local fallback"
        case .checking:
            return "Checking CloudKit account status"
        case .available:
            return "CloudKit account is available"
        case .noAccount:
            return "No iCloud account is available for CloudKit"
        case .restricted:
            return "CloudKit access is restricted"
        case .temporarilyUnavailable:
            return "CloudKit is temporarily unavailable"
        case let .unavailable(reason):
            return reason ?? "CloudKit status is unavailable"
        }
    }
}

enum CloudKitStatusProbe {
    static func currentStatus() async -> CloudKitSyncStatus {
        #if targetEnvironment(simulator)
        return .localOnly
        #else
        let container = CKContainer(identifier: SharedModelContainer.cloudKitContainerIdentifier)

        return await withCheckedContinuation { continuation in
            container.accountStatus { accountStatus, error in
                if let error {
                    let nsError = error as NSError

                    if nsError.domain == CKErrorDomain,
                       nsError.code == CKError.notAuthenticated.rawValue {
                        continuation.resume(returning: .noAccount)
                        return
                    }

                    continuation.resume(
                        returning: .unavailable(error.localizedDescription.trimmedOrNil)
                    )
                    return
                }

                let status: CloudKitSyncStatus

                switch accountStatus {
                case .available:
                    status = .available
                case .noAccount:
                    status = .noAccount
                case .restricted:
                    status = .restricted
                case .temporarilyUnavailable:
                    status = .temporarilyUnavailable
                case .couldNotDetermine:
                    status = .unavailable("CloudKit could not determine account status.")
                @unknown default:
                    status = .unavailable("CloudKit returned an unknown account state.")
                }

                continuation.resume(returning: status)
            }
        }
        #endif
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
