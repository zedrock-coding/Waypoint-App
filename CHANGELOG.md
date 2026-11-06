# Changelog

## [v0.5.0] - 2026-11-06

### Changes
# Waypoint v0.5.0 — Production Release 🧭

[![Version](https://img.shields.io/badge/version-0.5.0--build.21-88C0A4?style=for-the-badge&labelColor=1E2124)](https://github.com/zedrock-coding/Waypoint-App/releases/tag/v0.5.0)
[![Engine](https://img.shields.io/badge/Flutter-3.x_Material_3-1E2124?style=for-the-badge&logo=flutter&logoColor=88C0A4)](https://flutter.dev)
[![Backend](https://img.shields.io/badge/Supabase-Auth_%26_Postgres_RLS-1E2124?style=for-the-badge&logo=supabase&logoColor=88C0A4)](https://supabase.com)
[![Offline](https://img.shields.io/badge/Storage-Hive_NoSQL_Local--First-1E2124?style=for-the-badge&logo=hive&logoColor=88C0A4)](https://pub.dev/packages/hive)
[![AI Orchestrator](https://img.shields.io/badge/Orchestrator-gemini--3.5--flash--lite-1E2124?style=for-the-badge&logo=google&logoColor=88C0A4)](https://ai.google.dev)

> **Waypoint v0.5.0** delivers a hands-free conversational voice workflow with interactive speech audio playback, resolves monotonic recording timer freezes, provides multimodal binary audio format sniffing, and guarantees cross-platform sync badge visibility.

---

## 📦 Release Artifacts & Targets

| Platform | Distribution Target | Details / File | SHA-256 Digest |
|---|---|---|---|
| **Windows Desktop** | `waypoint.exe` (x64 Release) | `build/windows/x64/runner/Release/waypoint.exe` | `57C074B089F3C0C912691ABBB0B127C89BF432DDB939443A91F6D7ED86BCDA04` |
| **Android** | `app-release.apk` (61.5 MB) | `build/app/outputs/flutter-apk/app-release.apk` | `61148B1D7EC71884CA1D8D7E8700F8744627F65D0B98D65E36AB620CEF39C567` |
| **Web** | Progressive Web App (PWA) | Production standalone bundle (`build/web`) | `Verified (--pwa-strategy=none)` |

---

## 🌟 Key Engineering Fixes & Enhancements

### 1. 🎙️ Interactive Conversational AI Voice Loop & Audio Disambiguation
* **Cross-Platform Speech Synthesis**: Integrated high-performance speech synthesis (`flutter_tts` / SAPI on Windows, platform TTS on Android/Web) within `SherpaTtsService` for low-latency voice responses.
* **Autonomous Pause & Resume**: Audio capture cleanly pauses when the AI speaks clarifying questions and automatically unpauses/resumes recording immediately upon speech completion.
* **Multi-Turn Context Accumulation**: Successive user dictations accumulate across dialogue turns rather than restarting from scratch, allowing effortless voice task completion.
* **Audible Confirmation**: Newly formed tasks announce successful extraction before preview rendering.

### 2. ⏱️ Audio Recording Monotonic Countup Timer
* **Lifecycle Initialization Fix**: Resolved duration timer cancellation race in `AudioRecordingService` by disposing stale timers prior to assigning `_recordStartTime`.
* **Isolated Smooth Ticker**: Integrated a dedicated 100ms periodic timer updating elapsed state independently of widget render cycles (`00:ss / 00:30`).
* **Instantaneous UI Binding**: Exposed `AudioRecordingService.elapsed` getter to eliminate latency between overlay mounting and first timer tick.

### 3. 🔄 Universal Header Sync Badge & Responsive Modal
* **Standardized Header Action**: Replaced the 8px green dot with a standard `IconButton` container (`Icons.sync_rounded`) matching adjacent app bar controls.
* **Three Visual Engine States**:
  * **Synced**: Mint Green (`#88C0A4`) sync icon with subtle status pip indicating synchronized local Hive and Supabase cloud state.
  * **Syncing**: Centered circular progress indicator with nested sync glyph during active flush cycles.
  * **Pending**: High-contrast Amber icon wrapped in a dynamic numeric badge reflecting unflushed queue depth.
* **Responsive Bottom Sheet**: Enclosed title text in `Expanded(overflow: TextOverflow.ellipsis)` to resolve 142px flex overflow on narrow mobile viewports.

### 4. 🎵 Dynamic Multimodal Audio Header Inspection
* **Binary Magic Sniffing**: Implemented `AiService.detectMimeType()` checking raw container signatures (`ftyp` for MP4/M4A, `ID3` for MP3, `RIFF` for WAV, `OggS` for OGG).
* **Accurate Content-Type Header**: Eliminates Gemini API 400 rejection errors caused by mismatched audio MIME wrappers.

### 5. 🪟 Windows Desktop Hardening & Toolchain Automation
* **Automated Package Restoration**: Configured `nuget.exe` pipeline for C++/WinRT plugin dependencies.
* **Native Audio I/O Integration**: Verified native Windows audio recording (WASAPI) and speech output (SAPI) without external binary bloat.
* **Permission Fallbacks**: Added fallback handling for microphone permission checks on desktop platforms.

---

## 🧪 Verification & Quality Metrics

```text
✓ Test Suite:         135 passing unit, service, and widget tests (100% clean)
✓ Flutter Analyzer:   Zero warnings or errors (flutter analyze --fatal-infos)
✓ Windows Runner:     Debug and Release binaries built and verified
✓ Web Production:     PWA release bundle generated cleanly
✓ Cloud Pipeline:     End-to-end task extraction verified via Supabase & Gemini
```

---

*Waypoint Team • Built for precision, speed, and focus.*


## [v0.4.9] - 2026-11-05

### Changes
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


## [v0.4.3] - 2026-11-05

### Changes
* feat: implement production remediation and architectural specification suite (5028aef)
* fix(publish): extract build number dynamically for release title (13f7929)
* chore: bump version to 0.4.2+13 for blueprint release (2a5303b)
* feat: implement Master Architectural Blueprint and verification suite (e727da9)
* fix(android): pin targetSdk to 34 and sync versioned release APK (c1283fd)
* docs: document single-key shortcut removal in release notes (4f33f49)
* fix(shortcuts): remove single-key shortcuts for C and N (e3167d9)
* docs: add release notes for v0.4.1 (6f74e01)
* feat(release): automate GitHub release creation with GCM auth in publish.sh (92a5174)
* feat: add Inno Setup script for Windows installer (42c02b8)


## [v0.4.2] - 2026-11-05

### Changes
* chore: bump version to 0.4.2+13 for blueprint release (2a5303b)
* feat: implement Master Architectural Blueprint and verification suite (e727da9)
* fix(android): pin targetSdk to 34 and sync versioned release APK (c1283fd)
* docs: document single-key shortcut removal in release notes (4f33f49)
* fix(shortcuts): remove single-key shortcuts for C and N (e3167d9)
* docs: add release notes for v0.4.1 (6f74e01)
* feat(release): automate GitHub release creation with GCM auth in publish.sh (92a5174)
* feat: add Inno Setup script for Windows installer (42c02b8)
* feat: add automated release publishing pipeline and editor configurations (36d5c8c)
* chore: bump version to 0.4.1+12 (cc5cb8b)


## [v0.4.1] - 2026-11-04

### Changes
* docs: document single-key shortcut removal in release notes (4f33f49)
* fix(shortcuts): remove single-key shortcuts for C and N (e3167d9)
* docs: add release notes for v0.4.1 (6f74e01)
* feat(release): automate GitHub release creation with GCM auth in publish.sh (92a5174)
* feat: add Inno Setup script for Windows installer (42c02b8)
* feat: add automated release publishing pipeline and editor configurations (36d5c8c)
* chore: bump version to 0.4.1+12 (cc5cb8b)
* feat: implement Waypoint architectural blueprint, features, and test suites (87ca14d)
* feat(audio,ai): add real-time audio visualizer, multi-phase feedback, and subtask breakdown automation (aa792d4)
* feat(settings): add GitHub updates link to About and Settings (bd041e0)


## [v0.4.1] - 2026-11-04

### Changes
* fix(shortcuts): remove single-key shortcuts for C and N (e3167d9)
* docs: add release notes for v0.4.1 (6f74e01)
* feat(release): automate GitHub release creation with GCM auth in publish.sh (92a5174)
* feat: add Inno Setup script for Windows installer (42c02b8)
* feat: add automated release publishing pipeline and editor configurations (36d5c8c)
* chore: bump version to 0.4.1+12 (cc5cb8b)
* feat: implement Waypoint architectural blueprint, features, and test suites (87ca14d)
* feat(audio,ai): add real-time audio visualizer, multi-phase feedback, and subtask breakdown automation (aa792d4)
* feat(settings): add GitHub updates link to About and Settings (bd041e0)
* feat(seo,ai): add web SEO tags, sitemap, robots.txt, and subtask decomposition (7c93182)


All notable changes and public releases of Waypoint are documented here.

## [v0.4.1] - 2026-11-04

### 🚀 Added
* **Real-Time Audio Waveform & Voice Overlay**: Dynamic 60fps mic visualizer with multi-phase transcription feedback and audio chunk buffering.
* **AI Subtask Breakdown & Needle Dispatch Engine**: Automated task decomposition via Gemini 3.5 Flash Lite with hybrid offline fallback parser.
* **Native Android Home Screen Widgets**: Three standalone widgets (Agenda view, Month density grid, and Priority filter).
* **Hardened Offline Mutation Engine**: Re-architected sync queue around deterministic `SyncMutation` payloads with reactive `SyncBadge`.
* **Single-File Windows Installer**: Packaged setup installer (`Waypoint-v0.4.1-Setup.exe`) via Inno Setup.
* **Automated Publishing Pipeline**: Integrated `publish.sh` with credential helpers and GitHub Releases.

### 🛠️ Changes & Fixes
* Added in-app GitHub release updates link in About and Settings screens.
* Automated version naming across Gradle and CMake builds.

## [v0.4.0] - 2026-10-30

### 🚀 Added
* Universal deep linking (`waypoint://invite`) and passwordless 6-digit email OTP.
* Waypoint rebrand across workspace, manifest, and deep link schemas.
* Local Hive storage migration and gamified velocity streak tracking.
