import SwiftData
import SwiftUI
import WidgetKit

struct CreateMagnetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @FocusState private var isNameFocused: Bool
    @State private var magnetName = ""
    @State private var errorMessage: String?

    private var trimmedName: String {
        magnetName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ZStack {
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

                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Name a new Magnet")
                            .font(.system(size: 30, weight: .bold, design: .rounded))

                        Text("Start with a shared space for family drops, a friend group, or your first agent-driven widget feed.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Magnet name")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("Friday family board", text: $magnetName)
                            .textInputAutocapitalization(.words)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .focused($isNameFocused)
                    }

                    HStack(spacing: 12) {
                        previewChip(title: "Shared Space", subtitle: "Syncs across devices", icon: "icloud.fill")
                        previewChip(title: "Invite", subtitle: "8-char code", icon: "link.badge.plus")
                    }

                    Spacer()
                }
                .padding(24)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createMagnet()
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(32)
        .presentationDragIndicator(.visible)
        .alert("Unable to Create Magnet", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
        .onAppear {
            isNameFocused = true
        }
    }

    private func previewChip(title: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color(hex: "#4B43E8"))

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(subtitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @MainActor
    private func createMagnet() {
        do {
            let uniqueCode = try Magnet.makeUniqueInviteCode(in: modelContext)
            let magnet = Magnet(name: trimmedName, inviteCode: uniqueCode)
            let owner = MagnetMember(displayName: "You", role: .owner, magnet: magnet)

            modelContext.insert(magnet)
            modelContext.insert(owner)

            try modelContext.save()
            WidgetCenter.shared.reloadAllTimelines()
            dismiss()
        } catch {
            #if DEBUG
            print("⚠️ Unable to save magnet: \(error)")
            #endif
            errorMessage = "We couldn't save that Magnet. Please try again."
        }
    }
}
