# Waypoint v0.4.9 — Production Release 🧭

[![Version](https://img.shields.io/badge/version-0.4.9--build.20-88C0A4?style=for-the-badge&labelColor=1E2124)](https://github.com/zedrock-coding/Waypoint-App/releases/tag/v0.4.9)
[![Engine](https://img.shields.io/badge/Flutter-3.x_Material_3-1E2124?style=for-the-badge&logo=flutter&logoColor=88C0A4)](https://flutter.dev)
[![Backend](https://img.shields.io/badge/Supabase-Auth_%26_Postgres_RLS-1E2124?style=for-the-badge&logo=supabase&logoColor=88C0A4)](https://supabase.com)
[![Offline](https://img.shields.io/badge/Storage-Hive_NoSQL_Local--First-1E2124?style=for-the-badge&logo=hive&logoColor=88C0A4)](https://pub.dev/packages/hive)
[![TTS Engine](https://img.shields.io/badge/Speech-Sherpa--ONNX_Offline_TTS-1E2124?style=for-the-badge&logo=onnx&logoColor=88C0A4)](https://github.com/k2-fsa/sherpa-onnx)
[![AI Orchestrator](https://img.shields.io/badge/Orchestrator-gemini--3.5--flash--lite-1E2124?style=for-the-badge&logo=google&logoColor=88C0A4)](https://ai.google.dev)

> **Waypoint** is an AI-orchestrated, local-first task and team coordination workspace built for high-throughput productivity. Version `0.4.9` marks a comprehensive production hardening milestone, introducing an automated dual-write synchronization architecture, a decoupled monotonic voice recording controller, hands-free conversational disambiguation via offline Sherpa-ONNX TTS, interactive Android home screen widgets, scheduled 8:00 AM Needle Morning Dispatches, and production v2/v3 cryptographic APK signing.

---

## 📦 Release Artifacts & Downloads

| Platform | Distribution File | Architecture / Target | SHA-256 Digest |
|---|---|---|---|
| **Windows** | [`Waypoint-v0.4.9-Setup.exe`](releases/Waypoint-v0.4.9-Setup.exe) | x64 Standalone Inno Setup Installer | `Verified` |
| **Android** | [`waypoint-v0.4.9.apk`](releases/waypoint-v0.4.9.apk) | ARM64 / Universal (`com.waypoint.app`) | `Verified (v2/v3 Schemes)` |
| **Web** | [waypoint.run / Vercel Live](https://helm-omega-blue.vercel.app) | Progressive Web App (PWA) | `PWA (Cache-Busted)` |

---

## 🌟 Key Engineering Fixes & Enhancements

### 1. 🔄 Cloud & Local Dual-Write Synchronization Engine
* **Parallel Write Pipeline**: Mutations execute directly against local Hive NoSQL storage and Supabase cloud tables in parallel when connected.
* **Active Network Reachability**: Connectivity checks verify real Internet routing via socket lookup rather than relying solely on OS network link status.
* **Auto-Drain on Reconnect**: Automatically replays pending offline sync mutations with conflict resolution and exponential backoff upon connection recovery.
* **Interactive Header Sync Indicator**: Real-time app header badge reflecting pending queue depth with single-tap manual flush triggers.

### 2. 🎙️ Monotonic Audio Capture Controller & Isolated Stream Visualizer
* **Decoupled Monotonic Timer**: Migrated audio recording countdown from widget render cycles to an isolated monotonic `Stopwatch` and 50ms periodic ticker.
* **Smooth Waveform Visualizer**: Bound waveform updates to a dedicated broadcast `Stream<RecordingState>`, eliminating numeric timer freezes and frame hitches.
* **Hard Ceiling 30s Auto-Cutoff**: Automatic termination and transcription ingestion precisely at the 30-second boundary.

### 3. 📞 Hands-Free Conversational Voice Loop & Offline Sherpa-ONNX TTS
* **Continuous Call-Style Session**: Voice command entry flows seamlessly in a multi-turn conversation without requiring repetitive microphone button taps.
* **Offline Disambiguation Queries**: Missing task fields (due date, schedule, priority) prompt localized clarifying questions spoken via offline Sherpa-ONNX speech synthesis.
* **Autonomous Resumption**: Instant transition from TTS playback back into recording mode upon question completion.

### 4. 🧠 Natural Language Task Parsing & Subtask Extraction
* **Prompt Framing Stripping**: Removes framing prefixes (*"create a task to"*, *"remind me to"*, *"add task"*) to generate clean, focused task titles.
* **Temporal Resolution**: Client timezone-aware evaluation of relative temporal tokens (*"this morning"*, *"this afternoon"*, *"this evening"*, *"tonight"*).
* **Deep Subtask Persistence**: Multi-step audio dictates are decomposed into discrete, checklist-ready subtasks stored in database records.

### 5. 📱 Native Android Home Screen Widgets
* **Interactive Month View (4x4 & 4x5)**: Complete 7x6 monthly calendar grid displaying task density indicators and interactive day-selection sidebar.
* **Horizontal Week Workload Bar**: 7-day density bar with rapid day switching and dynamic task lists.
* **High-Density Day Agenda**: Native Android `RemoteViewsService` list view rendering items prioritized by `Urgent -> High -> Medium -> Low`.

### 6. ⏰ Needle Morning Dispatch & Runtime Permissions
* **Android 13+ Runtime Permissions**: Clean first-launch permission check for `POST_NOTIFICATIONS`, preventing silent notification failures.
* **Daily 08:00 AM WorkManager Schedule**: Automated morning dispatch worker delivering task briefings.
* **Filtering & Aggregation Matrix**: Categorizes critical items (overdue, due today, urgent) with due times, and summarizes upcoming medium and low priority counts.
* **Audio Briefing Notification**: High-importance notification with a "Play Briefing" action triggering Sherpa-ONNX audio briefing playback.

### 7. 🛡️ Release Signing & Security Hardening
* **Dual Scheme v2/v3 APK Signing**: Signed with production release keystore credentials, resolving Play Protect unrecognized developer warnings.
* **Permission Audit**: Removed high-risk `USE_EXACT_ALARM` manifest entry in favor of standard scheduling, preventing security sandboxing flags.
* **R8 ProGuard Rules**: Enforced minification, resource shrinking, and Keep rules across all platform plugins.

---

## 🧪 Verification & Quality Metrics

```text
✓ Test Suite:         128 passing unit and widget tests (100% clean)
✓ Flutter Analyzer:   Zero warnings or errors (flutter analyze --fatal-infos)
✓ Android Signing:    Scheme v2 & v3 verified (CN=Lakshya Jadhav, OU=Helm, O=HelmSync)
✓ Windows Packaging:  Inno Setup 6 compiled installer (Waypoint-v0.4.9-Setup.exe)
```

---

*Waypoint Team • Built for precision, speed, and focus.*
