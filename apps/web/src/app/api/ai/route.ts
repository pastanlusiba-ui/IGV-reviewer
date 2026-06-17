import { NextRequest, NextResponse } from "next/server";

const providerEnv: Record<string, string | undefined> = {
  openai: process.env.OPENAI_API_KEY,
  gemini: process.env.GEMINI_API_KEY,
  perplexity: process.env.PERPLEXITY_API_KEY,
  deepseek: process.env.DEEPSEEK_API_KEY
};

export async function POST(request: NextRequest) {
  const body = await request.json().catch(() => ({}));
  const provider = String(body.provider ?? "openai").toLowerCase();
  const apiKey = providerEnv[provider];

  if (!apiKey) {
    return NextResponse.json(
      {
        error: "AI provider is not configured on the server.",
        provider,
        humanPolicy: "AI suggestions must remain advisory. Human reviewers make final decisions."
      },
      { status: 501 }
    );
  }

  return NextResponse.json(
    {
      error: "Provider adapter not implemented yet.",
      provider,
      nextStep: "Add provider-specific fetch logic here after API-key storage is finalized."
    },
    { status: 501 }
  );
}
