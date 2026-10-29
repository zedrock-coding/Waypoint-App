# Helm — Architecture

| | |
|---|---|
| **App** | Waypoint `0.4.0+11` (`helm/`) |
| **Stack** | Flutter (Material 3) · Supabase · Hive · Provider |
| **Targets** | Android, Windows, Web |
| **Last updated** | 2026-10-30 |

This document describes how the pieces fit together. For rules that agents and
contributors must follow, see `AGENTS.md`; for the schema see
`docs/database.md`; for the security work in progress see
`docs/security-remediation-plan.md`.

---

## 1. Runtime shape

```text
┌───────────────────────────────────────────────────────────────┐
│ Flutter client (Android / Windows / Web)                      │
│                                                               │
│  main.dart ──► Supabase.initialize()   (URL + publishable key)│
│            └─► HiveDatabase.init()     (local boxes)          │
│            └─► NotificationService.init()                     │
│                                                               │
│  TaskProvider (ChangeNotifier)                                │
│    ├── personalTasks  ◄── Hive `tasks` box                    │
│    └── communityTasks ◄── Supabase realtime stream            │
│                                                               │
│  SyncService (singleton)                                      │
│    queue in Hive `sync_queue`  ──► Supabase writes            │
└───────────────────────────────────────────────────────────────┘
        │                                   ▲
        │ HTTPS (publishable key)           │ realtime
        ▼                                   │
┌───────────────────────────────────────────────────────────────┐
│ Supabase                                                      │
│  Postgres + RLS · Auth · Realtime · Storage                   │
│  Edge Function `ai` ──► Gemini (secret lives here only)       │
└───────────────────────────────────────────────────────────────┘
```

There is no server of our own. The Vercel deployment is static hosting for the
Flutter web build plus `web/config.js`.

---

## 2. Layering

### 2.1 Entry point (`lib/main.dart`)

Initialisation order matters: Supabase first (auth session restored), then Hive
(local state), then notifications (may need the session for realtime). Routes,
theme, and the provider tree are wired here. `MyHomePage` owns the desktop
detail panel and the reorderable list.

### 2.2 State (`lib/providers/`, `lib/services/navigation_provider.dart`)

`TaskProvider` is the single source of UI truth for tasks:

- `personalTasks` is rebuilt from the Hive box (`_refreshPersonalTasks`), driven
  by `box.watch()`. It is fast and always available offline.
- `communityTasksStream(id)` is a **memoized** Supabase realtime stream per
  community. Memoization matters: creating the stream inside `build` re-opened
  the socket subscription on every frame.
- All remote mutations go through one private helper, `_mutate()`, which either
  writes immediately or enqueues and returns whether it succeeded. Duplicating
  the "if online try, else queue" dance per call site was the source of several
  data-loss bugs.
- `deleteTask(id, {taskBackup})` stores both Hive and in-memory `UnifiedTask` backups,
  immediately cleans `_personalTasks` for instant UI feedback, and cancels pending local
  notifications.
- `undoDelete()` restores personal tasks into Hive and community tasks through `_mutate(create)`,
  re-syncs the complete task schema (`due_at`, `subtasks`, `assignees`, `category_ids`),
  reschedules due date reminders, purges any unflushed delete in `SyncService`, and
  forces `_refreshPersonalTasks()` so the restored task displays immediately.

`NavigationProvider` holds the selected tab and community. Changing either
invalidates the desktop detail panel selection.

### 2.3 Services (`lib/services/`)

| File | Responsibility |
|---|---|
| `ai_service.dart` | Calls the `ai` Edge Function. Short commands are parsed locally first; cloud is used for de-jumbling. Errors map to `AiException` with a rate-limit flag. |
| `needle_engine.dart` | `LocalHeuristicParser` (implements `NeedleEngine`): deterministic keyword/rule extraction. Offline fallback, no model weights. |
| `supabase_service.dart` | RPC wrappers (`get_user_communities`, `get_community_member_names`, `delete_user_account`), auth, storage, plus a 2-minute roster cache. |
| `sync_service.dart` | Offline queue: coalescing, connectivity listener, retry/backoff, `pendingChanges` notifier. |
| `task_merge.dart` | Pure functions: last-write-wins decision and remote-delete detection. Unit-tested. |
| `task_rules.dart` | Pure functions: 2-comment quota and id-based task lookup. Unit-tested. |
| `hive_database.dart` | Adapter registration, box opening, category-key migration. |
| `invite_service.dart` | `helm://invite?…` deep links. |
| `audio_recording_service.dart` | Microphone capture for the AI voice path. |

### 2.4 UI (`lib/*_page.dart`, `lib/widgets/`)

`AppSnackBar` (`lib/widgets/app_snackbar.dart`) provides a small, centered, pill-shaped
floating toast (`width: 310`, `borderRadius: 100`, `#222528` background with `#88C0A4` mint action)
configured with a guaranteed 5-second persistence for dismissal and undo actions.

Screens are ordinary `StatefulWidget`s; no router package. `AppShell` provides
the responsive sidebar/drawer and the header (search, bell, pending-sync badge,
avatar). `community_manage_page.dart` deliberately uses a plain `Scaffold` —
nesting `AppShell` duplicated navigation state.

---

## 3. Data flow

### 3.1 Read (personal)

```text
Hive `tasks` box ──watch()──► TaskProvider._refreshPersonalTasks()
                                   │
                                   ▼
                         UnifiedTask list ──► widgets
```

`UnifiedTask` merges the Hive row with the Supabase-column shape so the UI has
one type regardless of origin.

### 3.2 Read (community)

```text
Supabase `.stream(primaryKey: ['id'])` (filtered by community_id)
        │
        ▼
map rows ──► UnifiedTask ──► sorted by `order` ──► StreamBuilder
```

### 3.3 Write

```text
UI action ──► TaskProvider method
                 ├── Hive write (instant UI, survives restart)
                 └── _mutate()
                       ├── online  ──► Supabase write
                       └── offline / failed ──► SyncService.addToQueue()
                                                     │
                        connectivity restored ───────┘
                                │
                                ▼
                   processSyncQueue(): create=upsert,
                   update=PATCH by id, delete=delete
                   (retry ×5 with backoff, then leave queued)
```

### 3.4 Conflict policy

Last write wins on `updated_at`, with one absolute rule: **a record with an
unflushed queue entry never accepts a remote value.** Without that rule, a pull
landing between the local edit and the flush silently reverted the edit.
`task_merge.dart` holds the decision function; `task_merge_test.dart` holds the
truth table.

---

## 4. AI path

1. `AiService.parseHybridCommand` short-circuits to `LocalHeuristicParser` for
   inputs of ≤ 8 words. No network, works offline.
2. Otherwise it calls `parseTaskCommand`, which invokes the `ai` Edge Function
   with the prompt, optional audio, and the user's community/member context.
3. The Edge Function attaches the fixed server-side system instruction
   (`gemini-3.5-flash-lite`), enforces a per-user rate limit, and returns JSON.
4. The response is passed back through the local parser (`needle_engine.dart`)
   and `AiService.parseAiDueDate` so exact user-specified times (e.g. "5 pm", "17:00")
   are extracted and blended into ISO8601 timestamps instead of defaulting to midday.

The client never sees a Gemini key. The Edge Function reads `GEMINI_API_KEY`
from its own environment.

---

## 5. Notifications

`NotificationService` schedules local notifications only — nothing is pushed
from the server.

- Timezone: `initializeTimeZones()` plus `FlutterTimezone.getLocalTimezone()`
  → `tz.setLocalLocation()`. Without the second step `tz.local` is UTC and
  reminders fire at the wrong hour.
- Ids: FNV-1a of the task id (folded into a range that leaves room for three
  reminders per task), because `String.hashCode` is not stable across runs.
- Failures are surfaced through `lastError` and shown as a banner in Settings.

---

## 6. Build & deploy

| Step | Command |
|---|---|
| Analyze | `flutter analyze --fatal-infos` |
| Test | `flutter test` |
| Web build | `flutter build web --release --pwa-strategy=none` |
| Deploy | GitHub Actions → Vercel (`deploy_web.yml`), or `vercel deploy` from `build/web` |

`.github/workflows/quality.yml` gates every push: analyze, test, and a gitleaks
scan of the changed commits. `deploy_web.yml` depends on that gate.

`--pwa-strategy=none` is deprecated but intentional: the service worker was
serving stale bundles after deploys. `--web-renderer` no longer exists.

---

## 7. Known gaps

- **RLS behaviour is applied but not proven.** All five migrations are applied
  to the remote project and `supabase db lint --linked` is clean, and the
  pre-migration schema is captured in `docs/baseline_schema.sql`. The pgTAP
  suite (`supabase/tests/rls_test.sql`) has still never been executed — the
  remote pooler restricts the `auth` schema — so the comment quota and role
  hierarchy are reasoned about, not demonstrated. The API-level check (a Member
  edit must fail with `curl`, not just be hidden by `AbsorbPointer`) is also
  outstanding.
- **No on-device ASR.** `transcribeAudioLocally` returns `null` by design; the
  voice path relies on the cloud function or speech-to-text.
- **Feedback page insert path** (`helm/web/feedback.html`) was verified for
  reads under RLS but not for inserts, and `anon` still has `insert`.

---

## 8. Authentication & Deep Linking

- **First-Time Sign Up**: Email OTP passwordless onboarding via Supabase Auth (`signInWithOtp(shouldCreateUser: true)`), 6-digit verification code with 60-second cooldown timer, followed by display name and password creation (`updateUser`).
- **Returning User Sign In**: Password sign in with visibility toggle and self-service password recovery flow (`resetPasswordForEmail`).
- **Universal Deep Linking**:
  - Custom schemes (`waypoint://` and legacy `helm://`) and web links (`https://helm-omega-blue.vercel.app`).
  - Auth redirects (`waypoint://login-callback`).
  - Community invites (`waypoint://invite?communityId=...` or `?communityId=...`): automatically joins community if authenticated or stores pending invite to join post-auth.
- **Build Artifact Auto-Naming**:
  - Android APK: `waypoint-v<version>.apk` via Gradle Kotlin DSL output filename override.
  - Windows: CMake post-build copy creating `waypoint-v<version>.exe`.
