// Supabase Edge Function: `ai`
//
// Single place where the Gemini credential is allowed to exist. The Flutter
// client sends a prompt (optionally with recorded audio) plus its Supabase JWT;
// this function authenticates the caller, enforces a per-user daily quota, calls
// Google, and returns the raw JSON text for the client to parse.
//
// Deploy:
//   supabase functions deploy ai --project-ref <ref>
//   supabase secrets set GEMINI_API_KEY=... --project-ref <ref>
//
// The model is fixed by project mandate (AGENTS.md §2): gemini-3.5-flash-lite.
// Do not change MODEL without an explicit instruction from the project owner.

import { createClient } from "jsr:@supabase/supabase-js@2";

const MODEL = "gemini-3.5-flash-lite";
const DAILY_LIMIT = 30;
/// Recordings are capped client-side at 30s; base64 inflates by ~4/3.
const MAX_AUDIO_BASE64_CHARS = 4 * 1024 * 1024 * 1.4;

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SYSTEM_INSTRUCTION = `Act as an expert data extraction engine for Helm, a team task manager.
Your goal is to parse user natural language into a structured JSON object.

EXTRACTION RULES:
1. **Title**: Extract a concise, actionable task title (maximum 5-7 words). You must completely rephrase the intent and NEVER just repeat the user's raw prompt.
2. **Description**: Interpret the command. If long, provide a concise summary. If short, expand it into a clear, detailed task description. Do not just copy the raw input.
3. **Due Date**: 
   - CRITICAL: Mathematically calculate exact target date based on Reference Time and Current Weekday.
   - "today" -> Reference Time date.
   - "tomorrow" -> Reference Time + 1 day.
   - "X days later" -> Add X days to Reference Time.
   - "next [Day]" -> Calculate exact date for that upcoming day.
   - Output MUST be formatted as simple date string: YYYY-MM-DD (e.g., "2026-09-03"). Do NOT include time or 'Z'. If no date mentioned, use null.
4. **Priority**: Map to "HIGH", "MEDIUM", or "LOW". Default is "MEDIUM".
5. **Community ID**: Match mentioned community names to the provided UUIDs. Use null if no match is found.
6. **Assignee ID**: Match mentioned names or "me" to the member UUIDs. Use null if no match is found.

OUTPUT FORMAT:
Return ONLY a raw JSON object. Do not wrap it in markdown. Do not include any explanations.

CONVERSATIONAL CLARIFICATION:
If the user's command is missing important actionable details (e.g., they say "remind me to prepare presentation" but give no due date/time, or "add task for the client" without clear title or deadline), engage in a natural conversation:
- Set "clarification_needed" to true.
- Set "clarification_message" to a concise, friendly question asking specifically for the missing detail (e.g., "When should this presentation be ready?", "What is the deadline for this task?").
- Retain whatever details the user already specified in the JSON schema fields.
- When an Existing Task Draft or Conversation History is provided, merge new voice answers directly into the draft.

SCHEMA:
{
  "title": "String",
  "description": "String or null",
  "due_date": "ISO8601 String or null",
  "priority": "HIGH | MEDIUM | LOW",
  "community_id": "UUID String or null",
  "assignee_id": "UUID String or null",
  "clarification_needed": Boolean,
  "clarification_message": "String or null"
}`;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ error: "Sign in to use AI commands." }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) {
    return json({ error: "AI proxy is not configured." }, 500);
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    return json({ error: "Sign in to use AI commands." }, 401);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Invalid request body." }, 400);
  }

  const prompt = typeof payload.prompt === "string" ? payload.prompt.trim() : "";
  if (!prompt) {
    return json({ error: "A prompt is required." }, 400);
  }

  const audioBase64 =
    typeof payload.audio_base64 === "string" ? payload.audio_base64 : null;
  if (audioBase64 && audioBase64.length > MAX_AUDIO_BASE64_CHARS) {
    return json({ error: "That recording is too long. Keep it under 30 seconds." }, 413);
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return json({ error: "AI proxy is not configured." }, 500);
  }

  // Quota is consumed only after the request has been validated, so malformed
  // calls cannot burn a user's daily allowance.
  const { data: remaining, error: quotaError } = await supabase.rpc("consume_ai_quota", {
    p_limit: DAILY_LIMIT,
  });

  if (quotaError) {
    if (`${quotaError.message}`.includes("rate_limit_exceeded")) {
      return json({ error: "Daily AI limit reached. Try again tomorrow." }, 429);
    }
    console.error("consume_ai_quota failed", quotaError);
    return json({ error: "AI quota check failed." }, 500);
  }

  const parts: Record<string, unknown>[] = [{ text: prompt }];
  if (audioBase64) {
    parts.unshift({
      inlineData: {
        mimeType: typeof payload.audio_mime_type === "string"
          ? payload.audio_mime_type
          : "audio/wav",
        data: audioBase64,
      },
    });
  }

  let upstream: Response;
  try {
    upstream = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
          contents: [{ role: "user", parts }],
          generationConfig: { responseMimeType: "application/json" },
        }),
      },
    );
  } catch (e) {
    console.error("Gemini request failed", e);
    return json({ error: "Could not reach the AI provider." }, 502);
  }

  if (!upstream.ok) {
    const detail = await upstream.text();
    console.error("Gemini error", upstream.status, detail);
    if (upstream.status === 429) {
      return json({ error: "The AI provider is busy. Try again in a moment." }, 429);
    }
    return json({ error: "The AI provider rejected the request." }, 502);
  }

  const data = await upstream.json();
  const text: string = (data?.candidates?.[0]?.content?.parts ?? [])
    .map((part: { text?: string }) => part.text ?? "")
    .join("")
    .trim();

  if (!text) {
    return json({ error: "The AI provider returned an empty response." }, 502);
  }

  return json({ text, remaining: typeof remaining === "number" ? remaining : null });
});
