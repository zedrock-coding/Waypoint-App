# Waypoint v0.4.1 — Production Release 🧭

[![Version](https://img.shields.io/badge/version-0.4.1-88C0A4?style=for-the-badge&labelColor=1E2124)](https://github.com/zedrock-coding/Waypoint-App/releases/tag/v0.4.1)
[![Engine](https://img.shields.io/badge/Flutter-3.x_Material_3-1E2124?style=for-the-badge&logo=flutter&logoColor=88C0A4)](https://flutter.dev)
[![Backend](https://img.shields.io/badge/Supabase-Auth_%26_Postgres_RLS-1E2124?style=for-the-badge&logo=supabase&logoColor=88C0A4)](https://supabase.com)
[![Offline](https://img.shields.io/badge/Storage-Hive_NoSQL_Local--First-1E2124?style=for-the-badge&logo=hive&logoColor=88C0A4)](https://pub.dev/packages/hive)
[![AI Model](https://img.shields.io/badge/Orchestrator-gemini--3.5--flash--lite-1E2124?style=for-the-badge&logo=google&logoColor=88C0A4)](https://ai.google.dev)

> **Waypoint** (formerly *Helm*) is an AI-orchestrated, local-first task management workspace built for teams who value action over noise. Version `0.4.1` introduces real-time voice waveforms with AI subtask breakdown, native Android home screen widgets, single-file Windows setup packaging, and hardened offline synchronization queues.

---

## 📦 Release Assets & Downloads

| Platform | File Artifact | Target Architecture |
|---|---|---|
| **Windows** | `Waypoint-v0.4.1-Setup.exe` | x64 Standalone Inno Setup Installer |
| **Android** | `waypoint-v0.4.1.apk` | ARM64 / Universal (`applicationId: com.waypoint.app`) |
| **Web** | [waypoint.run / Vercel Live](https://helm-omega-blue.vercel.app) | PWA with Cache-Busted Service Worker |

---

## 🌟 Highlights & What's New in v0.4.1

### 1. Real-Time Audio Visualizer & Conversational Voice Overlay
* **Reactive Waveform Canvas**: Integrated dynamic 60fps audio waveform visualizer (`AudioWaveformVisualizer`) reflecting mic amplitude with Slate & Mint theme accents.
* **Multi-Phase Voice Feedback**: Enhanced `AIVoiceOverlay` with instant speech-to-text transcription states, audio caching, and conversational feedback loops.
* **Audio Capture Controller**: Modular audio recording lifecycle management supporting local chunk buffering and interruption recovery.

### 2. AI Subtask Decomposition & Needle Dispatch Engine
* **Automated Task Breakdown**: Complex natural language tasks are intelligently decomposed into actionable subtasks via `gemini-3.5-flash-lite`.
* **Hybrid Needle Dispatch Engine**: Offline-first heuristic routing that falls back to localized regex/keyword rules when offline and escalates to Edge AI when connected.
* **Subtask Extraction Tests**: Comprehensive test suite verifying deterministic subtask generation and title normalization.

### 3. Native Android Home Screen Widgets
* **Three Dedicated Widget Layouts**:
  * **Agenda View**: Quick-glance checklist of tasks due today.
  * **Month View**: Compact monthly calendar grid showing pending task density.
  * **Priority View**: Urgent filter isolating High-priority items directly on the home screen.
* **Interactive Widget Provider**: Fast update cycles without waking the full Flutter runtime.

### 4. Robust Offline Mutation Engine & Reactive Sync Badge
* **Structured Sync Mutations**: Re-architected sync queue around deterministic `SyncMutation` payloads with automatic deduplication.
* **Visual Sync Indicator**: Added `SyncBadge` widget showing pending local changes and syncing animations during active network flushes.
* **Full Test Coverage**: Dedicated unit tests for sync queue ordering, conflict resolution, and retry backoff.

### 5. Automated Windows Setup & Public Release Pipeline
* **Single-File Setup Installer**: Packaged with Inno Setup (`Waypoint-v0.4.1-Setup.exe`) featuring automated shortcut creation, uninstaller, and compression.
* **Automated Publishing (`publish.sh`)**: Direct integration with Git Credential Manager and GitHub CLI (`gh release`) with zero-leakage security audits.
* **In-App GitHub Updates**: Added direct links to release notes in About and Settings screens.

---

## ⌨️ Desktop Keyboard Bindings

Waypoint provides global single-key shortcuts on desktop platforms:

| Key | Action |
|:---:|---|
| <kbd>N</kbd> | Open New Task modal |
| <kbd>C</kbd> | Jump to Calendar & Timeline view |
| <kbd>/</kbd> | Focus AI Natural Language Command Bar |
| <kbd>Esc</kbd> | Dismiss active detail panel or modal |

---

## 🔄 Upgrading & Verification

```bash
# Verify analysis and strict linter rules
flutter analyze --fatal-infos

# Run comprehensive test suite
flutter test

# Build production web bundle
flutter build web --release --pwa-strategy=none
```

---

*For technical architectural specifications, refer to `docs/architecture.md`. For security compliance and RLS auditing, review `docs/security-remediation-plan.md`.*
