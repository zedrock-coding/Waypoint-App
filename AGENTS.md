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
```
helm/lib/
├── main.dart                   # Application entry point, Provider initialization, routing setup
├── app_shell.dart              # Main navigation shell (Sidebar/Drawer, Header, Navigation)
├── models/                     # Data models
│   ├── hive_models.dart        # Hive database entities & TypeAdapters
│   ├── sync_model.dart         # Offline queue SyncAction entity & SyncActionType
│   └── unified_task.dart       # Unified task model merging Hive + Supabase data
├── services/                   # Service layer & APIs
│   ├── ai_service.dart         # Gemini AI integration using gemini-3.5-flash-lite
│   ├── supabase_service.dart   # Supabase RPCs, Auth, and Storage calls
│   ├── sync_service.dart       # Offline queue execution & network listener
│   └── navigation_provider.dart# App-wide routing & active tab state
├── providers/
│   └── task_provider.dart      # Task state management, local/remote sync orchestration
└── widgets/                    # Reusable UI components
    ├── command_bar.dart        # AI Voice & Text input bar
    ├── user_avatar.dart        # Avatar rendering with initials fallback
    └── task_item_card.dart     # Task card with 4px left priority accent line
```

## 4. CLI Commands
- **Run Web (Cache-Busting on Port 3000)**:
  ```bash
  flutter run -d web-server --web-port 3000 --web-renderer canvaskit
  ```
- **Build Web (Release with No PWA Cache)**:
  ```bash
  flutter build web --release --pwa-strategy=none --web-renderer canvaskit
  ```
- **Generate Hive Adapters**:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
- **Deploy Prebuilt Web Output to Vercel (CLI)**:
  ```bash
  cd build/web && vercel deploy . --prod --yes
  ```

## 5. Business Logic & System Conventions

### Offline Data Synchronization
- **Strategy**: Local-First with Last-Write-Wins conflict resolution.
- **Queueing**: Mutations while offline are written immediately to Hive (`tasks` box) for instant UI updates, and an action is enqueued into the `sync_queue` box.
- **Flushing**: When `connectivity_plus` detects connection restoration, `SyncService.processSyncQueue()` processes actions in FIFO order using Supabase `.upsert()`.

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
