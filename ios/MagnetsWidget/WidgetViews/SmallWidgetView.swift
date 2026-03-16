import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: MagnetsEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let post = entry.latestPost, let image = SharedMediaStore.loadCGImage(from: post.mediaURL) {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFill()
                    .overlay(alignment: .bottomLeading) {
                        Text(post.displayText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.65)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
            } else if let post = entry.latestPost {
                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.magnetName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(1)

                    Spacer()

                    Text(post.displayText)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(5)
                }
                .padding(14)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Text("Create a Magnet and your latest post will glow here.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(5)
                }
                .padding(14)
            }
        }
        .containerBackground(for: .widget) {
            background
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(hex: entry.latestPost?.backgroundColor ?? "#5A56F2"),
                Color(hex: "#1A1C28"),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
