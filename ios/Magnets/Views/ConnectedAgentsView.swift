import SwiftData
import SwiftUI

// MARK: - Connected Agents List (Settings entry point)

struct ConnectedAgentsListView: View {
    @Query(sort: \AgentConnection.createdAt, order: .reverse) private var allAgents: [AgentConnection]

    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingAddSheet = false
    @State private var agentToDelete: AgentConnection?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Connected Agents")
                    .font(.title3.weight(.bold))

                Spacer()

                Button {
                    isPresentingAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color(hex: "#4B43E8"))
                }
            }

            if allAgents.isEmpty {
                emptyState
            } else {
                VStack(spacing: 12) {
                    ForEach(allAgents, id: \.id) { agent in
                        AgentRowView(agent: agent, onDelete: {
                            agentToDelete = agent
                        })
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingAddSheet) {
            AddAgentSheet()
        }
        .alert("Remove Agent", isPresented: .init(
            get: { agentToDelete != nil },
            set: { if !$0 { agentToDelete = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let agent = agentToDelete {
                    modelContext.delete(agent)
                    try? modelContext.save()
                    agentToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                agentToDelete = nil
            }
        } message: {
            if let agent = agentToDelete {
                Text("Remove \"\(agent.name)\" from its Magnet? This can't be undone.")
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("No agents connected", systemImage: "sparkles")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color(hex: "#4B43E8"))

            Text("Tap + to attach an AI helper to a Magnet. It will post scheduled updates like morning greetings, quotes, or weather.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Agent Row

private struct AgentRowView: View {
    @Bindable var agent: AgentConnection
    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isRunning = false
    @State private var runResult: String?
    @State private var runError: String?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: agent.agentType.symbolName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(agent.isEnabled ? Color(hex: "#4B43E8") : .secondary)
                .frame(width: 42, height: 42)
                .background(
                    (agent.isEnabled ? Color(hex: "#4B43E8").opacity(0.1) : Color.gray.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(agent.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(agent.isEnabled ? .primary : .secondary)

                Text(agent.agentType.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: agent.schedule.symbolName)
                        .font(.caption2)
                    Text(agent.scheduleDescription)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                if let magnetName = agent.magnet?.name {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.heart.fill")
                            .font(.caption2)
                        Text(magnetName)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(Color(hex: "#4B43E8").opacity(0.7))
                }

                if let lastPost = agent.lastPostAt {
                    Text("Last post \(lastPost.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(spacing: 8) {
                Toggle("", isOn: $agent.isEnabled)
                    .labelsHidden()
                    .tint(Color(hex: "#4B43E8"))
                    .onChange(of: agent.isEnabled) { _, _ in
                        try? modelContext.save()
                    }

                Button {
                    runAgentNow()
                } label: {
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color(hex: "#4B43E8"))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isRunning || !agent.isEnabled)
                .accessibilityLabel("Run agent now")

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .bottom) {
            if let runResult {
                Text("✓ \(runResult)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color(hex: "#0AB8A2"))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .offset(y: 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if let runError {
                Text("⚠ \(runError)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color(hex: "#FF6B6B"))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .offset(y: 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.bottom, (runResult != nil || runError != nil) ? 12 : 0)
        .animation(.easeInOut(duration: 0.3), value: runResult)
        .animation(.easeInOut(duration: 0.3), value: runError)
    }

    private func runAgentNow() {
        isRunning = true
        runResult = nil
        runError = nil

        Task {
            do {
                let text = try await AgentPostService.runAgentLocally(agent, in: modelContext)
                let preview = String(text.prefix(60))
                runResult = preview
                // Auto-dismiss after 4 seconds
                try? await Task.sleep(for: .seconds(4))
                runResult = nil
            } catch {
                runError = error.localizedDescription
                try? await Task.sleep(for: .seconds(4))
                runError = nil
            }
            isRunning = false
        }
    }
}

// MARK: - Add Agent Sheet

private struct AddAgentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Magnet.createdAt, order: .reverse) private var magnets: [Magnet]

    @State private var selectedType: AgentType = .morningBriefing
    @State private var name: String = ""
    @State private var schedule: AgentSchedule = .daily
    @State private var scheduledHour: Int = 8
    @State private var scheduledMinute: Int = 0
    @State private var customPrompt: String = ""
    @State private var selectedMagnet: Magnet?
    @State private var errorMessage: String?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedMagnet != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    typePickerCard
                    nameCard
                    magnetPickerCard
                    scheduleCard

                    if selectedType == .custom {
                        customPromptCard
                    }

                    if let errorMessage {
                        errorBanner(errorMessage)
                    }
                }
                .padding(24)
                .frame(maxWidth: 680)
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
            .navigationTitle("Add Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveAgent() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(32)
        .presentationDragIndicator(.visible)
        .onAppear {
            name = selectedType.displayName
            scheduledHour = selectedType.defaultScheduleHour
            if selectedMagnet == nil {
                selectedMagnet = magnets.first
            }
        }
        .onChange(of: selectedType) { _, newType in
            if name.isEmpty || AgentType.allCases.map(\.displayName).contains(name) {
                name = newType.displayName
            }
            scheduledHour = newType.defaultScheduleHour
        }
    }

    // MARK: - Cards

    private var typePickerCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Agent Type")
                    .font(.headline.weight(.bold))

                ForEach(AgentType.allCases) { type in
                    Button {
                        selectedType = type
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: type.symbolName)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(selectedType == type ? .white : Color(hex: "#4B43E8"))
                                .frame(width: 38, height: 38)
                                .background(
                                    selectedType == type ? Color(hex: "#4B43E8") : Color(hex: "#4B43E8").opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(typeDescription(for: type))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color(hex: "#4B43E8"))
                            }
                        }
                        .padding(12)
                        .background(
                            selectedType == type ? Color(hex: "#4B43E8").opacity(0.06) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var nameCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Name")
                    .font(.headline.weight(.bold))

                TextField("e.g. Morning Bot", text: $name)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var magnetPickerCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Magnet")
                    .font(.headline.weight(.bold))

                Text("Choose which Magnet this agent posts to.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if magnets.isEmpty {
                    Label("Create a Magnet first", systemImage: "exclamationmark.triangle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(magnets, id: \.id) { magnet in
                        Button {
                            selectedMagnet = magnet
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(hex: magnet.primaryColorHex))
                                    .frame(width: 12, height: 12)

                                Text(magnet.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                if selectedMagnet?.id == magnet.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(hex: "#4B43E8"))
                                }
                            }
                            .padding(12)
                            .background(
                                selectedMagnet?.id == magnet.id ? Color(hex: "#4B43E8").opacity(0.06) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var scheduleCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Schedule")
                    .font(.headline.weight(.bold))

                Picker("Frequency", selection: $schedule) {
                    ForEach(AgentSchedule.allCases) { sched in
                        Label(sched.displayName, systemImage: sched.symbolName)
                            .tag(sched)
                    }
                }
                .pickerStyle(.segmented)

                if schedule != .hourly {
                    HStack(spacing: 12) {
                        Picker("Hour", selection: $scheduledHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(String(format: "%d:00", hour)).tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 100)

                        Picker("Minute", selection: $scheduledMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { min in
                                Text(String(format: ":%02d", min)).tag(min)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 100)
                    }
                }
            }
        }
    }

    private var customPromptCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Custom Prompt")
                    .font(.headline.weight(.bold))

                Text("Tell the agent what kind of content to generate.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("e.g. Write a fun fact about space", text: $customPrompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .lineLimit(2...5)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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

    // MARK: - Helpers

    private func typeDescription(for type: AgentType) -> String {
        switch type {
        case .morningBriefing: return "Warm morning greeting every day"
        case .dailyQuote: return "Inspirational or themed quote"
        case .weather: return "Local weather summary"
        case .custom: return "You write the prompt"
        }
    }

    private func saveAgent() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let magnet = selectedMagnet else {
            errorMessage = "Give the agent a name and pick a Magnet."
            return
        }

        let agent = AgentConnection(
            name: trimmedName,
            agentType: selectedType,
            schedule: schedule,
            scheduledHour: scheduledHour,
            scheduledMinute: scheduledMinute,
            isEnabled: true,
            customPrompt: selectedType == .custom ? customPrompt : nil,
            magnet: magnet
        )

        modelContext.insert(agent)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Couldn't save the agent. Try again."
        }
    }
}

// MARK: - Per-Magnet Agent Management Sheet

struct MagnetAgentsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let magnet: Magnet

    @State private var isPresentingAddSheet = false
    @State private var agentToDelete: AgentConnection?

    private var magnetAgents: [AgentConnection] {
        (magnet.agents).sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard

                    if magnetAgents.isEmpty {
                        emptyCard
                    } else {
                        VStack(spacing: 12) {
                            ForEach(magnetAgents, id: \.id) { agent in
                                AgentRowView(agent: agent, onDelete: {
                                    agentToDelete = agent
                                })
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 680)
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
            .navigationTitle("Agents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color(hex: "#4B43E8"))
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingAddSheet) {
            AddAgentSheet()
        }
        .alert("Remove Agent", isPresented: .init(
            get: { agentToDelete != nil },
            set: { if !$0 { agentToDelete = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let agent = agentToDelete {
                    modelContext.delete(agent)
                    try? modelContext.save()
                    agentToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                agentToDelete = nil
            }
        } message: {
            if let agent = agentToDelete {
                Text("Remove \"\(agent.name)\" from \(magnet.name)? This can't be undone.")
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Agents for \(magnet.name)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text("\(magnetAgents.count) connected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(hex: magnet.primaryColorHex))
                    .padding(14)
                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.24), lineWidth: 1)
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color(hex: magnet.primaryColorHex))

            Text("No agents yet")
                .font(.title3.weight(.bold))

            Text("Add an agent to post scheduled updates — morning greetings, quotes, weather, or anything you define.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                isPresentingAddSheet = true
            } label: {
                Label("Add First Agent", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: magnet.primaryColorHex))
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
    }
}
