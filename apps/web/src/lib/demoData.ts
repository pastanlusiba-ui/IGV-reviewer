import type { AIConnection, MemberSummary, ProjectDetail, ReviewProcessStage, UserSummary } from "./models";

export const reviewStages: { id: ReviewProcessStage; title: string; short: string; icon: string; tone: string }[] = [
  { id: "searching", title: "1. Searching", short: "Search", icon: "⌕", tone: "ochre" },
  { id: "screening", title: "2. Screening", short: "Screen", icon: "▤", tone: "red" },
  { id: "full_text_retrieval", title: "3. Full Text Retrieval", short: "Retrieve", icon: "◰", tone: "earth" },
  { id: "full_text_screening", title: "4. Full Text Screening", short: "Full Text", icon: "☑", tone: "gold" },
  { id: "data_extraction", title: "5. Data Extraction", short: "Extract", icon: "▦", tone: "green" },
  { id: "synthesis_qa", title: "6. Synthesis & QA", short: "QA", icon: "◇", tone: "amber" },
  { id: "report", title: "7. Report Writing", short: "Report", icon: "✎", tone: "clay" }
];

export const currentUser: UserSummary = {
  id: "user-pasta",
  name: "Pasta Nlusiba",
  email: "pasta@example.com",
  title: "Lead Reviewer"
};

export const initialMembers: MemberSummary[] = [
  { id: currentUser.id, name: currentUser.name, email: currentUser.email, role: "owner", assignedStages: reviewStages.map((stage) => stage.id) },
  { id: "member-grace", name: "Grace Nampiima", email: "grace@example.com", role: "editor", assignedStages: ["searching", "screening", "data_extraction", "synthesis_qa"] },
  { id: "member-daniel", name: "Daniel Ocen", email: "daniel@example.com", role: "reviewer", assignedStages: ["screening", "full_text_screening"] },
  { id: "member-sarah", name: "Sarah Kigozi", email: "sarah@example.com", role: "viewer", assignedStages: ["report"] }
];

export const demoProject: ProjectDetail = {
  id: "project-demo",
  title: "Malaria Prevention in Pregnancy",
  reviewQuestion: "Which interventions reduce malaria-related maternal outcomes in East Africa?",
  stage: "screening",
  health: "on_track",
  progress: 0.42,
  referencesCount: 284,
  teamName: "Maternal Health Lab",
  lead: currentUser,
  members: initialMembers,
  nextActions: [
    "Resolve title and abstract conflicts",
    "Upload missing full-text PDFs",
    "Finalize extraction form fields"
  ]
};

export const defaultConnections: AIConnection[] = [
  { id: "managed-openai", provider: "openai", mode: "managed_access", label: "Managed OpenAI access", createdAt: new Date().toISOString() },
  { id: "own-gemini", provider: "gemini", mode: "own_api_key", label: "Gemini API key", createdAt: new Date().toISOString() }
];
