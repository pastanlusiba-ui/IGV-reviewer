"use client";

import Image from "next/image";
import { useMemo, useState } from "react";
import { defaultConnections, demoProject, reviewStages } from "@/lib/demoData";
import type { AIConnection, AIConnectionMode, AIProvider, MemberSummary, ProjectDetail, ReviewProcessStage } from "@/lib/models";

const providerLabels: Record<AIProvider, string> = {
  openai: "ChatGPT / OpenAI",
  gemini: "Gemini",
  perplexity: "Perplexity",
  deepseek: "DeepSeek"
};

const providerNotes: Record<AIProvider, string> = {
  openai: "Strong general reasoning. API billing is separate from ChatGPT subscriptions.",
  gemini: "Good for Google-hosted AI workflows. Free-tier availability can vary.",
  perplexity: "Useful for search-grounded answers and citation-heavy workflows.",
  deepseek: "Often low-cost and useful for coding/reasoning, but free access is not guaranteed."
};

export function AppShell() {
  const [screen, setScreen] = useState<"home" | "login" | "welcome" | "projects" | "dashboard" | "settings">("home");
  const [project, setProject] = useState<ProjectDetail>(demoProject);
  const [connections, setConnections] = useState<AIConnection[]>(defaultConnections);
  const [activeMemberId, setActiveMemberId] = useState(project.lead.id);
  const [stageWarning, setStageWarning] = useState("");

  const activeMember = useMemo(
    () => project.members.find((member) => member.id === activeMemberId) ?? project.members[0],
    [activeMemberId, project.members]
  );

  function canAccess(member: MemberSummary, stage: ReviewProcessStage) {
    return member.role === "owner" || member.assignedStages.includes(stage);
  }

  function openStage(stage: ReviewProcessStage) {
    if (!canAccess(activeMember, stage)) {
      const stageTitle = reviewStages.find((item) => item.id === stage)?.short ?? stage;
      setStageWarning(`${activeMember.name} is not assigned to ${stageTitle}. Ask the project owner to update stage assignments.`);
      return;
    }
    setStageWarning(`${activeMember.name} opened ${reviewStages.find((item) => item.id === stage)?.title}.`);
  }

  function updateMemberStages(memberId: string, stage: ReviewProcessStage) {
    setProject((current) => ({
      ...current,
      members: current.members.map((member) => {
        if (member.id !== memberId || member.role === "owner") return member;
        const assignedStages = member.assignedStages.includes(stage)
          ? member.assignedStages.filter((item) => item !== stage)
          : [...member.assignedStages, stage];
        return { ...member, assignedStages };
      })
    }));
  }

  function addConnection(provider: AIProvider, mode: AIConnectionMode) {
    setConnections((current) => [
      ...current,
      {
        id: `${provider}-${crypto.randomUUID()}`,
        provider,
        mode,
        label: `${providerLabels[provider]} ${mode === "own_api_key" ? "API key" : "managed access"}`,
        createdAt: new Date().toISOString()
      }
    ]);
  }

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <Image src="/logo.png" alt="2IGV logo" width={72} height={72} priority />
          <div>
            <strong>2IGV Reviewer</strong>
            <span>Human-led AI review</span>
          </div>
        </div>
        <button className={screen === "home" ? "nav active" : "nav"} onClick={() => setScreen("home")}>Home</button>
        <button className={screen === "projects" || screen === "dashboard" ? "nav active" : "nav"} onClick={() => setScreen("projects")}>Projects</button>
        <button className={screen === "settings" ? "nav active" : "nav"} onClick={() => setScreen("settings")}>Settings</button>
        <div className="sidebar-note">AI can suggest. Humans decide.</div>
      </aside>

      <section className="workspace">
        {screen === "home" && <HomeScreen onContinue={() => setScreen("login")} />}
        {screen === "login" && <LoginScreen onContinue={() => setScreen("welcome")} />}
        {screen === "welcome" && <WelcomeScreen onContinue={() => setScreen("projects")} />}
        {screen === "projects" && <ProjectsScreen project={project} onOpen={() => setScreen("dashboard")} />}
        {screen === "dashboard" && (
          <DashboardScreen
            project={project}
            activeMember={activeMember}
            activeMemberId={activeMemberId}
            setActiveMemberId={setActiveMemberId}
            stageWarning={stageWarning}
            canAccess={canAccess}
            openStage={openStage}
            updateMemberStages={updateMemberStages}
            onSettings={() => setScreen("settings")}
          />
        )}
        {screen === "settings" && (
          <SettingsScreen connections={connections} addConnection={addConnection} />
        )}
      </section>
    </main>
  );
}

function HomeScreen({ onContinue }: { onContinue: () => void }) {
  return (
    <section className="hero panel patterned">
      <p className="eyebrow">Systematic review workspace</p>
      <h1>Evidence reviews with AI assistance, not AI replacement.</h1>
      <p>Bring the desktop workflow to the web: projects, collaborators, stage assignments, AI connections, and synchronized review decisions.</p>
      <button className="primary" onClick={onContinue}>Start review workspace</button>
    </section>
  );
}

function LoginScreen({ onContinue }: { onContinue: () => void }) {
  return (
    <section className="panel compact">
      <p className="eyebrow">Sign in</p>
      <h1>Review team access</h1>
      <input placeholder="Email address" defaultValue="pasta@example.com" />
      <input placeholder="Password" type="password" defaultValue="review" />
      <button className="primary" onClick={onContinue}>Continue</button>
      <p className="fineprint">Web auth will connect to Supabase/Auth.js in the next backend pass.</p>
    </section>
  );
}

function WelcomeScreen({ onContinue }: { onContinue: () => void }) {
  return (
    <section className="panel compact">
      <p className="eyebrow">Welcome back</p>
      <h1>Choose where the human review continues.</h1>
      <p>The web version keeps stage responsibility visible before anyone enters project work.</p>
      <button className="primary" onClick={onContinue}>Go to projects</button>
    </section>
  );
}

function ProjectsScreen({ project, onOpen }: { project: ProjectDetail; onOpen: () => void }) {
  return (
    <section className="panel">
      <div className="section-heading">
        <div>
          <p className="eyebrow">Projects</p>
          <h1>{project.title}</h1>
          <p>{project.reviewQuestion}</p>
        </div>
        <button className="primary" onClick={onOpen}>Open project</button>
      </div>
      <div className="metric-grid">
        <Metric label="Stage" value={project.stage.replaceAll("_", " ")} />
        <Metric label="References" value={String(project.referencesCount)} />
        <Metric label="Team" value={project.teamName} />
      </div>
    </section>
  );
}

function DashboardScreen(props: {
  project: ProjectDetail;
  activeMember: MemberSummary;
  activeMemberId: string;
  setActiveMemberId: (id: string) => void;
  stageWarning: string;
  canAccess: (member: MemberSummary, stage: ReviewProcessStage) => boolean;
  openStage: (stage: ReviewProcessStage) => void;
  updateMemberStages: (memberId: string, stage: ReviewProcessStage) => void;
  onSettings: () => void;
}) {
  const { project, activeMember, activeMemberId, setActiveMemberId, stageWarning, canAccess, openStage, updateMemberStages, onSettings } = props;

  return (
    <section className="dashboard">
      <div className="panel project-header patterned">
        <div>
          <p className="eyebrow">Review question</p>
          <h1>{project.title}</h1>
          <p>{project.reviewQuestion}</p>
        </div>
        <button className="secondary" onClick={onSettings}>AI settings</button>
      </div>

      <div className="metric-grid">
        <Metric label="Progress" value={`${Math.round(project.progress * 100)}%`} />
        <Metric label="References" value={String(project.referencesCount)} />
        <Metric label="Collaborators" value={String(project.members.length)} />
      </div>

      <section className="panel">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Review process</p>
            <h2>Stage access follows collaborator assignment.</h2>
          </div>
          <label className="view-as">
            View as
            <select value={activeMemberId} onChange={(event) => setActiveMemberId(event.target.value)}>
              {project.members.map((member) => <option key={member.id} value={member.id}>{member.name}</option>)}
            </select>
          </label>
        </div>

        <div className="stage-grid">
          {reviewStages.map((stage) => {
            const allowed = canAccess(activeMember, stage.id);
            const assignedCount = project.members.filter((member) => member.role === "owner" || member.assignedStages.includes(stage.id)).length;
            return (
              <button key={stage.id} className={`stage-card ${stage.tone} ${allowed ? "" : "locked"}`} onClick={() => openStage(stage.id)}>
                <span className="stage-icon">{stage.icon}</span>
                <strong>{stage.title}</strong>
                <span>{assignedCount} assigned</span>
                <small>{allowed ? "Available to this user" : "Locked for this user"}</small>
              </button>
            );
          })}
        </div>
        {stageWarning && <p className="notice">{stageWarning}</p>}
      </section>

      <section className="panel">
        <p className="eyebrow">Collaborators</p>
        <h2>Assign people to review stages</h2>
        <div className="member-list">
          {project.members.map((member) => (
            <div key={member.id} className="member-card">
              <div>
                <strong>{member.name}</strong>
                <span>{member.role}</span>
              </div>
              <div className="chips">
                {reviewStages.map((stage) => {
                  const selected = member.role === "owner" || member.assignedStages.includes(stage.id);
                  return (
                    <button
                      key={stage.id}
                      className={selected ? "chip selected" : "chip"}
                      disabled={member.role === "owner"}
                      onClick={() => updateMemberStages(member.id, stage.id)}
                    >
                      {stage.short}
                    </button>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      </section>
    </section>
  );
}

function SettingsScreen({ connections, addConnection }: { connections: AIConnection[]; addConnection: (provider: AIProvider, mode: AIConnectionMode) => void }) {
  const [provider, setProvider] = useState<AIProvider>("openai");
  const [mode, setMode] = useState<AIConnectionMode>("own_api_key");

  return (
    <section className="panel settings">
      <p className="eyebrow">Settings</p>
      <h1>AI Connections</h1>
      <p className="notice">Free or managed API access can be useful for trials, but limits, privacy controls, uptime, and model quality are usually better with paid provider keys. Never store raw API keys in browser-only code.</p>
      <div className="connection-form">
        <select value={provider} onChange={(event) => setProvider(event.target.value as AIProvider)}>
          {(Object.keys(providerLabels) as AIProvider[]).map((item) => <option key={item} value={item}>{providerLabels[item]}</option>)}
        </select>
        <select value={mode} onChange={(event) => setMode(event.target.value as AIConnectionMode)}>
          <option value="own_api_key">Connect my own API key</option>
          <option value="managed_access">Use app-managed/free-tier access</option>
        </select>
        <button className="primary" onClick={() => addConnection(provider, mode)}>Add connection</button>
      </div>
      <p>{providerNotes[provider]}</p>
      <div className="connection-list">
        {connections.map((connection) => (
          <div key={connection.id} className="connection-card">
            <strong>{connection.label}</strong>
            <span>{providerLabels[connection.provider]} • {connection.mode === "own_api_key" ? "Own API key" : "Managed/free-tier"}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}
