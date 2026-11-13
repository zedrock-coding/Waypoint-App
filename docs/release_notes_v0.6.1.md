# Waypoint v0.6.1 — Maintenance & Stabilization Release 🧭

[![Version](https://img.shields.io/badge/version-0.6.1--build.24-88C0A4?style=for-the-badge&labelColor=111417)](https://github.com/zedrock-coding/Waypoint-App/releases/tag/v0.6.1)
[![Engine](https://img.shields.io/badge/Flutter-3.x_Material_3-111417?style=for-the-badge&logo=flutter&logoColor=88C0A4)](https://flutter.dev)
[![Backend](https://img.shields.io/badge/Supabase-Auth_%26_Postgres_RLS-111417?style=for-the-badge&logo=supabase&logoColor=88C0A4)](https://supabase.com)
[![Offline](https://img.shields.io/badge/Storage-Hive_NoSQL_Local--First-111417?style=for-the-badge&logo=hive&logoColor=88C0A4)](https://pub.dev/packages/hive)
[![AI Orchestrator](https://img.shields.io/badge/Orchestrator-gemini--3.5--flash--lite-111417?style=for-the-badge&logo=google&logoColor=88C0A4)](https://ai.google.dev)

> **Waypoint v0.6.1** delivers critical task lifecycle fixes, timezone-accurate completed task filtering, seamless calendar scheduling, and an integrated in-app feedback and bug reporting system connected to Supabase.

---

## 📦 Release Artifacts & Targets

| Platform | Distribution Target | Details / File | Status |
|---|---|---|---|
| **Web** | Progressive Web App (PWA) | Production standalone bundle (`build/web`) | `Verified (--pwa-strategy=none)` |
| **Android** | `app-release.apk` | `build/app/outputs/flutter-apk/app-release.apk` | `Building Release` |
| **Windows Desktop** | `waypoint.exe` (x64 Release) | `build/windows/x64/runner/Release/waypoint.exe` | `Ready for Build` |

---

## 🌟 Key Engineering Enhancements & Fixes

### 1. 💬 In-App Feedback & Bug Report System
* **Obsidian Precision Modal (`FeedbackDialog`)**:
  * Clean modal dialog matching the Obsidian Precision design tokens (`#111417` surface, `#88C0A4` mint accent, JetBrains Mono tags).
  * Category selector chips: `General`, `Bug Report`, and `Feature Idea`.
  * Context-aware: automatically populates current user email and name from auth session.
  * Direct Supabase Cloud persistence: writes entries directly to the `feedback` table with timestamp and client context.
  * Immediate assistance: direct WhatsApp link for urgent support.
* **Universal Access Points**:
  * Top navigation header (Feedback icon button).
  * Desktop sidebar footer (Dedicated tile).
  * Settings view ("Feedback & Bug Report" tile).
  * Account view ("Support & Feedback" action).

### 2. 🐛 Task Lifecycle & Completed Tasks Stabilization
* **PostgreSQL Upsert vs Update Fix (`TaskProvider._mutate`)**:
  * Corrected `SyncActionType.update` to use Supabase PostgREST `.update(patch).eq('id', id)` instead of `.upsert(payload)`.
  * Resolves PostgreSQL `NOT NULL` constraint violations on partial updates where non-updated fields (such as `title` or `user_id`) were omitted.
* **Timezone-Normalized Date Matching**:
  * Applied `.toLocal()` conversions when calculating `completedTasksToday` and matching tasks in `ScheduleView._getEventsForDay`.
  * Eliminates date-shift discrepancies where UTC midnight differences caused tasks completed today to disappear.
* **Realtime Sync Deletion Guard**:
  * Guarded `localRowsMissingRemotely` in `TaskProvider._setupSupabaseSync` with `if (remoteIds.isNotEmpty)`.
  * Prevents local Hive task cache from being mistakenly purged when remote queries return an initial empty snapshot or during network reconnect transitions.
* **Immediate In-Memory Synchronization**:
  * Added `await _refreshPersonalTasks()` after `addTask`, `updateTask`, and `updateTaskStatus` to synchronize local in-memory view lists immediately.
  * Corrected `TodayView` to accurately filter tasks when `TodayFilter.completed` is selected.

### 3. 📅 Schedule Calendar View Integration
* **Comprehensive Task Mapping**:
  * Updated `TaskProvider.allTasksWithDueDates` to pull directly from the Hive storage box via `UnifiedTask.fromHive(t)`.
  * Tasks with either `dueDate` or `dateTime` display reliably on the calendar for both completed and active states.

---

## 🔒 Security & Verification Gate

* **Analyzer**: `flutter analyze --fatal-infos` passed with 0 warnings and 0 errors.
* **Unit & Widget Tests**: All 186 automated test suites passed (`186 passed`).
* **Secret Scanning**: Scanned via Gitleaks with 0 secrets detected.
