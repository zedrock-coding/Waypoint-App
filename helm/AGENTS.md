# Helm Project Architecture & Agent Guidelines

## 1. Tech Stack
- **UI Framework**: Flutter (Material 3)
- **Backend & Database**: Supabase (PostgreSQL, Auth, Row-Level Security, Storage, Realtime)
- **Local Database**: Hive (NoSQL, local-first offline storage)
- **State Management**: Provider (`ChangeNotifier`)
- **Deployment**: Vercel (GitHub Actions CI/CD workflow & Vercel CLI)

## 2. AI Configuration
- **Model Mandate**: All generative AI features MUST strictly use `gemini-3.5-flash-lite`.
- **STRICT RULE**: Do NOT upgrade, alter, or replace this model string under any circumstances.

## 3. Architecture & Directory Structure

```text
helm/
├── lib/
│   ├── main.dart                  # Entry point: Supabase/Hive init, routing, home shell wiring
│   ├── app_shell.dart             # Navigation shell: sidebar/drawer, header, pending-sync badge
│   ├── config/app_config.dart     # Public runtime config (Supabase URL + publishable key, AI function name)
│   ├── models/
│   │   ├── hive_models.dart       # Hive entities + generated TypeAdapters
│   │   ├── sync_model.dart        # SyncAction / SyncActionType (offline queue rows)
│   │   └── unified_task.dart      # Task view model merging Hive + Supabase rows
│   ├── providers/
│   │   └── task_provider.dart     # Task state, local/remote orchestration, single `_mutate()` write path
│   ├── services/
│   │   ├── ai_service.dart        # Calls the `ai` Edge Function; falls back to the local parser
│   │   ├── needle_engine.dart     # `LocalHeuristicParser`: offline keyword/rule extraction
│   │   ├── supabase_service.dart  # RPC, auth, storage helpers + roster cache
│   │   ├── sync_service.dart      # Offline queue engine, connectivity listener, retry/backoff
│   │   ├── task_merge.dart        # Pure last-write-wins + remote-delete rules
│   │   ├── task_rules.dart        # Pure comment-quota and task-lookup rules
│   │   ├── hive_database.dart     # Box/adapter registration, category key migration
│   │   ├── invite_service.dart    # Deep-link invite handling
│   │   ├── audio_recording_service.dart
│   │   └── navigation_provider.dart
│   ├── theme/app_theme.dart       # Material 3 colour scheme and typography
│   ├── theme_provider.dart
│   ├── notification_service.dart  # Local notifications: scheduling, ids, diagnostics
│   ├── widgets/                   # Reusable UI (command bar, task card, bell, feed, search, …)
│   └── *_page.dart                # Screens: auth, calendar, categories, settings, task detail, …
├── web/
│   ├── config.js                  # The only public runtime config; no secrets
│   └── index.html
├── test/                          # Unit/widget tests run by CI
└── pubspec.yaml
supabase/
├── functions/ai/index.ts          # Sole holder of the Gemini credential
└── migrations/                    # SQL migrations (see docs/database.md)
tools/admin/                       # Local-only ops console; never copied into build/web
docs/                              # Architecture, database and remediation docs
```

**Rule:** the Flutter client must never contain a private key. The Gemini key
exists only as an Edge Function secret (`supabase secrets set GEMINI_API_KEY=…`),
and `web/config.js` may only hold values that are safe to publish.

## 4. CLI Commands

All commands run from `helm/` unless stated otherwise.

- **Run Web (hot reload, port 3000)**:
  ```bash
  flutter run -d chrome --web-port 3000
  ```
- **Build Web (release, no service worker)**:
  ```bash
  flutter build web --release --pwa-strategy=none
  ```
  `--pwa-strategy` is deprecated but still honoured; without it the generated
  service worker serves stale bundles. `--web-renderer` no longer exists in
  current Flutter and must not be added back.
- **Analyze / test (CI gate)**:
  ```bash
  flutter analyze --fatal-infos
  flutter test
  ```
- **Generate Hive Adapters** (only after editing `@HiveType`/`@HiveField`):
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
- **Deploy prebuilt web output to Vercel**:
  ```bash
  cd build/web && vercel deploy . --prod --yes
  ```
- **Deploy the AI Edge Function** (repo root):
  ```bash
  supabase functions deploy ai
  supabase secrets set GEMINI_API_KEY=your_key_here
  ```

## 5. Business Logic & System Conventions

### Offline Data Synchronization
- **Strategy**: Local-First with last-write-wins conflict resolution on `updated_at`.
- **Queueing**: Mutations while offline are written immediately to Hive (`tasks` box) for instant UI updates, and one action is enqueued into the `sync_queue` box under the key `table:id` (so the same record never accumulates duplicates).
- **Coalescing**: `create` + `update` merges into a single `create`; repeated `update`s merge payloads; `create` + `delete` cancels out; a queued `delete` swallows later `update`s.
- **Flushing**: When `connectivity_plus` detects connection restoration, `SyncService.processSyncQueue()` drains the queue. `create` uses `.upsert()`, `update` uses a PATCH (filtered by id) so a partial payload can never insert a truncated row, `delete` uses `.delete()`. Failures retry with exponential backoff up to 5 attempts per record, then stay queued for the next cycle.
- **Remote deletes**: the realtime pull diffs the server snapshot against the Hive mirror; rows with an unflushed write, or rows created offline, are never removed locally.
- **Indicator**: `SyncService.pendingChanges` drives the header badge showing unflushed writes.

### Design System & Styling
- **Primary Background (Dark Slate)**: `#1E2124` (surface `#2D2F31`)
- **Primary Accent (Mint Green)**: `#88C0A4`
- **Priority Accents**:
  - High: `RedAccent` (`#FF5252`) + `Icons.keyboard_double_arrow_up_rounded`
  - Medium: `Amber` (`#FFBF00`) + `Icons.remove_rounded`
  - Low: `BlueGrey` (`#78909C`) + `Icons.keyboard_arrow_down_rounded`

### 2-Comment Limit Rule
- **Enforcement**: Users can submit a maximum of **2 comments** per task.
- **Calculation**: Count comments where `created_at >= task.updated_at`.
- **Reset Trigger**: Any update to the task's properties (`title`, `description`, `status`, `priority`, `subtasks`) updates `updated_at`, resetting the available comment slots for all users back to 0.

### Weighted RBAC (Role-Based Access Control)
- **Hierarchy Weights**:
  - `Owner` = 3 (Full control, cannot be demoted or removed)
  - `Admin` = 2 (Can manage members and tasks, cannot demote/remove Owners or other Admins)
  - `Member` = 1 (Can view/comment; cannot edit tasks created by higher roles)
- **UI Locking**: In `TaskDetailPage`, if current user weight < creator's role weight, display the "Read-Only" banner and wrap the form in an `AbsorbPointer`.
