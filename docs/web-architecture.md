# 2IGV Web Architecture

## Direction

Rebuild the app as a web product instead of directly converting SwiftUI. The Swift app remains the source of truth for workflow behavior while the web version becomes the deployable multi-user product.

## App Layers

1. Web UI: Next.js, React, TypeScript, CSS modules/global CSS.
2. Auth and sync: Supabase Auth and Postgres row-level security.
3. Project data: projects, members, stage assignments, references, votes, extraction forms, synthesis notes, report sections.
4. File storage: Supabase Storage for PDFs and exported reports.
5. AI gateway: server-only API routes that proxy OpenAI, Gemini, Perplexity, and DeepSeek.
6. Deployment: GitHub repository connected to Vercel.

## Human-AI Principle

AI supports drafting, suggestions, retrieval hints, and summarization. Human reviewers remain accountable for inclusion, exclusion, extraction, QA, synthesis, and report sign-off.

## Core Tables

- users
- projects
- project_members
- ai_connections
- references
- screening_votes
- full_text_votes
- extraction_records
- quality_assessments
- synthesis_notes
- report_sections

## Permission Model

Project owners have all stage access. Other members can be assigned to one or many review process stages:

- searching
- screening
- full_text_retrieval
- full_text_screening
- data_extraction
- synthesis_qa
- report

The UI should hide or lock unassigned stages, and backend routes should enforce the same rule before accepting writes.
