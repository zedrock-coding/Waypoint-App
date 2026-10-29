# Waypoint 0.4.0 - Public Release 🚀

**Waypoint 0.4.0** is an AI-orchestrated task management workspace. Evolved from Helm into a comprehensive, AI-powered team orchestration system. Optimized for **Android**, **Windows**, and **Web**, Waypoint provides a professional, reactive experience for real-time team collaboration and personal productivity.

![Aesthetic](https://img.shields.io/badge/Aesthetic-Slate%20%26%20Mint-88C0A4)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Web-blue)
![Version](https://img.shields.io/badge/Version-0.4.0-green)

## 🌟 Major Highlights for the Public Launch

### 🤖 Generative AI Command Center
*   **Voice & Text Orchestration**: Create complex tasks using natural language. Powered by **Gemini 3.5 Flash lite**.
*   **Context-Aware Parsing**: The AI understands your communities and team members, allowing commands like *"Assign a high priority bug fix to Shivam by Friday"*.

### 📅 Interactive Task Calendar
*   **Monthly Timeline**: Visualize your deadlines with a dedicated monthly calendar view.
*   **Subtle Status Badges**: Quickly identify days with pending or urgent tasks.
*   **Date-Based Filtering**: Tap any day to see exactly what's due, or view all tasks with a single click.

### 💬 Community Discussion & 2-Comment Limit
*   **Task-Specific Chat**: Discuss details directly on the task card.
*   **Smart Discussion Reset**: Encourages action over endless chatter. Users have a 2-comment limit that resets automatically whenever the task is updated (status, title, or subtasks).

### 🛡️ Weighted Role-Based Access (RBAC)
*   **Hierarchy of Authority**: Introduced **Owner**, **Admin**, and **Member** roles.
*   **Security Lockdown**: Tasks created by high-authority roles (Owners/Admins) are read-only for standard members to maintain project integrity.

### 🖼️ Profile & Identity
*   **Global Avatars**: Fully functional profile picture system with auto-compression and Supabase storage.
*   **Initial Fallbacks**: WhatsApp-style colored avatars for users who haven't uploaded a photo yet.

---

## 🛠 Tech Stack
*   **Framework**: Flutter (Material 3)
*   **AI Engine**: Supabase Edge Function proxying Gemini 3.5 Flash lite (the API key never reaches the client)
*   **Cloud Backend**: Supabase (PostgreSQL, Realtime, RLS, Storage)
*   **Local Storage**: Hive (Reactive high-speed NoSQL)
*   **State Management**: Provider

---

## ⚙️ Quick Start

### Prerequisites
*   **Flutter SDK**: ^3.41 (Dart ^3.11)
*   **Supabase project**: the app signs in and syncs against it.
*   **Gemini API key**: only for deploying the `ai` Edge Function, as a function secret.

### Steps
1.  **Clone & Install**:
    ```bash
    git clone https://github.com/zedrock-coding/Helm.git
    cd helm
    flutter pub get
    ```
2.  **Public configuration**:
    Edit `helm/web/config.js` and set the Supabase URL and the **publishable**
    (`sb_publishable_…`) key. Both are public by design; RLS is what protects
    the data.
3.  **AI backend (optional but needed for AI features)**:
    ```bash
    supabase functions deploy ai
    supabase secrets set GEMINI_API_KEY=your_key_here
    ```
    The key is read from the function environment only — never commit it, and
    never add it to a Flutter asset.
4.  **Launch**:
    ```bash
    flutter run -d chrome
    ```

---

## 🔐 Security & Integrity
Helm 0.3.3 utilizes PostgreSQL Security Definer functions and strict Row Level Security (RLS) to ensure your team's data is isolated and protected against unauthorized access.

---

## 📄 License

Helm is **source-available, not open source**.

- **Source code**: proprietary, all rights reserved. No copying, modification or
  redistribution without written permission.
- **Compiled builds**: free to download, install and use — personal or
  commercial — and free to redistribute unmodified. They may not be sold, and
  modified builds may not be redistributed.

See [`LICENSE`](LICENSE) for the full terms. Third-party packages keep their own
licenses.
