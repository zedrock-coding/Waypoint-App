# Changelog - Helm Workspace 🚀

All notable changes to the **Helm** project will be documented in this file.

---

## [0.3.3] - Navigation Hotfix

### 🐛 Fixed
- **Communities Navigation**: Clicking the "Communities" tab on the bottom navigation or sidebar now properly resets the active route and guarantees a return to the main dashboard/directory view, escaping deep-linked community context.

---

## [0.3.2] - Current Release

### 🚀 Added
- **Strict Client-Side RBAC Locking**: Non-editable tasks created by higher-ranking members (Admins/Owners) now display a "Read-Only" banner and lock all input fields.
- **Offline Data Sync Engine**: Built-in `sync_queue` powered by Hive and `connectivity_plus` for last-write-wins synchronization upon network reconnect.
- **Improved AI Parsing**: Enforced strict prompt rules on `gemini-3.5-flash-lite` for accurate 5-7 word title summaries and relative date calculations.
- **Automated Assignment Notifications**: Integrated a Postgres trigger to alert users immediately when assigned to a task.

### 🐛 Fixed
- **Navigation Sync**: Fixed a state mismatch between the sidebar items and the bottom navigation bar.
- **Calendar Filtering**: Fixed date comparison logic to use local normalized timestamps, resolving misplaced task dots.
- **Comment Deduplication**: Prevented duplicate comment renders and resolved premature 2-comment limit locks.
- **Layout Overflows**: Resolved `RenderFlex` errors in the task detail panel and task item cards.

---

## [0.3.1] - Support & Feedback Update

### 🚀 Added
- **Support & Feedback Portal**: In-app web modal and external portal (`feedback.html`) integrated with Supabase.
- **Global Keyboard Shortcuts**: Added `Ctrl+N` (New Task), `Ctrl+F` (Search), `Ctrl+Space` (Voice AI), `Ctrl+Tab` (Switch Tabs), and `Esc` (Close Panel).
- **Vercel Web Deployment**: Integrated GitHub Actions CI/CD workflow for automated web builds.

---

## [0.3.0] - Public Launch Milestone

### 🚀 Added
- **Interactive Calendar View**: Monthly timeline with due-date markers and daily task filtering.
- **Task Comments & 2-Comment Limit**: Discussion threads with an automatic reset trigger when task details or status change.
- **Profile Picture System**: Integrated `image_picker`, client-side image compression, and Supabase Storage avatars.
- **WhatsApp-Style Initials**: Automatic fallback avatars displaying user initials.
- **Subtask Management**: Dynamic creation and interactive checklist for subtasks.

---

## [0.2.2] - AI & Customization Update

### 🚀 Added
- **Generative AI Integration**: Natural language task creation via `gemini-3.5-flash-lite`.
- **Command Bar Widget**: Text and voice input bar with real-time listening animation.
- **Real-time Notifications**: In-app bell with unread badges and live updates via Supabase Realtime streams.

---

## [0.2.1] - Community & Deep Linking

### 🚀 Added
- **Community Workspaces**: Shared team spaces with role management (Owner, Admin, Member).
- **Deep Linking**: Added `helm://invite` link handler for seamless team onboarding.
- **Full Task CRUD**: Complete editing, status toggling, and deletion with "Undo" support.

---

## [0.1.0] - Foundation

### 🚀 Added
- **Local Storage Engine**: Core Hive NoSQL setup with Offline-first architecture.
- **Material 3 Design**: Dark Slate (`#1E2124`) & Mint Green (`#88C0A4`) design system.
- **Velocity Dashboard**: Daily goal progress tracking and completion streaks.
