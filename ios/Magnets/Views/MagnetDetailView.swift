import CoreImage
import CoreImage.CIFilterBuiltins
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import WidgetKit
#if canImport(FoundationModels)
import FoundationModels
#endif

struct MagnetDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let magnet: Magnet

    @State private var draftText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var composerMessage: String?
    @State private var isSaving = false
    @State private var isPresentingInviteSheet = false
    @State private var isPresentingAIComposeSheet = false
    @State private var draftSource: ComposerDraftSource = .manual

    private var sortedPosts: [Post] {
        magnet.sortedPosts
    }

    private var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedPhoto != nil
    }

    private var aiComposeAvailability: AIComposeAvailability {
        AIComposeService.availability
    }

    private var aiComposeContext: AIComposeContext {
        AIComposeContext(
            magnetName: magnet.name,
            primaryColorHex: magnet.primaryColorHex,
            recentPostSnippets: Array(sortedPosts.prefix(4)).map(\.aiSummarySnippet)
        )
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
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 20)
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
        .sheet(isPresented: $isPresentingAIComposeSheet) {
            AIComposeSheet(context: aiComposeContext) { generatedText in
                draftText = generatedText
                draftSource = .aiGenerated
                composerMessage = "AI draft ready. Give it a quick edit, then send."
            }
        }
        .sheet(isPresented: $isPresentingInviteSheet) {
            InviteView(magnet: magnet)
        }
        .onChange(of: draftText) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, selectedPhoto == nil {
                draftSource = .manual
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            if newValue == nil, draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draftSource = .manual
            }
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
        let composerAccent = Color(hex: magnet.primaryColorHex)

        return VStack(alignment: .leading, spacing: 10) {
            if let composerMessage {
                Text(composerMessage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            if selectedPhoto != nil {
                HStack(spacing: 10) {
                    Image(systemName: "photo.fill")
                        .foregroundStyle(composerAccent)

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
                        .foregroundStyle(composerAccent)
                        .frame(width: 50, height: 50)
                        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                if aiComposeAvailability.shouldShowButton {
                    Button {
                        isPresentingAIComposeSheet = true
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(
                                aiComposeAvailability.isAvailable
                                ? composerAccent
                                : .secondary
                            )
                            .frame(width: 50, height: 50)
                            .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .disabled(!aiComposeAvailability.isAvailable || isSaving)
                    .opacity(aiComposeAvailability.isAvailable ? 1 : 0.45)
                    .accessibilityLabel("AI Compose")
                    .accessibilityHint(aiComposeAvailability.helpText)
                    .help(aiComposeAvailability.helpText)
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

            if let unavailableMessage = aiComposeAvailability.unavailableMessage {
                Label(unavailableMessage, systemImage: "sparkles")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
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
            contentType: postContentType(for: storedMediaPath),
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
            draftSource = .manual
            WidgetRefreshCoordinator.shared.requestRefresh()
        } catch {
            composerMessage = "Couldn’t save that post. Try once more."
        }
    }

    private func postContentType(for storedMediaPath: String?) -> PostContentType {
        if storedMediaPath != nil {
            return .photo
        }

        return draftSource == .aiGenerated ? .aiGenerated : .text
    }
}

private enum ComposerDraftSource {
    case manual
    case aiGenerated
}

private struct AIComposeContext: Sendable {
    let magnetName: String
    let primaryColorHex: String
    let recentPostSnippets: [String]
}

private enum AIComposePreset: String, CaseIterable, Identifiable {
    case morningGreeting
    case dailyQuote
    case summarizeRecent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morningGreeting:
            return "Morning greeting"
        case .dailyQuote:
            return "Daily quote"
        case .summarizeRecent:
            return "Summarize recent"
        }
    }

    var subtitle: String {
        switch self {
        case .morningGreeting:
            return "Generate a warm good-morning note for the widget."
        case .dailyQuote:
            return "Create a short inspirational line that feels fresh."
        case .summarizeRecent:
            return "Condense the latest posts into one quick recap."
        }
    }

    var iconName: String {
        switch self {
        case .morningGreeting:
            return "sun.max.fill"
        case .dailyQuote:
            return "quote.bubble.fill"
        case .summarizeRecent:
            return "text.redaction"
        }
    }

    func isEnabled(in context: AIComposeContext) -> Bool {
        switch self {
        case .summarizeRecent:
            return !context.recentPostSnippets.isEmpty
        case .morningGreeting, .dailyQuote:
            return true
        }
    }

    var disabledMessage: String {
        switch self {
        case .summarizeRecent:
            return "Share a few posts first so AI has something to summarize."
        case .morningGreeting, .dailyQuote:
            return ""
        }
    }
}

private struct AIComposeAvailability: Equatable {
    enum State: Equatable {
        case available
        case unavailable(String)
        case unsupportedFramework
    }

    let state: State

    var shouldShowButton: Bool {
        state != .unsupportedFramework
    }

    var isAvailable: Bool {
        state == .available
    }

    var unavailableMessage: String? {
        guard case let .unavailable(message) = state else {
            return nil
        }

        return message
    }

    var helpText: String {
        switch state {
        case .available:
            return "Generate a short on-device draft."
        case let .unavailable(message):
            return message
        case .unsupportedFramework:
            return "Foundation Models isn’t available in this build."
        }
    }
}

private enum AIComposeError: LocalizedError {
    case unavailable(String)
    case emptyCustomPrompt
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case let .unavailable(message):
            return message
        case .emptyCustomPrompt:
            return "Add a short custom prompt first."
        case .emptyResponse:
            return "The model returned an empty draft. Try again."
        }
    }
}

private enum AIComposeService {
    static var availability: AIComposeAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 18.0, *) {
            return AIComposeAvailability(systemAvailability: SystemLanguageModel.default.availability)
        }

        return AIComposeAvailability(state: .unavailable("Requires iOS 18 or newer."))
        #else
        return AIComposeAvailability(state: .unsupportedFramework)
        #endif
    }

    static func generateDraft(
        for preset: AIComposePreset?,
        customPrompt: String,
        context: AIComposeContext
    ) async throws -> String {
        let availability = availability

        guard availability.isAvailable else {
            throw AIComposeError.unavailable(
                availability.unavailableMessage ?? "Apple Intelligence isn’t available right now."
            )
        }

        let trimmedCustomPrompt = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let prompt = makePrompt(
            for: preset,
            customPrompt: trimmedCustomPrompt,
            context: context
        ) else {
            throw AIComposeError.emptyCustomPrompt
        }

        #if canImport(FoundationModels)
        if #available(iOS 18.0, *) {
            let session = LanguageModelSession(
                model: SystemLanguageModel.default,
                instructions: """
                Write one short post for the Magnets iOS app.
                Keep it natural, friendly, and under 220 characters.
                Return only the final post text with no title, bullets, or quotation marks.
                """
            )

            let response = try await session.respond(to: prompt)
            let trimmed = response.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))

            guard !trimmed.isEmpty else {
                throw AIComposeError.emptyResponse
            }

            return trimmed
        }
        #endif

        throw AIComposeError.unavailable("Foundation Models isn’t available in this build.")
    }

    private static func makePrompt(
        for preset: AIComposePreset?,
        customPrompt: String,
        context: AIComposeContext
    ) -> String? {
        switch preset {
        case .morningGreeting:
            return "Write a friendly morning greeting for the shared widget \(context.magnetName). Warm tone. One short message."
        case .dailyQuote:
            return "Write one original inspirational quote for the shared widget \(context.magnetName). Keep it punchy and uplifting."
        case .summarizeRecent:
            guard !context.recentPostSnippets.isEmpty else {
                return nil
            }

            let updates = context.recentPostSnippets.joined(separator: " | ")
            return "Summarize these recent \(context.magnetName) updates in 1 or 2 short sentences: \(updates)"
        case nil:
            guard !customPrompt.isEmpty else {
                return nil
            }

            return "Write a short post for the shared widget \(context.magnetName). User request: \(customPrompt)"
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 18.0, *)
private extension AIComposeAvailability {
    init(systemAvailability: SystemLanguageModel.Availability) {
        switch systemAvailability {
        case .available:
            self.init(state: .available)
        case .unavailable(.deviceNotEligible):
            self.init(state: .unavailable("Requires Apple Intelligence on a supported device."))
        case .unavailable(.appleIntelligenceNotEnabled):
            self.init(state: .unavailable("Turn on Apple Intelligence to use AI Compose."))
        case .unavailable(.modelNotReady):
            self.init(state: .unavailable("Apple Intelligence is still getting ready."))
        @unknown default:
            self.init(state: .unavailable("Apple Intelligence isn’t available right now."))
        }
    }
}
#endif

private struct AIComposeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let context: AIComposeContext
    let onDraftGenerated: (String) -> Void

    @State private var customPrompt = ""
    @State private var generationError: String?
    @State private var isGenerating = false
    @State private var generatingPreset: AIComposePreset?
    @FocusState private var isCustomPromptFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Prompt ideas")
                            .font(.headline.weight(.bold))

                        ForEach(AIComposePreset.allCases) { preset in
                            promptOptionCard(for: preset)
                        }
                    }
                    .padding(22)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .strokeBorder(.white.opacity(0.24), lineWidth: 1)
                    }

                    customPromptCard

                    if isGenerating {
                        generatingCard
                    }

                    if let generationError {
                        errorCard(message: generationError)
                    }
                }
                .padding(24)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "#F7F3FF"),
                        Color(hex: "#EEF3FF"),
                        Color(hex: "#FFF7F2"),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("AI Compose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(isGenerating)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(32)
        .presentationDragIndicator(.visible)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt the model")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Everything stays on device. Pick a short preset or hand it a custom nudge, then review the draft before posting.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(hex: context.primaryColorHex))
                    .padding(14)
                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if !context.recentPostSnippets.isEmpty {
                Label("\(context.recentPostSnippets.count) recent posts ready for summarizing", systemImage: "rectangle.stack.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(hex: context.primaryColorHex))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(.white.opacity(0.6), in: Capsule())
            }
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.24), lineWidth: 1)
        }
    }

    private var customPromptCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Custom prompt")
                .font(.headline.weight(.bold))

            TextField("Ask for something short and specific…", text: $customPrompt, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .lineLimit(2...5)
                .focused($isCustomPromptFocused)

            Button {
                isCustomPromptFocused = false
                generateDraft(using: nil)
            } label: {
                Label("Generate from custom prompt", systemImage: "wand.and.stars")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: context.primaryColorHex))
            .disabled(customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.24), lineWidth: 1)
        }
    }

    private var generatingCard: some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(Color(hex: context.primaryColorHex))

            VStack(alignment: .leading, spacing: 4) {
                Text("Generating on device…")
                    .font(.subheadline.weight(.semibold))

                Text("Keeping the prompt tight so the system model can move fast.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
    }

    private func errorCard(message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(hex: "#FF6B6B"))

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
    }

    private func promptOptionCard(for preset: AIComposePreset) -> some View {
        let isEnabled = preset.isEnabled(in: context)
        let isCurrentPreset = generatingPreset == preset

        return Button {
            generateDraft(using: preset)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: preset.iconName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isEnabled ? Color(hex: context.primaryColorHex) : .secondary)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(preset.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)

                    Text(isEnabled ? preset.subtitle : preset.disabledMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isCurrentPreset && isGenerating {
                    ProgressView()
                        .tint(Color(hex: context.primaryColorHex))
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isEnabled ? Color(hex: context.primaryColorHex) : .secondary)
                }
            }
            .padding(18)
            .background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isGenerating)
        .opacity(isEnabled ? 1 : 0.52)
    }

    private func generateDraft(using preset: AIComposePreset?) {
        let availability = AIComposeService.availability

        guard availability.isAvailable else {
            generationError = availability.unavailableMessage ?? "Apple Intelligence isn’t available right now."
            return
        }

        if let preset, !preset.isEnabled(in: context) {
            generationError = preset.disabledMessage
            return
        }

        generationError = nil
        generatingPreset = preset
        isGenerating = true

        Task {
            do {
                let generatedDraft = try await AIComposeService.generateDraft(
                    for: preset,
                    customPrompt: customPrompt,
                    context: context
                )

                await MainActor.run {
                    isGenerating = false
                    generatingPreset = nil
                    onDraftGenerated(generatedDraft)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    generatingPreset = nil
                    generationError = error.localizedDescription
                }
            }
        }
    }
}

private extension Post {
    var aiSummarySnippet: String {
        let sanitized = displayText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard sanitized.count > 96 else {
            return sanitized
        }

        let endIndex = sanitized.index(sanitized.startIndex, offsetBy: 93)
        return String(sanitized[..<endIndex]) + "..."
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
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
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

            Text("Share this code or link to invite friends to your Magnet.")
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

            Text("Scan this code on another device to open the invite.")
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
