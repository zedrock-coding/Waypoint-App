# Changelog

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
