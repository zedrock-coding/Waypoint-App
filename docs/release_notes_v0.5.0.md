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
| **Android** | `app-release.apk` (61.6 MB) | `build/app/outputs/flutter-apk/app-release.apk` | `B161EAD3104A8A7C4D49E3E53EED8B8D37AFBE84D6B6057ED8A829D18CBFCC50` |
| **Web** | Progressive Web App (PWA) | Production standalone bundle (`build/web`) | `Verified (--pwa-strategy=none)` |

---

## 🌟 Key Engineering Fixes & Enhancements

### 1. 🎙️ Interactive Conversational AI Voice Loop & Audio Disambiguation
* **Physical Asset Staging & Native Paths**: Implemented `SherpaModelAssetManager` ensuring ONNX model and token binaries are extracted from the APK to physical device storage with non-zero byte validation before native runtime initialization.
* **Standardized 44-Byte RIFF/WAV Container Encoding**: Integrated `WavAudioContainerUtil` wrapping raw PCM audio samples into valid WAV containers with accurate sample rate and block alignment headers to prevent audio decoder rejection.
* **Strict State Machine Orchestrator**: Re-architected `VoiceSessionController` into a deterministic state engine (`Idle`, `UserListening`, `Processing`, `AgentSpeaking`, `Completed`, `Error`).
* **Emergency Watchdog Failsafe**: Embedded an automated 4-second safety watchdog timer preventing loop freezes if audio sinks hang, forcefully advancing back to `UserListening` and resetting the 30-second countdown timer.
* **Audio Focus Management**: Enforces synchronous microphone release prior to speech playback; declared `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` in `AndroidManifest.xml`.
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
✓ Test Suite:         140 passing unit, service, and widget tests (100% clean)
✓ Subsystem Suites:   TTS asset staging, WAV encoding, watchdog failsafe, and dispatch matrix verified
✓ Flutter Analyzer:   Zero warnings or errors (flutter analyze --fatal-infos)
✓ Windows Runner:     Debug and Release binaries built and verified
✓ Web Production:     PWA release bundle generated cleanly
✓ Cloud Pipeline:     End-to-end task extraction verified via Supabase & Gemini
```

---

*Waypoint Team • Built for precision, speed, and focus.*
