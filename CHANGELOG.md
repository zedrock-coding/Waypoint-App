# Changelog - Helm Workspace 🚀

All notable changes to the **Helm** project will be documented in this file.

---

## [0.3.5] - 2026-10-29

### 🚀 Added
- **Compact Pill Undo Toast (`AppSnackBar`)**:
  - Rebuilt toast into a centered, floating pill (`width: 310`, `borderRadius: 100`, `#222528` slate background, `#3A3D40` border, `#88C0A4` mint accent).
  - Maintained guaranteed 5-second display before dismissal across desktop and mobile.
  - Added dedicated widget test suite (`helm/test/app_snackbar_test.dart`).

### 🐛 Fixed
- **Task Deletion & Undo Restoration Lifecycle**:
  - Fixed undo failure where community tasks streamed from Supabase lacked local Hive backup.
  - Added `taskBackup` parameter in `TaskProvider.deleteTask` across `main.dart`, `calendar_page.dart`, and `widgets/task_search_delegate.dart`.
  - Re-synced restored tasks with full schema fields (`due_at`, `status`, `order`, `subtasks`, `category_ids`, `assignees`) to Supabase and Hive.
  - Forced `await _refreshPersonalTasks()` upon undo to eliminate stale in-memory task lists on Flutter Web.
  - Cleaned up pending sync deletions via `SyncService().removeFromQueue` when restored immediately.

---

## [0.3.4] - 2026-10-29

### 🚀 Added
- **Exact Time Extraction in Hybrid AI Parsing**:
  - Added `AiService.parseAiDueDate` supporting full ISO8601 timestamps and explicit user-specified times.
  - Added regex time capture in `LocalHeuristicParser` (`needle_engine.dart`) for standard formats (`5 pm`, `17:00`, `9:30 am`, `noon`).
  - Added context-aware time blending in `applyGeminiTemplateContext`: preserves user-specified time instead of defaulting to midday `12:00 PM`.
  - Updated Edge Function prompt in `supabase/functions/ai/index.ts` to output `YYYY-MM-DDTHH:mm:ss` ISO format when time is mentioned.
  - Added 5 test cases in `helm/test/ai_service_hybrid_test.dart` verifying explicit time extraction and parsing.

---

## [0.3.3] - Navigation Hotfix

### 🐛 Fixed
- **Communities Navigation**: Clicking the "Communities" tab on the bottom navigation or sidebar now properly resets the active route and guarantees a return to the main dashboard/directory view, escaping deep-linked community context.

---

## [0.3.2] - Current Release

### 🚀 Added
- **Strict Client-Side RBAC Locking**: Non-editable tasks created by higher-ranking members (Admins/Owners) now display a "Read-Only" banner and lock all input fields.
- **Offline Data Sync Engine**: Built-in `sync_queue` powered by Hive and `connectivity_plus` for last-write-wins synchronization upon network reconnect.
- **Improved AI Parsing**: Enforced strict prompt rules on `gemini-3.5-flash-lite` for accurate 5-7 word title summaries and relative date calculations.
- **Automated Assignment Notifications**: Integrated a Postgres trigger to alert users immediately when assigned to a task.

### 🐛 Fixed
- **Navigation Sync**: Fixed a state mismatch between the sidebar items and the bottom navigation bar.
- **Calendar Filtering**: Fixed date comparison logic to use local normalized timestamps, resolving misplaced task dots.
- **Comment Deduplication**: Prevented duplicate comment renders and resolved premature 2-comment limit locks.
- **Layout Overflows**: Resolved `RenderFlex` errors in the task detail panel and task item cards.

---

## [0.3.1] - Support & Feedback Update

### 🚀 Added
- **Support & Feedback Portal**: In-app web modal and external portal (`feedback.html`) integrated with Supabase.
- **Global Keyboard Shortcuts**: Added `Ctrl+N` (New Task), `Ctrl+F` (Search), `Ctrl+Space` (Voice AI), `Ctrl+Tab` (Switch Tabs), and `Esc` (Close Panel).
- **Vercel Web Deployment**: Integrated GitHub Actions CI/CD workflow for automated web builds.

---

## [0.3.0] - Public Launch Milestone

### 🚀 Added
- **Interactive Calendar View**: Monthly timeline with due-date markers and daily task filtering.
- **Task Comments & 2-Comment Limit**: Discussion threads with an automatic reset trigger when task details or status change.
- **Profile Picture System**: Integrated `image_picker`, client-side image compression, and Supabase Storage avatars.
- **WhatsApp-Style Initials**: Automatic fallback avatars displaying user initials.
- **Subtask Management**: Dynamic creation and interactive checklist for subtasks.

---

## [0.2.2] - AI & Customization Update

### 🚀 Added
- **Generative AI Integration**: Natural language task creation via `gemini-3.5-flash-lite`.
- **Command Bar Widget**: Text and voice input bar with real-time listening animation.
- **Real-time Notifications**: In-app bell with unread badges and live updates via Supabase Realtime streams.

---

## [0.2.1] - Community & Deep Linking

### 🚀 Added
- **Community Workspaces**: Shared team spaces with role management (Owner, Admin, Member).
- **Deep Linking**: Added `helm://invite` link handler for seamless team onboarding.
- **Full Task CRUD**: Complete editing, status toggling, and deletion with "Undo" support.

---

## [0.1.0] - Foundation

### 🚀 Added
- **Local Storage Engine**: Core Hive NoSQL setup with Offline-first architecture.
- **Material 3 Design**: Dark Slate (`#1E2124`) & Mint Green (`#88C0A4`) design system.
- **Velocity Dashboard**: Daily goal progress tracking and completion streaks.
