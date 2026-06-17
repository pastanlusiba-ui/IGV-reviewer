import SwiftUI

enum ProjectEditorMode {
    case create
    case edit

    var title: String {
        switch self {
        case .create:
            return "Create Project"
        case .edit:
            return "Project Settings"
        }
    }

    var actionLabel: String {
        switch self {
        case .create:
            return "Create Project"
        case .edit:
            return "Save Changes"
        }
    }
}

struct ProjectEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let mode: ProjectEditorMode
    let onSave: (ProjectDraft) -> Void

    @State private var draft: ProjectDraft
    @State private var newMemberName = ""
    @State private var newMemberEmail = ""
    @State private var newMemberRole: MembershipRole = .editor

    init(mode: ProjectEditorMode, draft: ProjectDraft = ProjectDraft(), onSave: @escaping (ProjectDraft) -> Void) {
        self.mode = mode
        self.onSave = onSave
        self._draft = State(initialValue: draft)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    humanLedCard
                    basicsCard
                    picosCard
                    policyCard
                    teamCard
                }
                .padding(24)
            }

            footer
        }
        .frame(minWidth: 920, minHeight: 780)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mode.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Set up the human-led review structure first. AI should support your workflow, not replace reviewer judgement.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color(red: 0.94, green: 0.91, blue: 0.84), Color(red: 0.88, green: 0.93, blue: 0.90)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var humanLedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Human-Led Review", systemImage: "person.2.fill")
                .font(.title3.weight(.semibold))
            Text("The app can draft, suggest, summarize, and surface signals. Humans remain responsible for final screening, extraction, interpretation, and reporting decisions.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.orange.opacity(0.08))
        )
    }

    private var basicsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Basics")
                .font(.title3.weight(.semibold))

            TextField("Project title", text: $draft.title)
                .textFieldStyle(.roundedBorder)

            TextField("Review question", text: $draft.reviewQuestion)
                .textFieldStyle(.roundedBorder)

            TextField("Team name", text: $draft.teamName)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Protocol / background")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                TextEditor(text: $draft.description)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.25))
                    )
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var picosCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PICOS")
                .font(.title3.weight(.semibold))

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    fieldBadge("P")
                    TextField("Population", text: $draft.population)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    fieldBadge("I")
                    TextField("Intervention", text: $draft.intervention)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    fieldBadge("C")
                    TextField("Comparator", text: $draft.comparator)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    fieldBadge("O")
                    TextField("Outcome", text: $draft.outcome)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    fieldBadge("S")
                    TextField("Study design", text: $draft.studyDesign)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var policyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Human & AI Roles")
                .font(.title3.weight(.semibold))

            policyEditor(
                title: "Human decision policy",
                text: $draft.humanReviewPolicy
            )

            policyEditor(
                title: "AI assistance policy",
                text: $draft.aiAssistPolicy
            )
        }
        .padding(20)
        .background(cardBackground)
    }

    private var teamCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Team Roles")
                .font(.title3.weight(.semibold))

            HStack(alignment: .top, spacing: 12) {
                TextField("Collaborator name", text: $newMemberName)
                    .textFieldStyle(.roundedBorder)

                TextField("Email (optional)", text: $newMemberEmail)
                    .textFieldStyle(.roundedBorder)

                Picker("Role", selection: $newMemberRole) {
                    ForEach(MembershipRole.allCases, id: \.self) { role in
                        Text(role.rawValue.capitalized).tag(role)
                    }
                }
                .frame(width: 180)

                Button("Add") {
                    addMember()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if draft.members.isEmpty {
                Text("No collaborators added yet. Human reviewers can still be added later, but the project should always have clear human responsibility.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(draft.members) { member in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name)
                                .font(.headline)
                            if !member.email.isEmpty {
                                Text(member.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(member.role.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            draft.members.removeAll { $0.id == member.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }

                    if member.id != draft.members.last?.id {
                        Divider()
                    }
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

            Button(mode.actionLabel) {
                onSave(draft)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.reviewQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(20)
        .background(.ultraThinMaterial)
    }

    private func addMember() {
        let trimmedName = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        draft.members.append(
            ProjectDraftMember(name: trimmedName, email: newMemberEmail.trimmingCharacters(in: .whitespacesAndNewlines), role: newMemberRole)
        )
        newMemberName = ""
        newMemberEmail = ""
        newMemberRole = .editor
    }

    private func policyEditor(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            TextEditor(text: text)
                .frame(minHeight: 110)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.25))
                )
        }
    }

    private func fieldBadge(_ value: String) -> some View {
        Text(value)
            .font(.caption.weight(.bold))
            .frame(width: 28, height: 28)
            .background(Color.blue.opacity(0.12))
            .foregroundStyle(.blue)
            .clipShape(Circle())
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color(nsColor: .controlBackgroundColor))
    }
}
