import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard

                    VStack(alignment: .leading, spacing: 14) {
                        settingsRow(
                            title: "Shared container",
                            subtitle: SharedModelContainer.appGroupID,
                            icon: "square.stack.3d.up.fill"
                        )

                        settingsRow(
                            title: "Phase 2 push refresh",
                            subtitle: "Widget push token hook is stubbed and ready.",
                            icon: "bolt.badge.clock.fill"
                        )

                        settingsRow(
                            title: "Agent posting",
                            subtitle: "Reserved for OpenClaw connections and on-device generation.",
                            icon: "sparkles.rectangle.stack.fill"
                        )
                    }
                    .padding(18)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }
            .background(backgroundView)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.thinMaterial, for: .navigationBar)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Phase 1 foundations are in.")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("Local SwiftData, the shared widget container, and the first consumer UI are wired. Phase 2 can layer on invites, push, and agents.")
                .foregroundStyle(.secondary)

            Label("CloudKit-shaped models, App Group store, WidgetKit extension", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: "#4B43E8"))
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#FFFFFF"),
                    Color(hex: "#EEF3FF"),
                    Color(hex: "#FFF2EC"),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.42), lineWidth: 1)
        }
    }

    private func settingsRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(hex: "#4B43E8"))
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(hex: "#F6F5FF"),
                Color(hex: "#FDF8F5"),
                Color.white,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
