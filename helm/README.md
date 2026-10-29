# Waypoint 0.4.0 - Public Release 🚀

**Waypoint 0.4.0** is an AI-orchestrated task management workspace. Evolved from Helm into a comprehensive, AI-powered team orchestration system. Optimized for **Android**, **Windows**, and **Web**, Waypoint provides a professional, reactive experience for real-time team collaboration and personal productivity.

![Aesthetic](https://img.shields.io/badge/Aesthetic-Slate%20%26%20Mint-88C0A4)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Web-blue)
![Version](https://img.shields.io/badge/Version-0.4.0-green)

## 🌟 Major Highlights

### 🛠 Integrated Support & Feedback
*   **Direct Submission**: Users can now submit suggestions, bug reports, or help requests directly from the app's sidebar.
*   **Themed Submission Portal**: A standalone, beautifully designed feedback form hosted on the web.
*   **WhatsApp Priority Support**: One-tap access to chat for urgent workspace issues.

### 🤖 Generative AI Command Center
*   **Voice & Text Orchestration**: Create complex tasks using natural language. Powered by **Gemini** (`gemini-3.5-flash-lite`) through a server-side proxy.
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
*   **AI Engine**: Google Gemini (`gemini-3.5-flash-lite`), called through the `ai` Supabase Edge Function
*   **Cloud Backend**: Supabase (PostgreSQL, Realtime, RLS, Storage)
*   **Local Storage**: Hive (Reactive high-speed NoSQL)
*   **State Management**: Provider

---

## ⚙️ Quick Start

### Prerequisites
*   **Flutter SDK**: ^3.38.4

### Steps
1.  **Clone & Install**:
    ```bash
    git clone https://github.com/your-repo/helm.git
    cd helm
    flutter pub get
    ```
2.  **Environment Setup**:
    Copy `.env.example` to `.env` and fill in the **public** Supabase values
    (the publishable/anon key is safe to ship; RLS is what protects the data):
    ```bash
    cp .env.example .env
    ```
    No Gemini key belongs in this file. AI commands are proxied through the
    `ai` Edge Function, which holds `GEMINI_API_KEY` as a server secret:
    ```bash
    supabase secrets set GEMINI_API_KEY=... --project-ref <ref>
    supabase functions deploy ai --project-ref <ref>
    ```
3.  **Launch**:
    ```bash
    flutter run --dart-define-from-file=.env
    ```
    For local AI development without deploying, run the function locally:
    ```bash
    supabase functions serve ai --env-file supabase/functions/.env.local
    ```

---

## 🔐 Security & Integrity
Helm 3.0 utilizes PostgreSQL Security Definer functions and strict Row Level Security (RLS) to ensure your team's data is isolated and protected against unauthorized access.
