# Waypoint 0.6.1 - Production Release 🚀

**Waypoint 0.6.1** is an AI-orchestrated task management workspace. Evolved from Helm into a comprehensive, AI-powered team orchestration system. Optimized for **Android**, **Windows**, and **Web**, Waypoint provides a professional, reactive experience for real-time team collaboration and personal productivity.

![Aesthetic](https://img.shields.io/badge/Aesthetic-Obsidian%20%26%20Mint-88C0A4)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Web-blue)
![Version](https://img.shields.io/badge/Version-0.6.1-green)
![License](https://img.shields.io/badge/License-Source--Available-orange)

---

## 📥 Download & Live Access

Get the latest build for your platform directly from the [Waypoint Releases](https://github.com/zedrock-coding/Waypoint-App/releases/latest) page:

| Platform | Type | Direct Download Link |
| :--- | :--- | :--- |
| **Android** | APK (`v0.6.1`) | [📲 Download Android APK](https://github.com/zedrock-coding/Waypoint-App/releases/latest/download/waypoint-v0.6.1.apk) |
| **Windows** | Executable (`v0.6.1`) | [💻 Download Windows App](https://github.com/zedrock-coding/Waypoint-App/releases/latest/download/Waypoint-v0.6.1-Setup.exe) |
| **Web** | Live Production PWA | [🌐 Launch Web App](https://helm-omega-blue.vercel.app) |

*Alternative release mirrors: [Helm GitHub Releases](https://github.com/zedrock-coding/Helm/releases/latest)*

---

## 🌟 What's New in 0.6.1

### 💬 In-App Feedback & Bug Reporting System
*   **Direct Cloud Feedback**: Built-in modal dialog connected to Supabase `feedback` table for instant bug reporting and feature requests.
*   **Context-Aware Metadata**: Automatically pre-fills current authenticated user identity and context.
*   **Omni Access**: Accessible from the top header, sidebar footer, settings screen, and account view.

### 🐛 Task Lifecycle & Synchronization Stabilization
*   **PostgreSQL Partial Update Fix**: Switched `TaskProvider._mutate` updates to PostgREST `.update(patch).eq('id', id)` to avoid constraint errors on partial payloads.
*   **Timezone-Normalized Dates**: Accurate `.toLocal()` date evaluations ensuring tasks completed today remain visible in Today's focus and Schedule calendar views.
*   **Sync Safeguards**: Guarded local storage against empty remote snapshot deletions during network switches.
*   **Instant Local Updates**: Synchronized task providers immediately following task mutations.

---

## 🌟 What's New in 0.6.0

### 🎨 Obsidian Precision UI Overhaul & Typography
*   **Obsidian Dark Palette**: Modernized UI aesthetic with `#111417` base/surface, `#191C1F` low surface, `#1D2023` standard surface, `#272A2D` elevated surface, and `#88C0A4` mint accent.
*   **Geist & JetBrains Mono Fonts**: Typography powered by `google_fonts` pairing Geist for readable body and JetBrains Mono for monospace timestamps, task tags (`#TASK-XXXX`), and priority indicators.
*   **Waypoint Diamond Vector Monogram**: Custom vector-painted geometric diamond emblem integrated throughout the navigation shell.

### 📱 Adaptive Responsive Navigation Architecture
*   **Desktop Shell (≥768px)**: Persistent 256px left sidebar with brand identity, keyboard shortcuts (`⌘N` Add Task, `⌘K` Search), views switcher, workspace directory, and sync badge. Bottom dock is omitted.
*   **Mobile Shell (<768px)**: Compact 56px bottom navigation bar with central `+` quick-action button and one-tap view switches. Sidebar is omitted.
*   **Omni Action Header**: Search input with keyboard triggering, instant Add Task CTA, AI Voice assistant button, notifications center, and user profile avatar.

### 📝 Slide-Over Task Creation Drawer with AI Decompose
*   **Slide-Over Presentation**: Smooth right slide-over drawer on desktop (`480px`) and responsive bottom sheet on mobile.
*   **AI Milestone Synthesis**: Preserved **"✨ AI Decompose"** feature utilizing `AiService.generateSubtasks()` to convert complex prompts into step-by-step checklists.
*   **Granular Scheduling**: Priority pills, calendar date & time pickers, recurring cadence rules (Daily, Weekly, Bi-Weekly, Monthly), and dynamic checklist management.

### 🗂️ Curated Filtered Views & Communities Hub
*   **Today's Focus**: Filterable feed (All Active, Recurring, High Priority, Completed) with progress counters and collapsible completed section.
*   **Inbox**: Shared team feed displaying tasks assigned by others across communities.
*   **Recurring**: Dedicated management of repeating cadence routines.
*   **Schedule Calendar**: Integrated `TableCalendar` with Obsidian styling and day-by-day task lists.
*   **Communities Hub**: Overview of team workspaces with one-tap Create and Join via Code dialogs.

---

## 🌟 What's New in 0.5.1

### 🎯 Needle AI Task Reconciliation Engine
*   **Deterministic Cross-Verification**: Reconciles raw spoken speech transcripts against preliminary Gemini model extractions to eliminate hallucinations and retain core intent.
*   **Imperative Meta-Framing Sanitization**: Automatically strips conversational meta-framing (`"create a task saying"`, `"remind me to"`, `"please schedule"`) to produce concise canonical task titles.
*   **Relative Date & Temporal Anchoring**: Resolves relative phrases (`"tonight"`, `"tomorrow morning"`, `"today evening"`, `"in 2 hours"`) into normalized ISO-8601 timestamps against client time context.
*   **Sequential Subtask Milestone Extraction**: Decomposes multi-step spoken instructions (`first... then... also... finally...`) into discrete, trackable subtask checklists.
*   **Dual-Write Offline & Cloud Persistence**: Dual-writes verified tasks and subtask checklists directly to local Hive storage and Supabase cloud tables.
*   **Conversational Voice Disambiguation**: Engaging hands-free clarification turns via Sherpa-ONNX TTS playback when required details are ambiguous.

### 🎙️ Daily Morning Dispatch Audio & In-App Notification Center
*   **Audible Briefing Playback**: Voice audio narration when tapping "Play Briefing" in Daily Briefing.
*   **Persistent In-App Notification Feed**: Briefings saved directly to the notification feed allowing users to re-play voice briefings anytime.

### 📐 Universal Responsive Layout Engine (`ResponsiveClamp`)
*   **Zero RenderFlex Overflows**: Adaptive layout scaling and responsive sizing preventing UI overflow across diverse mobile and tablet screen dimensions.

### 📉 Subtractive Maintenance & Optimization (REDUCE)
*   **Reduced Binary Footprint**: Pruned unreferenced scratch audio files (-564 KB).
*   **Leaner Dependencies**: Removed unused packages (`file_picker`, `cupertino_icons`).
*   **Dead Code Cleanup**: Eliminated obsolete function aliases and orphaned test artifacts.

---

## 🌟 What's New in 0.5.0

### 🎙️ Conversational Call-Style Multi-Turn Voice Loop
*   **Symmetrical Context Tracking**: Captures both user utterances and assistant clarification turns in session history.
*   **Deep Draft Delta-Merging**: Retains captured titles, descriptions, and tags across follow-up disambiguation turns without overwriting data.
*   **Audio Focus Synchronization**: Dynamic TTS speech watchdogs scaled to text length with 500ms hardware drain delay to prevent audio clipping.
*   **Sub-Second Voice Processing**: Pre-flight remote queries replaced with local Hive caching; audio Base64 encoding offloaded to background Dart isolates.

### 🧠 Natural Language & Heuristic Parsing Engine
*   **Flexible Time & Date Recognition**: Supports relative weekdays (`next monday`), 12-hour clock (`5pm`, `9:30 am`), and 24-hour formats (`17:30`).
*   **Standalone Priority Detection**: Automatically extracts priority words (`urgent`, `critical`, `high`, `medium`, `low`) without requiring syntax prefixes.
*   **Graceful Default Fallback**: Defaults missing priority to `medium` when deadline is specified, eliminating redundant conversational loops.

### ⚡ Performance & Caching Engine
*   **Skeleton Loaders**: Integrated animated `TaskCardSkeleton` layouts to eliminate perceived network latency during initial fetch.
*   **Request Deduplication & Debouncing**: In-flight concurrent duplicate query collapsing and keystroke debouncing for search inputs.
*   **Immutable CDN Edge Caching**: Optimized cache headers configured in `vercel.json` for web assets and font pre-fetching.

### 🛡️ Enterprise Data Protection & Reliability
*   **Soft Deletion Safeguards**: Soft deletes using `deleted_at` timestamps with automatic filter enforcement.
*   **Mutation Audit Logs (CDC)**: Database triggers track row changes into dedicated audit tables.
*   **Batch Ceilings & Typed Safeguards**: Enforces strict mutation batch ceilings (100 rows per transaction) and prevents accidental cascade drops.

---

## 🛠 Tech Stack
*   **Framework**: Flutter (Material 3)
*   **AI Engine**: Gemini (`gemini-3.5-flash-lite`) proxied via Supabase Edge Functions
*   **Cloud Backend**: Supabase (PostgreSQL, Realtime, RLS, Storage)
*   **Local Storage**: Hive (Reactive high-speed NoSQL)
*   **State Management**: Provider (`ChangeNotifier`)
*   **Voice & Audio**: Native Sherpa-ONNX TTS runtime and `audio_session` focus orchestration

---

## ⚙️ Quick Start

### Prerequisites
*   **Flutter SDK**: ^3.41 (Dart ^3.11)
*   **Supabase project**: backend authentication and database sync.
*   **Gemini API key**: deployed exclusively as Supabase function secret (`GEMINI_API_KEY`).

### Steps
1.  **Clone & Install**:
    ```bash
    git clone https://github.com/zedrock-coding/Helm.git
    cd helm
    flutter pub get
    ```
2.  **Public configuration**:
    Edit `helm/web/config.js` and set the Supabase URL and publishable key (`sb_publishable_…`).
3.  **AI backend setup**:
    ```bash
    supabase functions deploy ai
    supabase secrets set GEMINI_API_KEY=your_key_here
    ```
4.  **Launch**:
    ```bash
    flutter run -d chrome
    ```

---

## 🔐 Security & Integrity
Waypoint utilizes PostgreSQL Security Definer functions and Row Level Security (RLS) ensuring strict workspace isolation and tamper-proof multi-tenant security.

---

## 📄 License

Waypoint is **source-available, not open source**.

- **Source code**: proprietary, all rights reserved.
- **Compiled builds**: free to download, install, and use for personal or commercial purposes.

See [`LICENSE`](LICENSE) for complete terms.
