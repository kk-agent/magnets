import CoreGraphics
import SwiftUI

struct PostRowView: View {
    let post: Post

    private var mediaImage: CGImage? {
        SharedMediaStore.loadCGImage(from: post.mediaURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.authorDisplayName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    Text(post.createdAt, style: .relative)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                if post.contentType == .aiGenerated {
                    Label("AI", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(.white.opacity(0.12), in: Capsule())
                }
            }

            if let mediaImage {
                Image(decorative: mediaImage, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }

            if let textContent = post.textContent, !textContent.isEmpty {
                Text(textContent)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Label(post.contentType.rawValue.capitalized, systemImage: iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))

                Spacer()

                Text(post.magnet?.inviteCode ?? "--------")
                    .font(.caption2.weight(.bold).monospaced())
                    .foregroundStyle(.white.opacity(0.74))
            }
        }
        .padding(18)
        .background(cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Color.black.opacity(0.14), radius: 18, y: 10)
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: post.backgroundColor),
                Color(hex: post.backgroundColor).opacity(0.78),
                Color(hex: "#181A26"),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(.thinMaterial.opacity(0.16))
    }

    private var iconName: String {
        switch post.contentType {
        case .text:
            return "text.bubble.fill"
        case .photo:
            return "photo.fill"
        case .aiGenerated:
            return "sparkles"
        }
    }
}
