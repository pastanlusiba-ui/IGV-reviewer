export type AIProvider = "openai" | "gemini" | "perplexity" | "deepseek";
export type AIConnectionMode = "managed_access" | "own_api_key";
export type MembershipRole = "owner" | "editor" | "reviewer" | "viewer";

export type ReviewProcessStage =
  | "searching"
  | "screening"
  | "full_text_retrieval"
  | "full_text_screening"
  | "data_extraction"
  | "synthesis_qa"
  | "report";

export interface UserSummary {
  id: string;
  name: string;
  email: string;
  title: string;
}

export interface MemberSummary {
  id: string;
  name: string;
  email?: string;
  role: MembershipRole;
  assignedStages: ReviewProcessStage[];
}

export interface AIConnection {
  id: string;
  provider: AIProvider;
  mode: AIConnectionMode;
  label: string;
  createdAt: string;
}

export interface ProjectDetail {
  id: string;
  title: string;
  reviewQuestion: string;
  stage: ReviewProcessStage;
  health: "on_track" | "at_risk" | "blocked";
  progress: number;
  referencesCount: number;
  teamName: string;
  lead: UserSummary;
  members: MemberSummary[];
  nextActions: string[];
}
