# Changelog - Helm Workspace 🚀

All notable changes to the **Helm** / **Waypoint** project will be documented in this file.

---

## [0.6.2] - 2026-11-14

### 🎨 UI & Aesthetics
- **Branded Obsidian Header**:
  - Restored high-resolution Waypoint app logo (`assets/icon/icon.png`) with crisp 4px rounded borders and fallback vector rendering.
  - Applied **Geist** typography to app branding and view titles.
  - Eliminated mobile header button collision by removing redundant text buttons and wrapping titles in flexible containers.
- **Backdrop-Blurred Frosted Command Center**:
  - Replaced opaque floating command bar with an elegant 12px blur `BackdropFilter` and translucent dark slate styling.
  - Scoped bottom command bar to display exclusively on `Today` and `Inbox` views, preventing obscuration on `Settings`, `Schedule`, `Recurring`, and `Communities`.
  - Removed duplicate floating action button from navigation shell.
- **Obsidian Precision About Screen**:
  - Modernized `About Waypoint` settings screen to Obsidian Precision styling with surface cards, 4px corner radii, and JetBrains Mono badges.
  - Refined project attribution to solo creator **Lakshya Jadhav**.

### 🐛 Sync & Task Lifecycle Fixes
- **Startup Cloud Synchronization**:
  - Automatically invokes `loadRemoteTasks()` on app launch and upon authentication state transitions (`signedIn`, `tokenRefreshed`, `initialSession`), pulling remote tasks without requiring manual sync triggering.
  - Removed aggressive filtering that discarded community tasks on clean device installations.
  - Re-triggers in-memory task aggregation immediately upon receiving Supabase realtime stream events.
- **Recurring Routines Reconciliation**:
  - Preserved recurring tasks across both local Hive storage and remote Supabase tables when `isRecurring` or `recurrenceFrequency` is present.
  - Defaulted fallback frequency to `daily` so tasks such as "Daily Workout Routine" reliably populate `Recurring Routines`.
- **Calibrated Priority Levels**:
  - Aligned priority selectors in `TaskCreationDrawer` (High, Med, Low) with `TaskItemCard` display indicators and color accents, eliminating priority tier shifts.

---

## [0.6.1] - 2026-11-14

### 🚀 Added
- **In-App Feedback & Bug Reporting System**:
  - Modal dialog (`FeedbackDialog`) styled with Obsidian Precision tokens.
  - Category selector chips: `General`, `Bug Report`, and `Feature Idea`.
  - Contextual auto-fill for user name and email.
  - Direct persistence into Supabase `feedback` table.
  - Urgent WhatsApp support shortcut link.
  - Global access points: header icon button, sidebar footer tile, Settings view, and Account view.

### 🐛 Fixed
- **Task Lifecycle & Completed Tasks Disappearance**:
  - Corrected `TaskProvider._mutate` for `SyncActionType.update` to use Supabase PostgREST `.update(patch).eq('id', id)` instead of `.upsert(payload)`, resolving PostgreSQL `NOT NULL` constraint violations on partial updates.
  - Added `.toLocal()` timezone normalization for `completedTasksToday` and `ScheduleView._getEventsForDay` calendar queries, preventing date-shift clipping.
  - Guarded `localRowsMissingRemotely` in Supabase realtime sync against initial empty remote sets, preventing local task deletions during offline or reconnect states.
  - Synchronized in-memory task collections immediately after addition and updates via `_refreshPersonalTasks()`.
  - Fixed `TodayView` to accurately filter tasks when `TodayFilter.completed` is selected.
  - Mapped all dated tasks across Hive storage for accurate `ScheduleView` calendar rendering.

---

## [0.6.0] - 2026-11-14

### 🚀 Added
- **Obsidian Precision Design System & Typography**:
  - Dark Obsidian color tokens (`#111417` base/surface, `#191C1F` surfaceContainerLow, `#1D2023` surfaceContainer, `#272A2D` surfaceContainerHigh, `#323538` border/surfaceVariant, `#88C0A4` mint primary).
  - High-readability font pairing: **Geist** for body text and UI labels, **JetBrains Mono** for metadata, timestamps, priority pills, and monospace task codes (`#TASK-XXXX`).
  - Precision 4px card corner radii with crisp 1px borders.
- **Adaptive Responsive Shell**:
  - Desktop viewports (width ≥ 768px): persistent 256px left sidebar with brand header, "+ New Task" shortcut (`⌘N`), views navigation, workspaces list, and sync footer. Bottom navigation dock completely omitted.
  - Mobile viewports (width < 768px): compact 56px bottom navigation dock with central `+` CTA and quick tabs. Left sidebar completely omitted.
  - Header actions: Omni search (`⌘K`), quick `+ Add Task` (`⌘N`), AI Voice trigger (`mic`), notification bell, and user avatar.
- **Slide-Over Task Creation Drawer with AI Subtask Decomposition**:
  - Ergonomic slide-over drawer on desktop (`width: 480px`), animated bottom sheet on mobile.
  - Full AI feature preservation: **"✨ AI Decompose"** button invoking `AiService.generateSubtasks()` to synthesize milestone checklists.
  - Priority selector pills (Urgent, High, Med), interactive Date/Time pickers, recurrence cadence dropdown, workspace selectors, and dynamic checklist items.
- **Curated Filtered Views & Communities Hub**:
  - `TodayView`: Today's Focus header, live task metrics, filter chips (All Active, Recurring, High Priority, Completed), and collapsible completed tasks section.
  - `InboxView`: Delegated tasks across shared workspaces.
  - `RecurringView`: Automated recurring tasks configured to roll over on completion.
  - `ScheduleView`: Interactive `TableCalendar` with Obsidian tokens and day task list.
  - `CommunitiesOverviewView`: Dedicated workspace overview with "+ Create Community" and "Join via Code" dialogs.
  - `SettingsView`: Voice assistant, theme, and notification preferences.
- **Waypoint Diamond Monogram Vector Logo**:
  - Precision vector `CustomPainter` rendering Waypoint diamond monogram with crisp anti-aliasing across sidebar, header, and dialogs.

---

## [0.5.1] - 2026-11-10

### 🚀 Added
- **Needle AI Task Reconciliation & Cross-Verification Engine**:
  - Deterministic verification layer (`NeedleReconciliationEngine`) cross-examining raw STT speech transcripts against preliminary Gemini model extractions.
  - Imperative meta-framing sanitization: automatically strips prefixes (`"create a task saying"`, `"remind me to"`, `"please schedule"`) ensuring clean, canonical task titles.
  - Temporal anchor normalization: parses client context timestamp and timezone, mapping relative timings (`"tonight"` -> 21:00, `"today evening"` -> 18:00, `"tomorrow morning"` -> 09:00, `"in X hours"`) into normalized ISO-8601 timestamps.
  - Granular milestone decomposition: parses sequential speech markers (`first`, `then`, `also`, `finally`) into discrete subtasks with individual tracking.
  - Priority & entity resolution: maps explicit priority keywords (`urgent`, `high`, `medium`, `low`) and matches spoken names against accessible team members.
  - Dual-write direct persistence: saves verified tasks and subtask checklists directly to local Hive NoSQL and Supabase cloud tables.
  - Conversational clarification loop: triggers voice disambiguation via Sherpa-ONNX TTS when essential details are ambiguous, automatically resuming microphone capture.
- **Morning Dispatch Audio & Notification Center Feed**:
  - Voice audio playback for the Daily Morning Briefing (`playBriefing`).
  - Persistent in-app notification center integration, enabling users to re-play daily briefing audio later at any time.
- **Universal Responsive Layout Engine (`ResponsiveClamp`)**:
  - Responsive layout clamping and adaptive ratio scaling preventing RenderFlex overflow errors across varying mobile, tablet, and foldable form factors.

### 📉 Reduced & Cleaned
- **REDUCE Subtractive Maintenance**:
  - Pruned obsolete test audio asset (`Task_Creation_test_audio.mp3`, -564 KB binary reduction).
  - Removed unused dependencies (`file_picker: 8.1.7`, `cupertino_icons: ^1.0.8`) reducing bundle overhead.
  - Eliminated unreferenced dead-code aliases (`generateBriefingScript`) and legacy session artifacts.

---

## [0.5.0] - 2026-11-06

### 🚀 Added
- **Interactive Conversational AI Voice Loop & Diagnostic Remediation**:
  - Implemented `SherpaModelAssetManager` for physical asset staging from compressed APK bundles to persistent application storage with non-zero byte validation.
  - Implemented `WavAudioContainerUtil` encapsulating raw PCM inference samples into valid 44-byte RIFF/WAV containers to prevent system audio decoder errors.
  - Re-architected `VoiceSessionController` into a strict sequential state machine (`Idle`, `UserListening`, `Processing`, `AgentSpeaking`, `Completed`, `Error`).
  - Added an emergency 4-second watchdog timer automatically recovering from playback hangs and resetting the 30-second recording countdown.
  - Enforced synchronous microphone hardware focus release prior to audio speech output.
  - Declared `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` in `AndroidManifest.xml`.
  - Registered high-importance notification channel with sound, vibration, and heads-up banner display for Needle Morning Dispatch.
  - Live on-device audio playback (`flutter_tts` / SAPI / platform TTS) in `SherpaTtsService` for speaking clarification questions aloud.
  - Automatic audio recording pause during AI speech playback with seamless hands-free auto-resume upon completion.
  - Multi-turn conversation accumulation to maintain user prompt context across continuous dialogue turns.
  - Audible confirmation announcements for extracted tasks.
- **Multimodal Audio Format Sniffing**:
  - Binary magic byte inspection in `AiService.detectMimeType()` supporting MP4/M4A (`ftyp`), MP3 (`ID3`), WAV (`RIFF`), and OGG (`OggS`).
  - Strict Content-Type headers in Edge Function audio payloads preventing Gemini API format rejections.
- **Standardized Header Sync Status Action**:
  - Replaced 8px dot with standard `IconButton` container with `Icons.sync_rounded`.
  - Color-coded tri-state indicators: Mint Green (`#88C0A4`) for synced, spinner for syncing, and Amber numeric badge for pending mutations.
  - Wrapped modal title in `Expanded(overflow: TextOverflow.ellipsis)` eliminating 142px flex overflow on narrow screens.
- **Windows Desktop Build & Audio Pipeline**:
  - Verified native WASAPI audio recording and SAPI speech playback on Windows desktop.
  - Automated `nuget.exe` package restoration for C++/WinRT dependencies.

### 🐛 Fixed
- **Audio Recording Countup Timer**:
  - Corrected timer disposal order in `AudioRecordingService` eliminating immediate cancellation race conditions.
  - Added monotonic 100ms ticker rendering smooth elapsed duration (`00:ss / 00:30`).
  - Added `AudioRecordingService.elapsed` getter for instant UI state synchronization.

---

## [0.4.9] - 2026-11-06

### 🚀 Added
- **Dual-Write Synchronization Engine**:
  - Parallel writes directly to local Hive NoSQL storage and Supabase cloud tables with auto-drain on reconnect.
  - Socket reachability checks verifying true Internet routing.
- **Android Home Screen Widgets**:
  - Interactive Month View (4x4 & 4x5), 7-day horizontal workload bar, and high-density Day Agenda widgets.
- **Needle Morning Dispatch**:
  - Scheduled 8:00 AM daily task briefing via WorkManager with Android 13+ runtime notification permissions.
- **Production APK Release Signing**:
  - Configured scheme v2/v3 cryptographic signing and R8 minification rules.

---

## [0.4.0] - 2026-10-30

### 🚀 Added
- **Universal Deep Linking**:
  - Implemented deep-link routing for custom schemes (`waypoint://` and legacy `helm://`) as well as web URLs (`https://helm-omega-blue.vercel.app`).
  - Added persistent pending invite storage when logged out, displaying an invite banner on `AuthScreen`, and auto-joining the community upon authentication.
  - Added Android intent filters for verified web links and scheme interception.
- **First-Time Sign Up with Email OTP**:
  - Implemented passwordless sign-up flow using 6-digit Email OTP via Supabase Auth with automated resend timer cooldown (60s).
  - Integrated profile onboarding for first-time users to set their display name and initial password.
- **Password Authentication & Self-Service Recovery**:
  - Set Email + Password as default login interface for returning users.
  - Added self-service "Forgot password?" recovery flow sending recovery tokens/links and updating passwords in-app.
- **Remote Supabase Configuration**:
  - Configured redirect URL whitelist (`waypoint://login-callback`, `helm://login-callback`, `https://helm-omega-blue.vercel.app/**`, `localhost`) and set OTP length to 6 digits live via `supabase config push`.
- **Automated Build Versioning**:
  - Android Gradle Kotlin DSL automatically names APK outputs as `waypoint-v<version>.apk`.
  - Windows CMake post-build rule automatically copies the compiled binary to `waypoint-v<version>.exe`.

## [0.3.5] - Waypoint Rebranding & Workspace Upgrade

### 🚀 Added
- **Project Rebranding (Waypoint)**: Renamed workspace identity, pubspec package, android applicationId/label (`com.waypoint.app`), windows binary target, web title/manifest, and deep linking scheme (`waypoint://invite`).
- **Gamification & Streak Tracking**: Added local Hive `user_stats` tracking `current_streak`, `longest_streak`, and `last_completed_date` with `HapticFeedback` on completion, wired directly to `VelocityDashboardCard`.
- **In-App Feedback Modal**: Replaced detached browser launches with an in-app modal dialog (`showDialog`) for support and feedback, preventing lost focus for automated agents.
- **Global Desktop Shortcuts**: Registered single-key desktop bindings (`N` for New Task, `C` for Calendar, `/` for Command Bar) with editable text focus guards.
- **Dynamic Timezone in AI Context**: Injected client reference time with local timezone and UTC offset for high-accuracy relative date/time calculations on `gemini-3.5-flash-lite`.

### 🐛 Fixed
- **Onboarding & EULA Persistence**: Added persistent `has_seen_onboarding` check to bypass tutorial and EULA once completed, and strictly route unauthenticated users to `/auth`.
- **Tutorial Navigation**: Added visible 'Back' button alongside 'Next' / 'Get Started' and bound arrow key navigation on desktop.
- **Web Cache-Busting**: Added service worker update script and query-string cache-busting to prevent stale asset loads on web.

---

## [0.3.5-patch] - 2026-10-29

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
