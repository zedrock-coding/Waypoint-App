# Waypoint 0.5.1 - Production Release 🚀

**Waypoint 0.5.1** is an AI-orchestrated task management workspace. Evolved from Helm into a comprehensive, AI-powered team orchestration system. Optimized for **Android**, **Windows**, and **Web**, Waypoint provides a professional, reactive experience for real-time team collaboration and personal productivity.

![Aesthetic](https://img.shields.io/badge/Aesthetic-Slate%20%26%20Mint-88C0A4)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Web-blue)
![Version](https://img.shields.io/badge/Version-v0.5.1-green)
![License](https://img.shields.io/badge/License-Source--Available-orange)

---

## 📥 Download & Live Access (v0.5.1)

Get the latest production build for your platform directly from the [Waypoint Releases](https://github.com/zedrock-coding/Waypoint-App/releases/latest) page:

| Platform | Type | Direct Download Link |
| :--- | :--- | :--- |
| **Android** | APK (`v0.5.1`) | [📲 Download Android APK](https://github.com/zedrock-coding/Waypoint-App/releases/latest/download/waypoint-v0.5.1.apk) |
| **Windows** | Executable (`v0.5.1`) | [💻 Download Windows App](https://github.com/zedrock-coding/Waypoint-App/releases/latest/download/Waypoint-v0.5.1-Setup.exe) |
| **Web** | Live Production PWA | [🌐 Launch Web App](https://helm-omega-blue.vercel.app) |

*Local Repository Mirrors*:
* 🪟 Windows Installer: [`Waypoint-v0.5.1-Setup.exe`](releases/Waypoint-v0.5.1-Setup.exe)
* 📱 Android APK: [`waypoint-v0.5.1.apk`](releases/waypoint-v0.5.1.apk)

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

## 🔐 Security & Integrity
Waypoint utilizes PostgreSQL Security Definer functions and strict Row Level Security (RLS) to ensure workspace isolation and tamper-proof multi-tenant security.

---

## 📄 License

Waypoint is **source-available, not open source**.

- **Source code**: proprietary, all rights reserved.
- **Compiled builds**: free to download, install, and use for personal or commercial purposes.

See [`LICENSE`](LICENSE) for complete terms.
