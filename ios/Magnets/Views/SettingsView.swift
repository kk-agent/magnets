import SwiftUI

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var widgetPushState = WidgetPushStateStore.load()
    @State private var isRefreshingPushState = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard

                    widgetPushDebugCard

                    VStack(alignment: .leading, spacing: 14) {
                        settingsRow(
                            title: "Shared container",
                            subtitle: SharedModelContainer.appGroupID,
                            icon: "square.stack.3d.up.fill"
                        )

                        settingsRow(
                            title: "Phase 2 push refresh",
                            subtitle: "WidgetKit push state now persists to App Group JSON for app-side inspection.",
                            icon: "bolt.badge.clock.fill"
                        )

                        settingsRow(
                            title: "Deep link routing",
                            subtitle: "Widget taps now route into a specific Magnet or reserved invite path.",
                            icon: "arrowshape.turn.up.right.fill"
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
        .task {
            await refreshPushState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await refreshPushState()
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Phase 2A wiring is live.")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("The widget can now publish its push token into the shared container, the app can inspect that state, and deep links have a real landing path.")
                .foregroundStyle(.secondary)

            Label("CloudKit-shaped models, App Group JSON, widget tap routing", systemImage: "checkmark.seal.fill")
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

    private var widgetPushDebugCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Widget Push Debug")
                        .font(.title3.weight(.bold))

                    Text("Read from the shared App Group state so the app and widget are looking at the same token snapshot.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        await refreshPushState()
                    }
                } label: {
                    if isRefreshingPushState {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.headline.weight(.semibold))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(hex: "#4B43E8"))
            }

            VStack(spacing: 12) {
                debugRow(
                    title: "Push token",
                    value: widgetPushState.hasPushToken ? "Captured" : "Waiting",
                    detail: widgetPushState.tokenPreview ?? "No token saved yet."
                )

                debugRow(
                    title: "Known widgets",
                    value: "\(widgetPushState.widgets.count)",
                    detail: widgetPushState.widgets.isEmpty
                        ? "No active widget configurations recorded yet."
                        : widgetFamilySummary
                )

                debugRow(
                    title: "Last token update",
                    value: widgetPushState.lastTokenUpdateAt.map {
                        $0.formatted(date: .abbreviated, time: .shortened)
                    } ?? "Not yet",
                    detail: widgetPushState.lastTokenUpdateAt == nil
                        ? "This fills in after WidgetKit hands back a push token."
                        : "Timestamp is preserved until the token rotates again."
                )
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
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

    private var widgetFamilySummary: String {
        widgetPushState.widgets
            .map(\.family)
            .sorted()
            .joined(separator: " • ")
    }

    @MainActor
    private func refreshPushState() async {
        isRefreshingPushState = true
        defer { isRefreshingPushState = false }

        widgetPushState = await WidgetPushStateStore.refreshFromSystem()
    }

    private func debugRow(title: String, value: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.headline.weight(.bold))

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
