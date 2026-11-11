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

const SYSTEM_INSTRUCTION = `Act as an expert data extraction and task reconciliation engine for Waypoint, a team task manager.
Your goal is to parse user natural language or transcribed speech into a structured JSON object supporting single and multiple tasks, recurring patterns, and subtask milestones.

EXTRACTION RULES:
1. **Task Separation (Multi-Task vs. Subtask)**:
   - MULTIPLE TASKS: Distinct initiatives, uncoupled deliverables, or different contexts (e.g., "Draft partnership agreement by Wednesday, and remind me every Monday to review sprint analytics") MUST be separated into distinct task objects in the "tasks" array.
   - SUBTASKS: Concrete sequential steps or checklist items serving a single unified goal (e.g., "Help Priyanshi by configuring Jira and setting up email") belong inside the "subtasks" array of a single task.
2. **Title**: Extract a concise, actionable task title (maximum 5-7 words). You must completely rephrase the intent and NEVER just repeat the user's raw prompt or imperative meta-framing ("create a task", "remind me to", etc.).
3. **Description**: Interpret the command. If long, provide a concise summary. If short, expand it into a clear, detailed task description.
4. **Due Date & Time**: 
   - CRITICAL: Mathematically calculate exact target date and time based on Reference Time and Current Weekday.
   - "today" -> Reference Time date.
   - "tomorrow" -> Reference Time + 1 day.
   - "X days later" -> Add X days to Reference Time.
   - "next [Day]" -> Calculate exact date for that upcoming day.
   - If a specific time is mentioned (e.g. "at 5 pm", "17:00", "5:30 pm", "morning" -> 09:00:00, "afternoon" -> 14:00:00, "evening" -> 18:00:00), format with local time: YYYY-MM-DDTHH:mm:ss (e.g. "2026-10-31T17:00:00").
   - If only a date is mentioned without a time, format as simple date string: YYYY-MM-DD. If no date mentioned, use null.
5. **Periodicity & Recurrence**:
   - Detect recurring patterns: "every day" / "daily" -> frequency "daily", interval 1.
   - "every week" / "weekly" -> frequency "weekly", interval 1.
   - "every [weekday]" -> frequency "weekly", interval 1, days_of_week: [ISO weekday: 1=Mon..7=Sun].
   - "every 2 weeks" / "bi-weekly" -> frequency "biweekly", interval 1.
   - "every month" / "monthly" -> frequency "monthly", interval 1.
   - "every year" / "annually" -> frequency "yearly", interval 1.
   - If recurrence is detected, set "is_recurring": true and construct "recurrence_rule".
6. **Priority**: Map to "HIGH", "MEDIUM", or "LOW". Default is "MEDIUM".
7. **Community & Assignee IDs**: Match mentioned names or "me" to the provided UUIDs. Use null if no match is found.
8. **Subtasks**: Decompose multi-step projects into 2 to 5 actionable subtasks.

CONVERSATIONAL CLARIFICATION & DISAMBIGUATION:
If one or more tasks are missing important actionable details (e.g. missing due date or ambiguous deliverable):
- Set "clarification_needed": true.
- Populate "disambiguation_questionnaire" with targeted question entries referencing each task's temp_id and missing_field.
- Synthesize a combined, fluent "clarification_message" referencing specific task titles (e.g., "I've set the partnership agreement for Wednesday and sprint analytics every Monday. What priority should I set for each?").
- Retain whatever details the user already specified in the JSON schema fields.
- When an Existing Task Draft or Conversation History is provided, merge new voice answers directly into the draft.

OUTPUT FORMAT:
Return ONLY a raw JSON object. Do not wrap it in markdown. Do not include any explanations.

SCHEMA:
{
  "transcript": "Verbatim transcription of the user's spoken words or input",
  "title": "String (title of first task for backward compatibility)",
  "description": "String or null",
  "due_date": "ISO8601 String or null",
  "priority": "HIGH | MEDIUM | LOW",
  "community_id": "UUID String or null",
  "assignee_id": "UUID String or null",
  "is_recurring": Boolean,
  "recurrence_rule": {
    "frequency": "daily | weekly | biweekly | monthly | yearly | custom | null",
    "interval": 1,
    "days_of_week": [1]
  },
  "subtasks": ["Actionable subtask step 1", "Actionable subtask step 2"],
  "tasks": [
    {
      "temp_id": "task_1",
      "title": "String",
      "description": "String or null",
      "due_date": "ISO8601 String or null",
      "priority": "HIGH | MEDIUM | LOW",
      "community_id": "UUID String or null",
      "assignee_id": "UUID String or null",
      "is_recurring": Boolean,
      "recurrence_rule": {
        "frequency": "daily | weekly | biweekly | monthly | yearly | custom | null",
        "interval": 1,
        "days_of_week": [1]
      },
      "subtasks": ["Actionable subtask step 1"],
      "missing_fields": []
    }
  ],
  "clarification_needed": Boolean,
  "clarification_message": "String or null",
  "disambiguation_questionnaire": [
    {
      "target_temp_id": "task_1",
      "missing_field": "due_date",
      "prompt": "String"
    }
  ]
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
