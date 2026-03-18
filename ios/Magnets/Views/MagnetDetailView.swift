import CoreImage
import CoreImage.CIFilterBuiltins
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

struct MagnetDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let magnet: Magnet

    @State private var draftText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var composerMessage: String?
    @State private var isSaving = false
    @State private var isPresentingInviteSheet = false

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingInviteSheet = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            composer
        }
        .sheet(isPresented: $isPresentingInviteSheet) {
            InviteView(magnet: magnet)
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

private struct InviteView: View {
    @Environment(\.dismiss) private var dismiss

    let magnet: Magnet

    @State private var copiedValueMessage: String?

    private var inviteLinkString: String {
        magnet.inviteURL.absoluteString
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    inviteHeroCard
                    qrCard
                    actionsCard
                }
                .padding(24)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "#F7F3FF"),
                        Color(hex: "#FFF7F2"),
                        Color.white,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(32)
    }

    private var inviteHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Share \(magnet.name)")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Anyone with the invite code or deep link can land in the join flow. Real multi-device access still depends on CloudKit provisioning + iCloud sign-in.")
                .foregroundStyle(.secondary)

            Text(magnet.inviteCode)
                .font(.system(size: 34, weight: .bold, design: .rounded).monospaced())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 26, style: .continuous))

            Text(inviteLinkString)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.24), lineWidth: 1)
        }
    }

    private var qrCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("QR code")
                .font(.headline.weight(.bold))

            Text("This encodes the `magnets://join/<code>` route so the app can jump straight into the join flow.")
                .foregroundStyle(.secondary)

            InviteQRCodeView(payload: inviteLinkString)
                .frame(maxWidth: .infinity)
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.24), lineWidth: 1)
        }
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actions")
                .font(.headline.weight(.bold))

            if let copiedValueMessage {
                Text(copiedValueMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: "#0AB8A2"))
            }

            HStack(spacing: 12) {
                Button {
                    copyInviteCode()
                } label: {
                    Label("Copy Code", systemImage: "document.on.document")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    copyInviteLink()
                } label: {
                    Label("Copy Link", systemImage: "link")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            ShareLink(item: magnet.inviteShareText) {
                Label("Share Invite", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: magnet.primaryColorHex))
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.24), lineWidth: 1)
        }
    }

    private func copyInviteCode() {
        UIPasteboard.general.string = magnet.inviteCode
        copiedValueMessage = "Invite code copied."
    }

    private func copyInviteLink() {
        UIPasteboard.general.string = inviteLinkString
        copiedValueMessage = "Invite link copied."
    }
}

private struct InviteQRCodeView: View {
    private static let ciContext = CIContext()

    let payload: String

    private var qrCodeImage: CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage?
            .transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = Self.ciContext.createCGImage(outputImage, from: outputImage.extent)
        else {
            return nil
        }

        return cgImage
    }

    var body: some View {
        Group {
            if let qrCodeImage {
                Image(decorative: qrCodeImage, scale: 1, orientation: .up)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(20)
                    .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 34, weight: .semibold))
                    Text("QR generation failed.")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        }
    }
}
