# Waypoint 0.5.0 - Production Release 🚀

**Waypoint 0.5.0** is an AI-orchestrated task management workspace. Evolved from Helm into a comprehensive, AI-powered team orchestration system. Optimized for **Android**, **Windows**, and **Web**, Waypoint provides a professional, reactive experience for real-time team collaboration and personal productivity.

![Aesthetic](https://img.shields.io/badge/Aesthetic-Slate%20%26%20Mint-88C0A4)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Web-blue)
![Version](https://img.shields.io/badge/Version-0.5.0-green)
![License](https://img.shields.io/badge/License-Source--Available-orange)

---

## 📥 Download & Live Access

Get the latest build for your platform directly from the [Waypoint Releases](https://github.com/zedrock-coding/Waypoint-App/releases/latest) page:

| Platform | Type | Direct Download Link |
| :--- | :--- | :--- |
| **Android** | APK (`v0.5.0`) | [📲 Download Android APK](https://github.com/zedrock-coding/Waypoint-App/releases/latest/download/waypoint-v0.5.0.apk) |
| **Windows** | Executable (`v0.5.0`) | [💻 Download Windows App](https://github.com/zedrock-coding/Waypoint-App/releases/latest/download/Waypoint-v0.5.0-Setup.exe) |
| **Web** | Live Production PWA | [🌐 Launch Web App](https://helm-omega-blue.vercel.app) |

*Alternative release mirrors: [Helm GitHub Releases](https://github.com/zedrock-coding/Helm/releases/latest)*

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
    Edit `web/config.js` and set the Supabase URL and publishable key (`sb_publishable_…`).
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
