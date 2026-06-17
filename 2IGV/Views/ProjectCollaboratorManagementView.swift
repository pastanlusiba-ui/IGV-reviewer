import SwiftUI

struct ProjectCollaboratorManagementView: View {
    @Environment(\.dismiss) private var dismiss

    let project: ProjectDetail
    let onSave: (ProjectDraft) -> Void

    @State private var draft: ProjectDraft
    @State private var newMemberName = ""
    @State private var newMemberEmail = ""
    @State private var newMemberRole: MembershipRole = .reviewer
    @State private var newMemberStages: Set<ReviewProcessStage> = [.screening]

    init(project: ProjectDetail, onSave: @escaping (ProjectDraft) -> Void) {
        self.project = project
        self.onSave = onSave
        self._draft = State(initialValue: ProjectDraft(project: project))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    invitationCard
                    addCollaboratorCard
                    rosterCard
                }
                .padding(24)
            }

            footer
        }
        .frame(minWidth: 860, minHeight: 700)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Manage Collaborators")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Keep responsibility visible. AI can support the work, but human roles, review ownership, and conflict resolution should stay explicit.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color(red: 0.92, green: 0.90, blue: 0.81), Color(red: 0.85, green: 0.92, blue: 0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var invitationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Human Accountability", systemImage: "person.3.sequence.fill")
                .font(.title3.weight(.semibold))
            Text("Owners guide the protocol and final decisions. Editors can shape the shared workspace. Reviewers screen and extract evidence. Viewers can monitor progress without changing decisions.")
                .foregroundStyle(.secondary)
            Text("Use email addresses where possible so this can map cleanly to real user accounts when the backend is connected.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.orange.opacity(0.09))
        )
    }

    private var addCollaboratorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Invite or Add Collaborators")
                .font(.title3.weight(.semibold))

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    TextField("Full name", text: $newMemberName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Email address", text: $newMemberEmail)
                        .textFieldStyle(.roundedBorder)
                    Picker("Role", selection: $newMemberRole) {
                        ForEach(MembershipRole.allCases.filter { $0 != .owner }, id: \.self) { role in
                            Text(role.rawValue.capitalized).tag(role)
                        }
                    }
                    .frame(width: 180)
                    Button("Add Collaborator") {
                        addMember()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newMemberStages.isEmpty)
                }
            }

            stageAssignmentPicker(
                title: "Assign Review Stages",
                selectedStages: $newMemberStages,
                locked: false
            )
        }
        .padding(20)
        .background(cardBackground)
    }

    private var rosterCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Team")
                .font(.title3.weight(.semibold))

            if draft.members.isEmpty {
                Text("No collaborators have been added yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach($draft.members) { $member in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Name", text: $member.name)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Email address", text: $member.email)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Picker("Role", selection: $member.role) {
                                ForEach(roleOptions(for: member), id: \.self) { role in
                                    Text(role.rawValue.capitalized).tag(role)
                                }
                            }
                            .frame(width: 180)
                            .disabled(member.role == .owner)

                            Spacer()

                            if member.role == .owner {
                                Text("Owner")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.brown.opacity(0.16)))
                            } else {
                                Button(role: .destructive) {
                                    draft.members.removeAll { $0.id == member.id }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        if member.role == .owner {
                            Text("The project owner remains the accountable lead for protocol and final human decisions.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        stageAssignmentPicker(
                            title: member.role == .owner ? "Stage Assignments" : "Assigned Review Stages",
                            selectedStages: Binding(
                                get: { Set(member.assignedStages) },
                                set: { member.assignedStages = orderedStages(from: $0) }
                            ),
                            locked: member.role == .owner
                        )
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Save Collaborators") {
                onSave(draft)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(draft.members.first(where: { $0.role == .owner }) == nil || draft.members.contains { $0.role != .owner && $0.assignedStages.isEmpty })
        }
        .padding(20)
        .background(.ultraThinMaterial)
    }

    private func stageAssignmentPicker(
        title: String,
        selectedStages: Binding<Set<ReviewProcessStage>>,
        locked: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                if locked {
                    Label("All stages", systemImage: "lock.open.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Button("All") {
                        selectedStages.wrappedValue = Set(ReviewProcessStage.allCases)
                    }
                    .buttonStyle(.borderless)

                    Button("Clear") {
                        selectedStages.wrappedValue = []
                    }
                    .buttonStyle(.borderless)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(ReviewProcessStage.allCases) { stage in
                    let isSelected = locked || selectedStages.wrappedValue.contains(stage)

                    Button {
                        var nextStages = selectedStages.wrappedValue
                        if nextStages.contains(stage) {
                            nextStages.remove(stage)
                        } else {
                            nextStages.insert(stage)
                        }
                        selectedStages.wrappedValue = nextStages
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            Text(stage.shortLabel)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? Color(red: 0.02, green: 0.45, blue: 0.72) : Color(nsColor: .windowBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color(red: 0.02, green: 0.45, blue: 0.72) : Color.black.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(locked)
                }
            }

            if !locked && selectedStages.wrappedValue.isEmpty {
                Text("Choose at least one stage before saving this collaborator.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.72))
        )
    }

    private func addMember() {
        let trimmedName = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !newMemberStages.isEmpty else { return }

        draft.members.append(
            ProjectDraftMember(
                name: trimmedName,
                email: newMemberEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                role: newMemberRole,
                assignedStages: orderedStages(from: newMemberStages)
            )
        )
        newMemberName = ""
        newMemberEmail = ""
        newMemberRole = .reviewer
        newMemberStages = [.screening]
    }

    private func roleOptions(for member: ProjectDraftMember) -> [MembershipRole] {
        member.role == .owner ? [.owner] : MembershipRole.allCases.filter { $0 != .owner }
    }

    private func orderedStages(from stages: Set<ReviewProcessStage>) -> [ReviewProcessStage] {
        ReviewProcessStage.allCases.filter { stages.contains($0) }
    }
}

private let cardBackground = RoundedRectangle(cornerRadius: 22)
    .fill(Color(nsColor: .controlBackgroundColor))
