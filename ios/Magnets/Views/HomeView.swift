import SwiftData
import SwiftUI
import UIKit

struct HomeView: View {
    @Environment(AppRouter.self) private var appRouter
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Magnet.createdAt, order: .reverse)
    private var magnets: [Magnet]

    @State private var isPresentingCreateSheet = false
    @State private var navigationPath: [HomeDestination] = []
    @State private var cloudKitSyncStatus: CloudKitSyncStatus = .checking

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroCard

                    if magnets.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 18) {
                            ForEach(magnets, id: \.id) { magnet in
                                NavigationLink(
                                    value: HomeDestination.magnet(
                                        id: magnet.id,
                                        inviteCode: magnet.inviteCode
                                    )
                                ) {
                                    MagnetCardView(magnet: magnet)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(backgroundView)
            .navigationTitle("Magnets")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.thinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    syncStatusToolbarIcon

                    Button {
                        isPresentingCreateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2.weight(.semibold))
                    }
                }
            }
            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {
                case let .magnet(id, inviteCode):
                    if let magnet = magnets.first(where: { $0.id == id }) {
                        MagnetDetailView(magnet: magnet)
                    } else {
                        MissingMagnetLandingView(magnetID: id, inviteCode: inviteCode)
                    }
                case let .invite(inviteCode):
                    JoinMagnetView(initialInviteCode: inviteCode) { magnet in
                        navigationPath = [.magnet(id: magnet.id, inviteCode: magnet.inviteCode)]
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingCreateSheet) {
            CreateMagnetView()
        }
        .onAppear {
            handlePendingDeepLink()
        }
        .onChange(of: appRouter.pendingLink?.id) { _, _ in
            handlePendingDeepLink()
        }
        .task {
            await refreshCloudKitStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await refreshCloudKitStatus()
            }
        }
    }

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#16192C"),
                            Color(hex: "#4B43E8"),
                            Color(hex: "#FF7A6B"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 160, height: 160)
                        .blur(radius: 18)
                        .offset(x: 42, y: -40)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 12) {
                Text("Shared moments,\npinned to glass.")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Create a Magnet, drop a note or photo, and your widget stays alive on every home screen.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    statPill(value: "\(magnets.count)", label: "Boards")
                    statPill(
                        value: "\(magnets.reduce(0) { $0 + $1.posts.count })",
                        label: "Posts"
                    )
                }

                HStack(spacing: 10) {
                    heroActionButton(
                        title: "Create Magnet",
                        systemImage: "plus.circle.fill"
                    ) {
                        isPresentingCreateSheet = true
                    }

                    heroActionButton(
                        title: "Join Magnet",
                        systemImage: "link.badge.plus"
                    ) {
                        navigationPath = [.invite(inviteCode: "")]
                    }
                }
            }
            .padding(24)
        }
        .frame(minHeight: 240)
        .shadow(color: Color.black.opacity(0.18), radius: 20, y: 14)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color(hex: "#4B43E8"))

            Text("Nothing on the fridge yet.")
                .font(.title2.weight(.bold))

            Text("Spin up your first shared widget space and start posting text, photos, and agent updates.")
                .foregroundStyle(.secondary)

            Button("Create your first Magnet") {
                isPresentingCreateSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "#4B43E8"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        }
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(.white.opacity(0.12), in: Capsule())
    }

    private func heroActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var syncStatusToolbarIcon: some View {
        Image(systemName: cloudKitSyncStatus.symbolName)
            .font(.headline.weight(.semibold))
            .foregroundStyle(cloudKitSyncStatus.tintColor)
            .accessibilityLabel(cloudKitSyncStatus.accessibilityLabel)
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#F6F5FF"),
                    Color(hex: "#FFF6F1"),
                    Color.white,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(hex: "#C3D5FF").opacity(0.35))
                .frame(width: 360, height: 360)
                .blur(radius: 18)
                .offset(x: -110, y: -220)

            Circle()
                .fill(Color(hex: "#FFD2C3").opacity(0.35))
                .frame(width: 300, height: 300)
                .blur(radius: 26)
                .offset(x: 160, y: 250)
        }
        .ignoresSafeArea()
    }

    private func handlePendingDeepLink() {
        guard let request = appRouter.consumePendingLink() else {
            return
        }

        isPresentingCreateSheet = false

        switch request.link {
        case .home:
            navigationPath = []
        case let .magnet(id, inviteCode):
            navigationPath = [.magnet(id: id, inviteCode: inviteCode)]
        case let .join(inviteCode):
            navigationPath = [.invite(inviteCode: inviteCode)]
        }
    }

    @MainActor
    private func refreshCloudKitStatus() async {
        cloudKitSyncStatus = .checking
        cloudKitSyncStatus = await CloudKitStatusProbe.currentStatus()
    }
}

private enum HomeDestination: Hashable {
    case magnet(id: UUID, inviteCode: String?)
    case invite(inviteCode: String)
}

private struct MagnetCardView: View {
    let magnet: Magnet

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: magnet.primaryColorHex),
                            Color(hex: magnet.primaryColorHex).opacity(0.6),
                            Color(hex: "#181A26"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.18))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("\(magnet.members.count)", systemImage: "person.2.fill")
                    Spacer()
                    Text(magnet.inviteCode)
                        .font(.caption.weight(.bold).monospaced())
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(.white.opacity(0.14), in: Capsule())
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.84))

                Spacer(minLength: 0)

                Text(magnet.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text(magnet.latestPost?.displayText ?? "Drop the first note or photo.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(2)

                HStack {
                    Label("\(magnet.posts.count) posts", systemImage: "rectangle.stack.fill")
                    Spacer()
                    Text(magnet.createdAt, format: .dateTime.month(.abbreviated).day())
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))
            }
            .padding(22)
        }
        .frame(height: 196)
        .shadow(color: Color.black.opacity(0.14), radius: 18, y: 10)
    }
}

private struct MissingMagnetLandingView: View {
    let magnetID: UUID
    let inviteCode: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "sparkles.rectangle.stack.badge.exclamationmark")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(Color(hex: "#4B43E8"))

            Text("This Magnet isn’t on this device yet.")
                .font(.title2.weight(.bold))

            Text("The widget opened a direct route, but this device does not have that Magnet yet. The CloudKit path is now wired, but real cross-device resolution still needs Apple Developer container provisioning and an iCloud-signed device.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                metadataRow(label: "Magnet ID", value: magnetID.uuidString.lowercased())

                if let inviteCode {
                    metadataRow(label: "Invite code", value: inviteCode)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .background(background)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(hex: "#F6F5FF"),
                Color(hex: "#FFF6F1"),
                Color.white,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func metadataRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.monospaced())
                .textSelection(.enabled)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct JoinMagnetView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Magnet.createdAt, order: .reverse)
    private var magnets: [Magnet]

    let onOpenMagnet: (Magnet) -> Void

    @FocusState private var isInviteCodeFocused: Bool
    @State private var inviteCode: String
    @State private var hasAttemptedLookup: Bool

    init(initialInviteCode: String, onOpenMagnet: @escaping (Magnet) -> Void) {
        self.onOpenMagnet = onOpenMagnet
        _inviteCode = State(initialValue: initialInviteCode)
        _hasAttemptedLookup = State(initialValue: !initialInviteCode.isEmpty)
    }

    private var normalizedInviteCode: String {
        Self.normalizeInviteCode(inviteCode)
    }

    private var matchingMagnet: Magnet? {
        let lookupCode = normalizedInviteCode
        guard !lookupCode.isEmpty else {
            return nil
        }

        return magnets.first {
            $0.inviteCode.caseInsensitiveCompare(lookupCode) == .orderedSame
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Join a Magnet")
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    Text("Paste an invite code or a `magnets://join/<code>` link. If this device already has that Magnet locally, the route opens immediately.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Invite code")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("MAGN3TS", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.title3, design: .rounded, weight: .bold).monospaced())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .focused($isInviteCodeFocused)
                        .onSubmit {
                            resolveInvite()
                        }
                }

                HStack(spacing: 12) {
                    Button {
                        if let clipboardValue = UIPasteboard.general.string {
                            inviteCode = clipboardValue
                            hasAttemptedLookup = false
                        }
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        resolveInvite()
                    } label: {
                        Label(
                            matchingMagnet == nil ? "Check Code" : "Open Magnet",
                            systemImage: matchingMagnet == nil ? "magnifyingglass" : "arrow.right.circle.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#4B43E8"))
                    .disabled(normalizedInviteCode.isEmpty)
                }

                if let matchingMagnet {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Local match found", systemImage: "checkmark.seal.fill")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color(hex: "#0AB8A2"))

                        Text(matchingMagnet.name)
                            .font(.title3.weight(.bold))

                        Text("Invite code \(matchingMagnet.inviteCode) is already in this shared store.")
                            .foregroundStyle(.secondary)

                        Button {
                            onOpenMagnet(matchingMagnet)
                        } label: {
                            Label("Open \(matchingMagnet.name)", systemImage: "arrow.right.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: matchingMagnet.primaryColorHex))
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.24), lineWidth: 1)
                    }
                } else if hasAttemptedLookup, !normalizedInviteCode.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("CloudKit groundwork is ready", systemImage: "icloud")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color(hex: "#3E8BFF"))

                        Text("This device does not have a local Magnet for \(normalizedInviteCode).")
                            .font(.headline.weight(.semibold))

                        Text("Real cross-device joins still need the Apple Developer iCloud container, both entitlements, and a signed-in physical device. Until then, the simulator stays local-only on purpose.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.24), lineWidth: 1)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Paste a code to start", systemImage: "link.badge.plus")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color(hex: "#4B43E8"))

                        Text("Deep links now resolve into this join flow, and local invite matches can open the right Magnet immediately.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.24), lineWidth: 1)
                    }
                }
            }
            .padding(24)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#F6F5FF"),
                    Color(hex: "#FFF6F1"),
                    Color.white,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Join")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            isInviteCodeFocused = inviteCode.isEmpty
        }
    }

    private func resolveInvite() {
        inviteCode = normalizedInviteCode
        hasAttemptedLookup = true

        if let matchingMagnet {
            onOpenMagnet(matchingMagnet)
        }
    }

    private static func normalizeInviteCode(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmed),
           case let .join(code) = MagnetsDeepLink(url: url) {
            return code.uppercased()
        }

        return trimmed
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}
