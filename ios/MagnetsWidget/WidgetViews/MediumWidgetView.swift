import AppIntents
import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: MagnetsEntry

    var body: some View {
        HStack(spacing: 14) {
            heroPanel
                .frame(width: 118)

            VStack(alignment: .leading, spacing: 10) {
                Text(entry.magnetName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)

                if let post = entry.latestPost {
                    Text(post.displayText)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(3)

                    Spacer(minLength: 0)

                    HStack {
                        Label(post.authorName, systemImage: "person.crop.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.78))

                        Spacer()

                        Text(post.createdAt, style: .time)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))
                    }
                } else {
                    Spacer(minLength: 0)

                    Text("Add a first note or photo to light up the widget.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(3)

                    Spacer(minLength: 0)
                }

                if let magnetID = entry.magnetID {
                    quickPostButton(for: magnetID)
                }
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            background
        }
    }

    @ViewBuilder
    private var heroPanel: some View {
        if let post = entry.latestPost, let image = SharedMediaStore.loadCGImage(from: post.mediaURL, maxPixelSize: 520) {
            Image(decorative: image, scale: 1, orientation: .up)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else if let post = entry.latestPost {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: post.contentType == .aiGenerated ? "sparkles" : "quote.bubble.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Text(post.displayText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(5)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: post.backgroundColor),
                        Color(hex: "#181A26"),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.12))
                .overlay {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(hex: entry.latestPost?.backgroundColor ?? "#5A56F2"),
                Color(hex: "#151723"),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func quickPostButton(for magnetID: UUID) -> some View {
        Button(intent: PostToMagnetIntent(magnetID: magnetID.uuidString, quickMessage: "👋 Wave")) {
            HStack(spacing: 10) {
                Text("Quick post")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                Image(systemName: "paperplane.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
