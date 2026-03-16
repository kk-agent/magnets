import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let entry: MagnetsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.magnetName)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)

                    Text(entry.inviteCode)
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if entry.recentPosts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No posts yet.")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Create a Magnet in the app and your shared feed will appear here.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(entry.recentPosts.prefix(3))) { post in
                        LargeFeedRow(post: post)
                    }
                }
            }
        }
        .padding(18)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(hex: entry.latestPost?.backgroundColor ?? "#5A56F2"),
                    Color(hex: "#10131D"),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct LargeFeedRow: View {
    let post: WidgetPostSnapshot

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(post.displayText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack {
                    Text(post.authorName)
                    Spacer()
                    Text(post.createdAt, style: .time)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.66))
            }
        }
        .padding(12)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = SharedMediaStore.loadCGImage(from: post.mediaURL) {
            Image(decorative: image, scale: 1, orientation: .up)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: post.backgroundColor),
                            Color(hex: "#181A26"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Image(systemName: post.contentType == .aiGenerated ? "sparkles" : "text.bubble.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }
        }
    }
}
