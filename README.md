# Waypoint Pre-Release Builds

Dedicated testing branch containing pre-release binaries for testing.

---

## 📦 Available Pre-Release Binaries

| Platform | File | Size | SHA-256 Checksum |
| :--- | :--- | :--- | :--- |
| **Android** | [`releases/Waypoint-v0.6.1.apk`](releases/Waypoint-v0.6.1.apk) | 61.9 MB | `865450A60A854A4EB7E7ADF18FF87F1A5EAF3CDC225154EE88FE1135A3871887` |
| **Windows** | [`releases/Waypoint-v0.5.1-Setup.exe`](releases/Waypoint-v0.5.1-Setup.exe) | 26.8 MB | `C155BA3FFF238CBC5D59C185E4255673321F73FD6DBED2CA6D75DB92CA7B2091` |

---

## 🚀 What's New in v0.6.1

- **Obsidian Precision Design & Adaptive Shell**:
  - Full UI overhaul with Obsidian dark tokens and mint primary.
  - Geist & JetBrains Mono typography.
  - Desktop 256px sidebar vs mobile 56px bottom navigation dock.
  - Slide-over task drawer with AI subtask decomposition.
- **In-App Feedback & Bug Reporting System**:
  - Built-in feedback modal writing to Supabase `feedback` table.
  - Category tags (General, Bug Report, Feature Idea), auto-filled user metadata, and direct WhatsApp support.
- **Task Lifecycle & Timezone Stabilization**:
  - PostgreSQL PostgREST `.update()` partial payload patch fix.
  - Timezone-normalized `.toLocal()` date evaluations preserving completed today tasks.
  - Resilient local offline cache protecting against empty remote deletion sweeps.
  - Synchronized in-memory task feeds and calendar schedule display.

---

## 📲 Installation Instructions

### Android
1. Download [`Waypoint-v0.6.1.apk`](releases/Waypoint-v0.6.1.apk).
2. Allow installation from unknown sources if prompted.
3. Open the APK to install or update Waypoint.

### Windows
1. Download [`Waypoint-v0.5.1-Setup.exe`](releases/Waypoint-v0.5.1-Setup.exe).
2. Run the installer wizard.
3. Launch Waypoint from the Start Menu or desktop shortcut.
