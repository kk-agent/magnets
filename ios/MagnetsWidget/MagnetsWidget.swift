import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

struct MagnetsWidget: Widget {
    private let kind = "MagnetsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MagnetsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Magnets")
        .description("Shared notes, photos, and AI moments on your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
        .pushHandler(MagnetsWidgetPushHandler.self)
    }
}

private struct MagnetsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: MagnetsEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            default:
                LargeWidgetView(entry: entry)
            }
        }
        .widgetURL(entry.destinationURL)
    }
}

struct WidgetSymbolImage: View {
    let primarySystemName: String
    let fallbackSystemName: String

    var body: some View {
        Image(systemName: resolvedSystemName)
    }

    private var resolvedSystemName: String {
#if canImport(UIKit)
        if UIImage(systemName: primarySystemName) != nil {
            return primarySystemName
        }

        if UIImage(systemName: fallbackSystemName) != nil {
            return fallbackSystemName
        }
#endif
        return fallbackSystemName
    }
}
