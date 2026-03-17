import SwiftUI
import WidgetKit

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
