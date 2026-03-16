import PhotosUI
import SwiftData
import SwiftUI
import WidgetKit

struct MagnetDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let magnet: Magnet

    @State private var draftText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var composerMessage: String?
    @State private var isSaving = false

    private var sortedPosts: [Post] {
        magnet.sortedPosts
    }

    private var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedPhoto != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                magnetHeader

                if sortedPosts.isEmpty {
                    emptyFeedCard
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(sortedPosts, id: \.id) { post in
                            PostRowView(post: post)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
        .background(backgroundView)
        .navigationTitle(magnet.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            composer
        }
    }

    private var magnetHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(magnet.name)
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    Text("Invite code \(magnet.inviteCode) keeps this Magnet in orbit.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "bolt.heart.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(hex: magnet.primaryColorHex))
                    .padding(14)
                    .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            HStack(spacing: 12) {
                detailPill(value: "\(magnet.members.count)", label: "Members", icon: "person.2.fill")
                detailPill(value: "\(magnet.posts.count)", label: "Posts", icon: "rectangle.stack.fill")
            }
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        }
    }

    private func detailPill(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.weight(.bold))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyFeedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color(hex: magnet.primaryColorHex))

            Text("Nothing shared yet.")
                .font(.title3.weight(.bold))

            Text("Type a note, attach a photo, and the widget will refresh across every home screen in this Magnet.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let composerMessage {
                Text(composerMessage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            if selectedPhoto != nil {
                HStack(spacing: 10) {
                    Image(systemName: "photo.fill")
                        .foregroundStyle(Color(hex: magnet.primaryColorHex))

                    Text("Photo ready to send")
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    Button("Remove") {
                        selectedPhoto = nil
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            HStack(alignment: .bottom, spacing: 12) {
                TextField("Drop a note, caption, or tiny AI moment…", text: $draftText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .lineLimit(1...4)

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo.badge.plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color(hex: magnet.primaryColorHex))
                        .frame(width: 50, height: 50)
                        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Button {
                    let pendingPhoto = selectedPhoto

                    Task {
                        await createPost(using: pendingPhoto)
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: magnet.primaryColorHex),
                                        Color(hex: "#181A26"),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 54, height: 54)
                }
                .disabled(!canSend || isSaving)
                .opacity(canSend ? 1 : 0.45)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.thinMaterial)
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(hex: "#FBFBFF"),
                Color(hex: "#F4F7FF"),
                Color(hex: "#FFF7F3"),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    @MainActor
    private func createPost(using pickerItem: PhotosPickerItem?) async {
        composerMessage = nil

        let trimmedText = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty || pickerItem != nil else {
            return
        }

        isSaving = true
        defer { isSaving = false }

        var storedMediaPath: String?

        if let pickerItem {
            do {
                if let importedData = try await pickerItem.loadTransferable(type: Data.self) {
                    storedMediaPath = try SharedMediaStore.saveImageData(importedData)
                }
            } catch {
                composerMessage = "That photo didn’t import cleanly. Try another one."
                return
            }
        }

        guard !trimmedText.isEmpty || storedMediaPath != nil else {
            composerMessage = "There’s nothing to send yet."
            return
        }

        let post = Post(
            contentType: storedMediaPath == nil ? .text : .photo,
            textContent: trimmedText.isEmpty ? nil : trimmedText,
            mediaURL: storedMediaPath,
            backgroundColor: MagnetPalette.randomPostHex(),
            magnet: magnet
        )

        modelContext.insert(post)

        do {
            try modelContext.save()
            draftText = ""
            selectedPhoto = nil
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            composerMessage = "Couldn’t save that post. Try once more."
        }
    }
}
