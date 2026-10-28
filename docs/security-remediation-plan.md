# Helm — Security & Reliability Remediation Plan

| | |
|---|---|
| **Repository** | `zedrock-coding/Helm` (formerly `EventsManagerTaskApp`), branch `highest`, HEAD `338723c` |
| **App version** | Helm `0.3.3+8` (`helm/`) |
| **Plan date** | 2026-10-28 |
| **Scope** | All P0–P3 findings from the 2026-10-28 static analysis, plus 4 findings discovered during planning recon |
| **Status** | Proposed — Phase 0 requires owner action before any code ships |

---

## 0. Executive summary

The app is functionally complete but three classes of problems are shipping right now:

1. **Secrets are public.** A live Gemini API key is committed to git at `helm/.env:1` *and* bundled into the Flutter web build as an asset, so it is downloadable from the deployed site. It also exists in git history, so removing the file does not make the key private.
2. **A privileged admin tool is deployed to production.** `helm/web/admin.html` is copied verbatim into `build/web/` and served at `/admin.html`. It instructs the operator to paste a **`service_role`** key into a browser field, and renders `feedback` rows with `innerHTML` interpolation (`admin.html:170-178`) — stored XSS with a full-RLS-bypass credential in the same DOM.
3. **The two "business rules" the product advertises are enforced only in Flutter.** The 2-comment limit (`task_detail_page.dart:473-479`) and the weighted RBAC lock (`task_detail_page.dart:59-91`) have no server-side counterpart, and the repository contains **no SQL at all** — there is no schema, no RLS policy, and no migration history to audit.

Everything else (sync correctness, stale UI, notification delivery, tech debt) is ordinary engineering work: ~25 discrete items, all localized, all fixable in ~10–14 engineer-days.

**Recommended sequencing:** stop the bleeding in hours (Phase 0), remove secrets from the client in days (Phases 1–2), make the server enforce the rules (Phase 3), then correctness and UX (Phases 4–5), then tooling/CI so it cannot regress (Phase 6).

### Decisions required from the owner

| # | Decision | Recommended answer |
|---|---|---|
| D1 | Rotate the exposed Gemini key now? | **Yes, before anything else.** Purging history is cosmetic afterwards. |
| D2 | Rotate the Supabase `service_role` JWT? | **Yes if it was ever pasted into `admin.html`** (it is deployed publicly). Rotating it breaks nothing in the app; the app only uses `anon`. |
| D3 | Purge `helm/.env` from git history (`filter-repo` + force-push)? | Optional. Only worth it for compliance optics; every clone/branch must re-clone. Default: **skip**, rotate instead. |
| D4 | AI proxy host: Supabase Edge Function or Vercel Function? | **Supabase Edge Function** — JWT verification, secret storage and rate limiting come free, and it works for Android/Windows/web from one endpoint. |
| D5 | Where do SQL migrations live? | **`supabase/migrations/` in this repo**, applied via CLI/CI, not hand-pasted into the dashboard. |
| D6 | Delete `admin.html`, or move it out of `web/`? | **Move to `tools/admin/`** and serve it locally only; it is only useful as a local operator tool. |

---

## 1. Threat model (why the ordering is what it is)

| Threat | Current exposure | Phase that closes it |
|---|---|---|
| Anyone reads the Gemini key from `/assets/.env` (unauthenticated) or from repo history/clones | **Live** | 1 |
| Anyone with the repo/history reads the same key | **Live** | 0 (rotate) / 1 |
| Malicious feedback row executes JS in the admin dashboard, stealing the pasted `service_role` | **Live** | 0 |
| Member edits an Owner/Admin task via a custom client (bypasses the Flutter `AbsorbPointer`) | **Live** | 3 |
| Member posts unlimited comments via a custom client | **Live** | 3 |
| Unauthenticated spam into `feedback` (anon `insert`, no captcha, no rate limit) | **Live** | 3 |
| Losing local edits when another device touches title/status/order | **Live** | 4 |

Client-side UX locking stays — it is a usability feature. The server becomes the source of truth for *authorization*.

---

## 2. Issue register

Legend — **S** security, **D** data integrity, **U** UX/correctness bug, **T** tech debt. Effort is engineer-time, excluding external console work.

### 2.1 Security

| ID | Sev | Issue | Evidence | Fix |
|---|---|---|---|---|
| S1 | **P0** | Live Gemini API key committed | `helm/.env:1`; tracked since `273bf39` | Rotate key; `git rm --cached helm/.env`; `.env.example`; secret scanning |
| S2 | **P0** | `.env` shipped as a Flutter asset → served from web deployment | `pubspec.yaml:55`, `main.dart:44`, `.github/workflows/deploy_web.yml:23` | Remove asset; delete `flutter_dotenv`; `AppConfig` via `--dart-define`; then Phase 2 removes the client key entirely |
| S3 | **P0** | Public `admin.html` harvests `service_role` and has stored XSS | `helm/web/admin.html:114-116,146,170-178` | Phase 0: move to `tools/admin/` (not deployed). Phase 3: replace with an authenticated admin role + escaped rendering |
| S4 | **P0** | RBAC + 2-comment limit enforced client-side only; no SQL in repo | `task_detail_page.dart:59-91,473-479`; `git ls-files '*.sql'` → empty | Phase 3: RLS policies + triggers mirroring AGENTS.md §5 exactly |
| S5 | P1 | Unauthenticated public `feedback` insert, no abuse controls | `helm/web/feedback.html:191-195` | Phase 3: rate limit + captcha or authenticated insert; revoke `anon` insert |
| S6 | P1 | Supabase URL + anon key hardcoded in 3 places | `main.dart:47-50`, `feedback.html:165-166`, `admin.html:125` | Phase 1: single `AppConfig`; inject into static HTML at build/deploy time |
| S7 | P1 | `innerHTML` interpolation of DB fields (XSS) beyond admin page | `admin.html:170-178` | Escaping helper; move to text nodes |
| S8 | P2 | Notification/task data trusted to be well-formed (`as bool`, `DateTime.parse` without guard) | `notification_feed.dart:117-118`, `task_provider.dart:110-117` | Phase 5: defensive parsing helpers |

### 2.2 Data integrity

| ID | Sev | Issue | Evidence | Fix |
|---|---|---|---|---|
| D1 | **P1** | Seeded categories get integer keys (`addAll`), all lookups are by UUID | `hive_database.dart:33-40` vs `task_provider.dart:299`, `task_item_card.dart:200` | Seed with `put(cat.id!, cat)`; one-time migration for existing installs |
| D2 | **P1** | Realtime pull overwrites whole local record when `status/title/order` differ; ignores `updated_at` | `task_provider.dart:120-123` | Compare `updated_at`; merge field-wise; never clobber a record with a pending queue entry |
| D3 | **P1** | Remote deletes never reach Hive → ghost tasks on other devices, inflated streaks/calendar | `task_provider.dart:97-125` | Diff snapshot vs box; tombstone deletes |
| D4 | P1 | Community tasks written into the personal Hive box by the unfiltered stream | `task_provider.dart:97` | Add `.eq('community_id', null)` or route by `community_id` into a separate box |
| D5 | P1 | Reorder + category CRUD bypass the offline queue; unawaited network call | `task_provider.dart:270,286-309` | Route all mutations through one `_mutate()` helper that always queues on failure |
| D6 | P1 | Subtask completion state lost on edit | `add_event_page.dart:151-154` | Match by title/id when rebuilding; preserve `is_completed` |
| D7 | P1 | Due date cannot be cleared; edits always re-stamp a date | `add_event_page.dart:157-181` | `Clear` affordance; pass `null` through `updateTask` |
| D8 | P1 | `deleteTask` silently no-ops when the row isn't in Hive | `task_provider.dart:551-552` | Delete locally *and* enqueue remote delete regardless |
| D9 | P2 | `_isSyncing` can stick `true`; queue keyed only by record id, not table | `sync_service.dart:40,99-125` | `try/finally`; key = `table:id`; backoff + retry budget |
| D10 | P2 | Failed queue items have no backoff and no surface to the user | `sync_service.dart:111-121` | Retry with exponential backoff; expose "N changes pending" badge |

### 2.3 UX / correctness

| ID | Sev | Issue | Evidence | Fix |
|---|---|---|---|---|
| U1 | P1 | App header ignores `AppShell.title` — Settings/Calendar show "Personal Tasks" | `app_shell.dart:427` (`widget.title` never read) | Use `widget.title` |
| U2 | P1 | Desktop detail panel is a stale snapshot; not cleared on tab/community switch | `main.dart:199,320` | Resolve the selected task from the provider by id on each build; clear on tab change |
| U3 | P1 | Realtime streams re-created on every build → re-subscribe churn (probable cause of duplicate comments) | `main.dart:359`, `task_detail_page.dart:460`, `notification_bell.dart:23`, `notification_feed.dart:82` | Hoist to `initState`/provider, memoize by key |
| U4 | P1 | Android 13+ notification permission never requested at startup → reminders silently never appear | `velocity_dashboard.dart:236-253` only | Request once post-auth with rationale; persist result |
| U5 | P1 | `tz.local` is UTC because only `initializeTimeZones()` is called → reminders fire at the wrong hour | `notification_service.dart:29,265` | `flutter_timezone` + `tz.setLocalLocation` |
| U6 | P2 | Comment limit recomputed off a fresh stream each build; dedupe hack | `task_detail_page.dart:459-477` | Depends on U3 + Phase 3 trigger |
| U7 | P2 | "Adjust Daily Goal" is dead UI | `velocity_dashboard.dart:255-270` | Persist goal in `Settings` or remove |
| U8 | P2 | Quick font-size S/M/L maps to indices 1/3/4 (M → 1.2×) | `velocity_dashboard.dart:220-227` | Map to 1/2/3 |
| U9 | P2 | Declining EULA on web does nothing (`SystemNavigator.pop` is a no-op in browsers) | `main.dart:129` | Block the shell behind the dialog on web |
| U10 | P2 | `record` and `speech_to_text` capture the mic simultaneously | `command_bar.dart:47-72` | Record only; use `record` stream → STT fallback, or STT-only preview mode |
| U11 | P2 | Unguarded casts/parses on notification rows | `notification_feed.dart:117-118` | Defensive helpers |
| U12 | P2 | Assignee avatar always shows initials "A" | `task_item_card.dart:190-196` | Resolve member names (cache community roster) |
| U13 | P2 | Search covers personal tasks only | `task_search_delegate.dart:58-61` | Search Hive + selected community stream |
| U14 | P2 | Haptic fired in `initState` of a 100 ms repeating animation | `main.dart:440-452` | Haptic on drag start only |
| U15 | P3 | Notification IDs are `taskId.hashCode` → collisions between `+1`/`+2` buckets | `notification_service.dart:249,316-327` | Deterministic hash → stable int range, or a stored int id |
| U16 | P3 | All plugin failures swallowed → silent notification blackout | `notification_service.dart:51,162` | Surface a one-time diagnostic in Settings |
| U17 | P3 | Dialog edit mode has no unsaved-changes guard | `add_event_page.dart:250-252` vs `254-262` | Wrap dialog in `PopScope` too |
| U18 | P3 | RBAC check treats a non-member creator as weight 1 → lock bypass | `task_detail_page.dart:70-80` | Fail closed: unknown creator ⇒ read-only |
| U19 | P3 | No email-format validation; sign-up doesn't switch to sign-in | `auth_screen.dart:163,207-215` | Validate + suggest next step |
| U20 | P3 | `CommunityManagePage` nests a second `AppShell`; `FutureBuilder` refetches per build | `community_manage_page.dart:124,213` | Plain `Scaffold`; cache the future |

### 2.4 Tech debt

| ID | Issue | Evidence | Fix |
|---|---|---|---|
| T1 | Deprecations muted; 83 `withOpacity`, 3 `DropdownButtonFormField(value:)` | `analysis_options.yaml:7`, `flutter analyze` → clean | Re-enable, codemod to `withValues(alpha:)` / `initialValue:` |
| T2 | AGENTS.md documents flags that no longer exist (`--web-renderer` removed in Flutter 3.29+) and a directory map that doesn't match `lib/` | `AGENTS.md:52-63`; verified `flutter build web --help` | Rewrite §3–§4 |
| T3 | "Cactus Needle 3, 121M params" is a heuristic stub; `transcribeAudioLocally` always returns `null` | `needle_engine.dart:40,50-54,63-157` | Either wire a real on-device model or rename to `LocalHeuristicParser` and drop the claim |
| T4 | `widget_test.dart` renders a `Text`; notification tests only prove exceptions are caught | `test/widget_test.dart`, `test/notification_settings_test.dart` | Real provider/sync/parse tests |
| T5 | CI has no analyze/test gate, runs only on `highest`, `checkout@v3`, drops the documented `--pwa-strategy=none` | `deploy_web.yml` | PR workflow + gate + `--pwa-strategy=none` |
| T6 | 590-line `TaskProvider`; 4 copies of the same upsert-or-queue block | `task_provider.dart:224-251,352-380,397-414,522-539,578-589` | Extract `TaskRepository` + `_mutate()` |
| T7 | No schema/migrations/RPC contracts in repo | — | Phase 3 |
| T8 | `SupabaseService()` constructed ad-hoc; only `AiService` is injected | 11 call sites | Provider/DI |
| T9 | `void cancelRecording() async` | `audio_recording_service.dart:91` | `Future<void>` |
| T10 | No LICENSE; README drift (claims Flutter ^3.38.4, "Helm 3.0") | `README.md:46,69` | Add LICENSE, fix versions |
| T11 | `.idea/`, `.artifacts/`, `.vercel/` churn in working tree | `git status` clean but dirs present | Ignore untracked tool dirs |

---

## 3. Phases

### Phase 0 — Emergency hotfix (hours, needs owner)

**Goal:** the live key is worthless and the privileged page is not reachable.

| # | Task | Owner |
|---|---|---|
| 0.1 | Revoke the key in Google AI Studio; create a new one; store it **only** as an Edge Function secret (`supabase secrets set GEMINI_API_KEY=…`) and local shell env | **You** (I cannot access your console) |
| 0.2 | Rotate the Supabase `service_role` JWT if it was ever pasted into `admin.html` | **You** |
| 0.3 | `git mv helm/web/admin.html tools/admin/admin.html`; add `docs/admin-tool.md` explaining local-only usage | Me |
| 0.4 | Confirm no other static file ships secrets: `git grep -n -I -E "AIza|eyJ" -- helm/web` | Me |
| 0.5 | Redeploy web; verify `/admin.html` → 404 and `/assets/.env` → 404 | Me + you (Vercel access) |

**Exit criteria**
```bash
git grep -n "AIza" -- .            # no matches
curl -sI https://<prod-domain>/admin.html | head -1   # 404
curl -sI https://<prod-domain>/assets/.env | head -1   # 404
```
> Until 0.1 is done, treat every "fix" as cosmetic: the key is already public and in history.

---

### Phase 1 — Secrets & configuration hardening (0.5 day)

**Goal:** no secret is bundled, no secret is in source, one place defines config.

1. `AppConfig` (`helm/lib/config/app_config.dart`):
   ```dart
   class AppConfig {
     static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
     static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
     static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
   }
   ```
2. `main.dart`: drop `dotenv.load` and hardcoded credentials; fail fast with an actionable message if `!isConfigured`.
3. `pubspec.yaml`: remove the `.env` asset; remove `flutter_dotenv` once `ai_service.dart:19` stops using it (Phase 2 swaps the call site; do both in the same PR to avoid a broken intermediate).
4. `git rm --cached helm/.env`; add `helm/.env.example`; keep `.env` in `.gitignore`.
5. Local dev: `flutter run --dart-define-from-file=.env.dev.json` (documented in README).
6. CI: `flutter build web --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }} --pwa-strategy=none`.
7. `web/feedback.html` / `web/admin.html`: replace hardcoded URL/key with placeholders substituted at deploy time (or, better, pass them as query-free config injected by a tiny build step). Never commit a `service_role` key anywhere.
8. GitHub: enable **secret scanning + push protection**; add a `gitleaks` job in CI.

**Exit criteria**
- `git ls-files helm/.env` → empty
- `ls build/web/assets/.env` → not found; `grep -r "AIza" build/web` → nothing
- App boots with `--dart-define`s; `flutter analyze && flutter test` green

**Rollback:** revert the commit; the key has already been rotated, so there is no security regression from reverting code.

---

### Phase 2 — AI proxy: remove the key from the client (1 day)

**Goal:** no client binary ever contains a Gemini credential.

```
supabase/functions/ai/index.ts   (new, deployed with --no-verify-jwt off)
  ├─ verifies the caller's Supabase JWT
  ├─ enforces per-user rate limit (table or KV)
  ├─ calls Generative Language API with model = gemini-3.5-flash-lite   ← AGENTS.md mandate, unchanged
  └─ returns { title, description, due_date, priority, community_id, assignee_id,
              clarification_needed, clarification_message }
```

Client change — `AiService` keeps its public API so `command_bar`, `ai_voice_overlay` and `task_detail_page` are untouched:

```dart
Future<Map<String, dynamic>?> _callCloud({
  String? userInput,
  Uint8List? audioBytes,
  required Map<String, dynamic> context,
}) async {
  final res = await Supabase.instance.client.functions.invoke('ai', body: {
    'text': userInput,
    'audio': audioBytes == null ? null : base64Encode(audioBytes),
    'context': context,
  });
  if (res.status != 200) throw Exception(res.data?['error'] ?? 'AI unavailable');
  return Map<String, dynamic>.from(res.data['result']);
}
```

Notes
- Audio must be base64 (or multipart) — enforce a hard size cap (e.g. 4 MB) and 30 s duration client-side.
- Keep `responseMimeType: application/json` server-side; the JSON contract stays byte-identical.
- Rate limit: 30 requests/day/free user, then 429 with a friendly message — that is also the cost control the current architecture lacks.
- Local dev: `supabase functions serve ai` + `--dart-define=AI_PROXY_URL=http://localhost:54321`.

**Exit criteria**
- `grep -r "generative" helm/lib` → only the Edge Function path
- Voice + text creation still work end-to-end on device
- 429 path renders a snackbar, not a crash

**Risk:** cold-start latency on voice (~300–900 ms). Mitigation: keep the client-side heuristic fast path (T3) for ≤8-word commands.

---

### Phase 3 — Database as the source of truth (2–3 days)

**Goal:** AGENTS.md §5 is enforced by Postgres, not by `AbsorbPointer`.

1. **Baseline capture.** `supabase db pull` (or `pg_dump --schema=public`) → commit `supabase/migrations/0001_baseline.sql`. *This must happen first; the live schema is currently undocumented.*
2. **Schema you must reconcile** (columns observed in code):
   - `tasks(id, title, description, community_id, user_id, category_ids text[], category_id, assignees text[], subtasks jsonb, priority, status, is_completed, "order", due_at, created_at, updated_at)`
   - `categories(id, name, user_id)`, `communities(id, name, creator_id, created_at)`, `community_members(community_id, user_id, role, created_at)`, `task_comments(id, task_id, user_id, user_name, comment_text, created_at)`, `notifications(id, user_id, type, title, body, related_id, is_read, created_at)`, `feedback(id, name, email, message, created_at)`
   - RPCs referenced by the app: `get_user_communities()`, `get_community_member_names(p_community_id uuid)`, `delete_user_account()`
3. **`internal` schema** for SECURITY DEFINER helpers (`role_weight`, `is_member`, `can_edit_task`) so PostgREST does not expose them.
4. **RLS** (rewrite of the naive versions):
   ```sql
   -- tasks: personal owner, or member of the community
   create policy tasks_select on public.tasks for select using (
     user_id = auth.uid()
     or (community_id is not null and internal.is_member(community_id))
   );
   -- tasks: creator, or higher-or-equal role in the community
   create policy tasks_write on public.tasks for update using (
     user_id = auth.uid()
     or internal.role_weight(community_id, auth.uid())
        >= internal.role_weight(community_id, user_id)
   ) with check (
     user_id = auth.uid()
     or internal.role_weight(community_id, auth.uid())
        >= internal.role_weight(community_id, user_id)
   );
   ```
5. **Triggers that mirror AGENTS.md exactly**
   - Comment quota: reject the 3rd comment where `created_at >= tasks.updated_at`, per `(task_id, user_id)`.
   - RBAC: reject `update`/`delete` when actor weight < creator weight; owner weight 3 cannot be demoted/removed.
   - Assignment notification: insert into `notifications` on `assignees` change (currently claimed in CHANGELOG 0.3.2 but not in the repo).
   - `updated_at = now()` on task mutation (the comment-reset trigger depends on it).
6. **`feedback`**: revoke `anon` insert; move submission behind the authenticated app or add a rate-limited Edge Function with a captcha.
7. **Storage**: `avatars` bucket policies — public read, owner-only write to `<uid>/…`.
8. **Client adjustments:** map new Postgres exceptions (`comment_limit_reached`, `insufficient_role`) to friendly messages in `task_detail_page.dart`; keep the client-side UX lock as a hint only.
9. **Tests:** `supabase test db` (pgTAP) covering: member cannot edit owner task; 3rd comment rejected; comment quota resets after task update; non-member cannot select community tasks.

**Exit criteria**
- `supabase db lint` clean; `supabase test db` green
- Manual: two accounts, one Owner + one Member; Member's edit attempt fails **at the API** (verify with `curl`), not just in the UI
- Existing data still readable (run against a branch database first)

**Risk (highest in the plan):** a wrong policy locks users out of their data. Mitigation: apply to a Supabase **branch/preview database**, run the app against it, then promote; keep the previous policy set in `0001_baseline.sql` for instant rollback.

---

### Phase 4 — Data-integrity fixes (2 days)

Prerequisite for testability: extract a `TaskRepository` interface from `TaskProvider` (T6/D5) so sync logic is unit-testable with a fake.

| Order | ID | Change |
|---|---|---|
| 1 | D1 | `HiveDatabase.init`: `await categoryBox.put(cat.id!, cat)`; add a one-time migration that re-keys existing integer-keyed seed rows without duplicating `categoryIds` on tasks |
| 2 | D5/D9 | Single `_mutate(id, table, payload)` used by add/update/toggle/reorder/delete/category ops; `window` guard `try/finally` in `processSyncQueue`; key `table:id`; exponential backoff |
| 3 | D2 | Merge by `updated_at` + per-field; skip records with a pending queue entry so local edits win |
| 4 | D3 | Snapshot diff → delete Hive rows absent from the server snapshot for the same scope |
| 5 | D4 | Filter the personal mirror stream to `community_id is null`; add a separate community mirror only if offline community reads are wanted (explicit product decision) |
| 6 | D6/D7 | Preserve `is_completed` on subtask edit; nullable due date with an explicit "Clear" action |
| 7 | D8 | Enqueue remote delete even when the local row is missing |
| 8 | D10 | Pending-changes indicator in the app bar; retry budget surfacing |

**Tests (new, `helm/test/`):** sync merge matrix (local-newer / remote-newer / equal / pending-queue), queue coalescing (create+delete, create+update, update+update), delete tombstone, category seed re-keying.

**Exit criteria**
- `flutter test` green with ≥12 new sync/category tests
- Airplane-mode scenario: create → edit → delete → reconnect produces exactly the intended server state
- Two-device scenario: edit on A, edit on B, both converge on the newer `updated_at`

---

### Phase 5 — UX correctness (2 days)

| Order | ID | Change |
|---|---|---|
| 1 | U1 | Use `widget.title` in `AppShell` (single-line fix; verify Settings/Calendar/Categories/Manage) |
| 2 | U2 | `MyHomePage` keeps `_selectedTaskId`; resolves the task from the provider every build; clears on tab/community change |
| 3 | U3 | Hoist streams: `TaskProvider.communityTasksStream(id)` memoized in a `Map<String, Stream>`; comments stream cached per task in `initState`; bell/feed streams in `initState` |
| 4 | U4/U5 | Post-auth permission prompt with rationale; `flutter_timezone` → `tz.setLocalLocation(tz.getLocation(name))` before scheduling |
| 5 | U10 | Stop dual capture: record for audio, derive the live preview from `speech_to_text` **or** drop STT preview and show a waveform |
| 6 | U9 | Web: keep the legal gate visible until accepted (no `SystemNavigator.pop`) |
| 7 | U8/U7 | Fix S/M/L mapping; persist or remove the daily goal dialog |
| 8 | U11/U12/U13/U15/U17/U18/U19/U20 | Per-item fixes as listed in §2.3 |

**Exit criteria**
- Manual regression sheet (below) all pass on Android + web + Windows
- Widget tests for: header title per route, detail panel refresh after subtask toggle, comment limit banner state

---

### Phase 6 — Tooling, CI and docs (1 day)

1. Remove `deprecated_member_use: ignore` from `analysis_options.yaml`; codemod the 83 `withOpacity` → `withValues(alpha:)` and 3 `DropdownButtonFormField(value:)` → `initialValue:` in one mechanical PR.
2. New workflow `.github/workflows/quality.yml`:
   ```yaml
   on: [push, pull_request]
   jobs:
     quality:
       runs-on: ubuntu-latest
       defaults: { run: { working-directory: helm } }
       steps:
         - uses: actions/checkout@v4
         - uses: subosito/flutter-action@v2
           with: { channel: stable, cache: true }
         - run: flutter pub get
         - run: flutter analyze --fatal-infos
         - run: flutter test --coverage
   ```
3. `deploy_web.yml`: `checkout@v4`, add `needs: quality`, replace outdated flag set with `--pwa-strategy=none`, add branch protection requiring the check.
4. `gitleaks` job (Phase 1 step 8).
5. Docs: rewrite `AGENTS.md` §3–§4 against reality (no `--web-renderer`; real file tree); add `docs/architecture.md` (data flow, boxes, sync contract), `docs/database.md` (tables, policies, RPCs), `docs/admin-tool.md`; fix README version drift; add LICENSE.
6. T3 decision: rename `CactusNeedleEngine` → `LocalHeuristicParser` and remove the "121M params" log/README claim, **or** wire a real model and keep the name. Do not ship the claim without the model.

---

### Phase 7 — Follow-ups (backlog, not blocking)

- Real on-device ASR (the stub `transcribeAudioLocally` is dead code today).
- Cross-community search + server-side search endpoint.
- Notification delivery diagnostics in Settings (U16).
- Observability: Sentry/Crashlytics for the remaining `debugPrint`-only error paths (76 sites).
- Offline read support for community tasks (depends on D4 decision).
- Replace `google_generative_ai: 0.4.6` with the current Google GenAI Dart SDK once the proxy exists (client no longer depends on it directly — lowest priority).

---

## 4. Sequencing, parallelism and estimates

```
Day 0      Phase 0  (owner: rotate keys)  ─┐
Day 0–0.5  Phase 0  (code hotfix)          ├─ blocking
Day 0.5–1  Phase 1  secrets/config        ─┘
Day 1–2    Phase 2  AI proxy
Day 2–5    Phase 3  DB/RLS  ──┬── can run in parallel with Phase 4
Day 3–5    Phase 4  data integrity ──┘
Day 5–7    Phase 5  UX correctness
Day 7–8    Phase 6  CI/docs
```

| Phase | Effort | Blocking? | Owner dependency |
|---|---|---|---|
| 0 | 2–4 h | **Yes** | Key rotation, Vercel/Supabase access |
| 1 | 0.5 d | Yes | GitHub settings |
| 2 | 1 d | No (but key stays exposed until done) | Supabase functions access |
| 3 | 2–3 d | Yes for S4 | Supabase project + branch DB |
| 4 | 2 d | No | — |
| 5 | 2 d | No | — |
| 6 | 1 d | No | Repo admin (branch protection) |

Total ≈ **10–14 engineer-days**; the security-critical subset (0–3) is ≈ **5–6 days** plus console time.

---

## 5. Verification strategy

**Per-PR gate (must pass):**
```bash
cd helm && flutter analyze --fatal-infos && flutter test
git grep -nE "AIza|service_role\s*=|sb_secret" -- . || true
```

**Manual regression sheet** (run on Android + web + Windows at the end of each phase):

| # | Check |
|---|---|
| 1 | Create task (personal/community/local-only) → appears, persists after restart |
| 2 | Edit title/priority/due date → syncs; comment slots reset |
| 3 | Clear due date → no notification scheduled |
| 4 | Toggle subtask on desktop panel → updates immediately |
| 5 | Delete → undo restores both local + remote |
| 6 | Airplane mode: create/edit/delete/reorder → reconnect → server state correct |
| 7 | Two devices: concurrent edit converges on newest `updated_at` |
| 8 | Member cannot edit Owner task (UI locked *and* API rejects) |
| 9 | 3rd comment blocked; 3rd comment after task update allowed |
| 10 | Voice + text AI commands create correctly, with rate-limit message at cap |
| 11 | Due reminder fires at the device-local hour (not UTC) |
| 12 | `/assets/.env` and `/admin.html` → 404 on production |
| 13 | Settings/Calendar/Categories headers show correct titles |
| 14 | EULA decline on web blocks the app |

**Security verification (post-Phase 2/3):**
```bash
# anon key must not read other users' feedback
curl -s "$SUPABASE_URL/rest/v1/feedback?select=*" -H "apikey: $ANON" -H "Authorization: Bearer $ANON"
# member token must not update an owner-owned task
curl -s -X PATCH "$SUPABASE_URL/rest/v1/tasks?id=eq.$TASK_ID" -H "apikey: $ANON" \
  -H "Authorization: Bearer $MEMBER_JWT" -d '{"priority":"high"}'
```

---

## 6. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| RLS migration locks out users | Medium | High | Apply to branch DB, run app + `curl` matrix, keep baseline for rollback, deploy outside peak hours |
| History purge breaks clones/PRs | High (if attempted) | Medium | Skip by default; rotate instead (D3) |
| Edge Function cold start hurts voice UX | Medium | Medium | Keep the local heuristic fast path; optimistic overlay already exists |
| Offline-first behaviour regresses during Phase 4 | Medium | High | Snapshot the merge matrix as tests *before* refactoring `TaskProvider` |
| Supabase dashboards drift from migrations (someone edits in the UI) | High | Medium | CI `supabase db diff` check; documented "no dashboard edits" rule |
| `service_role` already compromised via admin.html | Unknown | **Critical** | Rotate (0.2), audit `feedback`/`tasks` for unexpected writes, review auth logs |

---

## 7. Deliverables checklist

- [x] Rotated Gemini key (owner) + revoked old key
- [x] `tools/admin/admin.html` (no longer deployed) with escaped rendering
- [x] `helm/.env` untracked; `.env.example`; `AppConfig`
- [x] `supabase/functions/ai/index.ts` + rate limiting (code complete; deploy pending)
- [ ] `supabase/migrations/0001_baseline.sql` … `0005_rbac_triggers.sql` (`20261028120000_ai_rate_limit.sql` landed)
      — **authored but never applied**: `20261029110000_internal_helpers.sql`,
      `20261029110100_rls_policies.sql`, `20261029110200_task_triggers.sql`,
      `20261029110300_storage_avatars.sql`. Baseline capture is still missing
      (needs `supabase db pull` against the live project).
- [ ] pgTAP tests for comment quota + RBAC — `supabase/tests/rls_test.sql`
      authored, never executed.
- [x] Sync integrity tests (23) instead of a `TaskRepository` extraction; the
      queue engine was rewritten in place to avoid destabilising it.
- [x] Phase 5 UX fixes (U2–U20); 9 pure-rule tests, no widget tests.
- [ ] `quality.yml` gate — done; **branch protection still needs repo admin**.
- [x] `gitleaks` in CI
- [x] Rewritten `AGENTS.md`, new `docs/architecture.md`, `docs/database.md`, `docs/admin-tool.md`
- [x] LICENSE (MIT)

---

## Appendix A — Secret rotation runbook (owner)

1. **Google AI Studio** → API keys → *revoke* `AIza…` (the one in `helm/.env:1`) → create a new key.
2. **Supabase** → Project Settings → API → rotate `service_role` if it was ever pasted into `admin.html`. The app does not use it.
3. Store the new Gemini key **only** in: `supabase secrets set GEMINI_API_KEY=…` (Phase 2) and your local shell. Never in the repo, never in `web/`, never as a Flutter asset.
4. If you later decide on a history purge (D3):
   ```bash
   git filter-repo --path helm/.env --invert-paths
   git push --force-with-lease origin highest
   ```
   Coordinate first — every clone must re-clone, and open PRs must be rebased.
5. Enable GitHub → Settings → Code security → *Secret scanning* + *Push protection*.

## Appendix B — Files touched by phase (preview)

| Phase | Files |
|---|---|
| 0 | `helm/web/admin.html` → `tools/admin/admin.html` |
| 1 | `helm/pubspec.yaml`, `helm/lib/main.dart`, `helm/lib/services/ai_service.dart`, `.github/workflows/deploy_web.yml`, `helm/.env*` |
| 2 | `helm/lib/services/ai_service.dart`, `supabase/functions/ai/index.ts`, `helm/lib/config/app_config.dart` |
| 3 | `supabase/migrations/*.sql`, `supabase/tests/*.sql`, `helm/lib/task_detail_page.dart`, `helm/lib/providers/task_provider.dart` |
| 4 | `helm/lib/providers/task_provider.dart`, `helm/lib/services/hive_database.dart`, `helm/lib/services/sync_service.dart`, `helm/lib/add_event_page.dart`, `helm/test/*` |
| 5 | `helm/lib/app_shell.dart`, `helm/lib/main.dart`, `helm/lib/notification_service.dart`, `helm/lib/widgets/*`, `helm/lib/task_detail_page.dart` |
| 6 | `helm/analysis_options.yaml`, `.github/workflows/*`, `AGENTS.md`, `README.md`, `docs/*`, `LICENSE` |
