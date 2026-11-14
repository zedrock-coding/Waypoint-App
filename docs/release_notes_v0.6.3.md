# Waypoint v0.6.3 — Workspaces, Role Management & Adaptive Theme Release 🧭

[![Version](https://img.shields.io/badge/version-0.6.3--build.26-88C0A4?style=for-the-badge&labelColor=111417)](https://github.com/zedrock-coding/Waypoint-App/releases/tag/v0.6.3)
[![Engine](https://img.shields.io/badge/Flutter-3.x_Material_3-111417?style=for-the-badge&logo=flutter&logoColor=88C0A4)](https://flutter.dev)
[![Backend](https://img.shields.io/badge/Supabase-Auth_%26_Postgres_RLS-111417?style=for-the-badge&logo=supabase&logoColor=88C0A4)](https://supabase.com)
[![Offline](https://img.shields.io/badge/Storage-Hive_NoSQL_Local--First-111417?style=for-the-badge&logo=hive&logoColor=88C0A4)](https://pub.dev/packages/hive)
[![AI Orchestrator](https://img.shields.io/badge/Orchestrator-gemini--3.5--flash--lite-111417?style=for-the-badge&logo=google&logoColor=88C0A4)](https://ai.google.dev)

> **Waypoint v0.6.3** brings workspace title headers, team member & role management for administrators, persistent recurring cadence task visibility, and a fully functional theme-adaptive light mode.

---

## 📦 Release Artifacts & Targets

| Platform | Distribution Target | Details / File | Status |
|---|---|---|---|
| **Web** | Progressive Web App (PWA) | Production bundle (`build/web`) | `Verified (--pwa-strategy=none)` |
| **Android** | `app-release.apk` | `build/app/outputs/flutter-apk/app-release.apk` | `Ready for Build` |
| **Windows Desktop** | `waypoint.exe` (x64 Release) | `build/windows/x64/runner/Release/waypoint.exe` | `Ready for Build` |

---

## 🌟 Key Engineering Enhancements & Fixes

### 1. 🏢 Workspaces & Groups Header Context
* **Top Header Active Workspace Badge**:
  * Displays active workspace name and hub icon in the top header on both desktop and mobile when entering a workspace.
  * Added one-click "Exit Workspace" action returning user directly to their personal worklist.
  * Added prominent "Members & Roles" action button next to workspace title.
* **Workspace List & Overview Direct Actions**:
  * Added instant "View Members & Roles" buttons directly on workspace tiles in `CommunitiesOverviewView` and the desktop sidebar.

### 2. 👥 Team Directory & Role Management
* **Obsidian Precision Manage Screen**:
  * Redesigned `CommunityManagePage` with Obsidian Precision tokens (`AppTheme.bg(context)`, surface cards, 4px radii, JetBrains Mono tags).
  * Prominent role badges: `OWNER` (Mint), `ADMIN` (Amber), `MEMBER` (Blue-grey).
* **Interactive Role Modification & Removal**:
  * Integrated dialog allowing Admins and Owners to promote members to Admin or demote to Member following RBAC hierarchy.
  * Added member removal confirmation dialog.
  * Streamlined invite link generator with one-tap copy and share functionality.

### 3. 🔄 Recurring Routines Engine & Worklist Visibility
* **Cadence Engine Metadata Expansion**:
  * Recurrence engine automatically detects recurring tasks via metadata, flags, and natural language cadence keywords (`daily`, `every day`, `weekly`, `routine`).
  * Recurring routines remain visible in Today's focus and Recurring views regardless of whether they have been completed today or roll over to a future date.
  * Synchronized "Recurring" filter chip count with all configured recurring schedules.

### 4. ☀️ Dynamic Light & Dark Mode System
* **Theme-Adaptive Color Engine**:
  * Converted hardcoded color constants across components to context-aware tokens (`AppTheme.bg(context)`, `AppTheme.surface(context)`, `AppTheme.borderColor(context)`, `AppTheme.text(context)`, `AppTheme.textMuted(context)`).
  * Formatted `lightTheme` with crisp Obsidian Light styling: pure white cards, soft slate containers, and charcoal text.
  * Instant, flicker-free switching between Obsidian Dark and Clean Light modes.

---

## 🔒 Security & Verification Gate

* **Analyzer**: `flutter analyze --fatal-infos` passed with 0 warnings and 0 errors.
* **Unit & Widget Tests**: All 186 automated test suites passed (`186 passed`).
* **Secret Scanning**: Scanned via Gitleaks with 0 secrets detected.
