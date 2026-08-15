# Helm Technical Documentation 🚀

Welcome to the **Helm** technical architecture guide. This document provides a comprehensive overview of how the application is built, its data pipelines, and its core logic. 

---

## 🏗 High-Level Architecture
Helm is a cross-platform (Android, Windows, Web) task management application built using:
- **Framework**: Flutter (Material 3)
- **State Management**: `Provider` + `ChangeNotifier`
- **Primary Storage**: Hive (NoSQL) for high-performance offline access.
- **Backend-as-a-Service**: Supabase (Postgres, Auth, Storage, Realtime).
- **AI Engine**: Google Gemini 1.5 Flash (via `google_generative_ai`).

---

## 🚦 Navigation & Routing
The navigation system is managed by the `NavigationProvider`.

### 1. The `AppShell` Pattern
Most pages are wrapped in an `AppShell` widget. This provides:
- A responsive sidebar (Desktop) or Drawer (Mobile).
- A unified header with Search, AI Chat, and Profile controls.
- Centralized keyboard shortcut listeners.

### 2. State-Driven Tabs
Helm uses a dual-tab system: **Personal** (0) and **Communities** (1).
- Switching tabs updates the `selectedIndex` in `NavigationProvider`.
- Selecting a community via the sidebar automatically switches to the Communities tab and filters tasks.

---

## 📡 Data Pipeline: Adding a Task
When a user adds a task, it follows a "Local-First" synchronization strategy.

### Step-by-Step Flow:
1.  **UI Interaction**: The user submits the form in `AddEventPage`.
2.  **Provider Activation**: `TaskProvider.addTask()` is called.
3.  **Local Persistence (Immediate)**:
    - A new UUID is generated.
    - The task is saved to the **Hive** `tasks` box.
    - UI updates instantly via `notifyListeners()`.
4.  **Cloud Sync (Asynchronous)**:
    - If the user is logged in, a copy is pushed to **Supabase** (`tasks` table).
    - If the task belongs to a community, it becomes visible to all members via Supabase Realtime.
5.  **Postgres Triggers**:
    - **Notifications**: If an `assignee_id` is present, a Postgres trigger automatically inserts a record into the `notifications` table.

---

## 🔐 Security: Role-Based Access Control (RBAC)
Helm implements a strict hierarchy within Communities: **Owner (3) > Admin (2) > Member (1)**.

### 1. Backend Enforcement (Supabase RLS)
We use Row Level Security policies with weighted roles:
- **`user_can_edit_task` function**: Checks if the current user's role weight is $\ge$ the creator's role weight.
- **Update Policy**: Prevents standard members from editing tasks created by admins or the owner.

### 2. Frontend Enforcement
The `TaskDetailContent` (StatefulWidget) evaluates permissions on initialization:
- It fetches the community member list.
- Compares your role weight against the task creator's.
- If unauthorized, it wraps the entire UI in an `AbsorbPointer` and displays a "Read-Only" banner.

---

## 🤖 AI Integration Pipeline
The **Command Bar** and **AI Chat Drawer** use a multi-modal data extraction pipeline.

1.  **Input**: Text typed or Voice transcribed via `speech_to_text`.
2.  **Context Injection**: The `AiService` is fed a JSON list of all available **Communities** and **Members**.
3.  **Gemini Parsing**:
    - The model extracts: `title`, `priority`, `due_date`, `community_id`, and `assignee_id`.
    - It is forced to output valid JSON via `responseMimeType: 'application/json'`.
4.  **Action**: The resulting JSON is passed to `TaskProvider.addTask()`, completing the loop.

---

## 📅 Calendar & Commenting
- **Calendar**: Uses `table_calendar`. It pulls all Hive tasks with a non-null `dueAt` field. Tapping a date filters the local task list using `isSameDay` logic.
- **Comments**:
    - Stored in `task_comments` table.
    - **2-Comment Limit**: Calculated by counting the user's comments where `created_at` $\ge$ `task.updated_at`.
    - **Reset**: Any update to the task title, status, or subtasks triggers a DB update to `updated_at`, which instantly resets the available comment slots for all users.

---

## 📁 File Structure Reference
- `lib/models/`: Data definitions (Hive and Unified types).
- `lib/providers/`: Core business logic and state sync.
- `lib/services/`: Direct API wrappers (Supabase, AI, Notifications).
- `lib/widgets/`: Reusable UI components (Avatars, Cards, Dashboards).
- `android/`, `windows/`, `web/`: Platform-specific native configurations.
