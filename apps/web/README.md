# 2IGV Reviewer Web

This is the web rebuild scaffold for the 2IGV desktop app. The Swift app remains in the repository as the reference implementation while the web UI is rebuilt in Next.js/TypeScript.

## Recommended Stack

- Next.js + React + TypeScript for the web app
- Supabase for authentication, Postgres database, file storage, and realtime collaboration
- Server-side AI routes for OpenAI, Gemini, Perplexity, and DeepSeek integrations
- Vercel for hosting after the GitHub repository is connected

## Local Setup

Install a Node package manager first. This machine currently has Node, but no `npm`, `pnpm`, or `yarn` on PATH.

```bash
cd apps/web
npm install
npm run dev
```

Then open `http://localhost:3000`.

## AI Key Rule

Never put provider API keys in browser/client code. Use `.env.local` with server-only variables such as `OPENAI_API_KEY`, `GEMINI_API_KEY`, `PERPLEXITY_API_KEY`, and `DEEPSEEK_API_KEY`.

## Migration Notes

The first screen preserves the important human side of the app: review stages, collaborator assignments, locked/unlocked stage access, and AI disclaimers. The next migration pass should connect Supabase persistence and replace demo data.
