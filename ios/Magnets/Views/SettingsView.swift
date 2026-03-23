import SwiftUI

private enum SettingsViewLayoutMetrics {
    static let maxContentWidth: CGFloat = 680
    static let bottomScrollClearance: CGFloat = 16
}

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var widgetPushState = WidgetPushStateStore.load()
    @State private var isRefreshingPushState = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard

                    widgetStatusCard

                    connectedAgentsCard

                    aboutCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .frame(maxWidth: SettingsViewLayoutMetrics.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: SettingsViewLayoutMetrics.bottomScrollClearance)
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
            Text("Keep your Magnets close.")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("Magnets keeps shared notes, photos, and future agent updates one glance away on your Home Screen.")
                .foregroundStyle(.secondary)

            Label(heroStatusCopy, systemImage: heroStatusIcon)
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

    private var widgetStatusCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Widget Status")
                            .font(.title3.weight(.bold))

                        Text("Add Magnets to your Home Screen for quicker updates and one-tap access.")
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
                    statusRow(
                        title: "Status",
                        value: widgetStatusTitle,
                        detail: widgetStatusDetail
                    )

                    statusRow(
                        title: "Active widgets",
                        value: activeWidgetCountLabel,
                        detail: widgetConfigurationDetail
                    )

                    statusRow(
                        title: "Last setup update",
                        value: lastWidgetUpdateLabel,
                        detail: lastWidgetUpdateDetail
                    )
                }
            }
        }
    }

    private var connectedAgentsCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Connected Agents")
                    .font(.title3.weight(.bold))

                Label("No agents connected", systemImage: "sparkles")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color(hex: "#4B43E8"))

                Text("Agent posting is coming soon. You'll be able to connect a helper to a Magnet for scheduled updates, daily briefs, and other automatic posts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aboutCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("About")
                    .font(.title3.weight(.bold))

                settingsRow(
                    title: "App version",
                    subtitle: appVersionLabel,
                    icon: "info.circle.fill"
                )

                settingsRow(
                    title: "Sharing",
                    subtitle: "Share a code or link to invite friends to a Magnet.",
                    icon: "link.badge.plus"
                )

                settingsRow(
                    title: "iCloud",
                    subtitle: "Sign into iCloud to keep your Magnets available across your Apple devices.",
                    icon: "icloud.fill"
                )

                settingsRow(
                    title: "Widgets",
                    subtitle: "Home Screen widgets show the latest post and open straight back into the app.",
                    icon: "rectangle.stack.badge.person.crop.fill"
                )
            }
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

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
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
        Array(
            Set(
                widgetPushState.widgets
                    .map { widgetFamilyName(for: $0.family) }
            )
        )
            .sorted()
            .joined(separator: " • ")
    }

    @MainActor
    private func refreshPushState() async {
        isRefreshingPushState = true
        defer { isRefreshingPushState = false }

        widgetPushState = await WidgetPushStateStore.refreshFromSystem()
    }

    private func statusRow(title: String, value: String, detail: String) -> some View {
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

    private var heroStatusCopy: String {
        widgetPushState.widgets.isEmpty
            ? "Add a widget to your Home Screen for quick access."
            : "Home Screen widgets are active on this device."
    }

    private var heroStatusIcon: String {
        widgetPushState.widgets.isEmpty ? "plus.circle.fill" : "checkmark.seal.fill"
    }

    private var widgetStatusTitle: String {
        if widgetPushState.hasPushToken, !widgetPushState.widgets.isEmpty {
            return "Ready"
        }

        if !widgetPushState.widgets.isEmpty {
            return "Finishing setup"
        }

        return "Not added yet"
    }

    private var widgetStatusDetail: String {
        if widgetPushState.hasPushToken, !widgetPushState.widgets.isEmpty {
            return "Your widget is connected and ready for faster refreshes on this device."
        }

        if !widgetPushState.widgets.isEmpty {
            return "Open the widget once and Magnets will finish registering it automatically."
        }

        return "Add a Magnets widget to your Home Screen to enable quicker updates."
    }

    private var activeWidgetCountLabel: String {
        widgetPushState.widgets.count == 1
            ? "1 widget"
            : "\(widgetPushState.widgets.count) widgets"
    }

    private var widgetConfigurationDetail: String {
        widgetPushState.widgets.isEmpty
            ? "No Magnets widgets are currently configured on this device."
            : widgetFamilySummary
    }

    private var lastWidgetUpdateLabel: String {
        widgetPushState.lastTokenUpdateAt.map {
            $0.formatted(date: .abbreviated, time: .shortened)
        } ?? "Not yet"
    }

    private var lastWidgetUpdateDetail: String {
        widgetPushState.lastTokenUpdateAt == nil
            ? "Once a widget is added, Magnets will keep this status up to date automatically."
            : "This is the most recent widget registration seen by the app."
    }

    private var appVersionLabel: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(shortVersion) (\(buildNumber))"
    }

    private func widgetFamilyName(for family: String) -> String {
        switch family {
        case "systemSmall":
            return "Small"
        case "systemMedium":
            return "Medium"
        case "systemLarge":
            return "Large"
        case "systemExtraLarge":
            return "Extra Large"
        default:
            return family
        }
    }
}
