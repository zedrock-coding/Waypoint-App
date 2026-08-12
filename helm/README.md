# Helm 2.2 - AI-Powered Team Workspace

**Helm 2.2** is a next-generation, collaborative task management system. Optimized for **Android**, **Windows**, and **Web**, Helm provides a professional, reactive experience for real-time team orchestration and personal productivity, now supercharged with Artificial Intelligence.

![Aesthetic](https://img.shields.io/badge/Aesthetic-Slate%20%26%20Mint-88C0A4)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Web-blue)
![Version](https://img.shields.io/badge/Version-2.2.0-green)

## 🚀 What's New in v2.2

### 🤖 Generative AI Commands
*   **Voice & Text Orchestration**: Create complex tasks using natural language. Powered by **Gemini 1.5 Flash**.
*   **Context-Aware Parsing**: The AI understands your communities and team members, allowing commands like *"Assign a high priority bug fix to Lakshya in Team Alpha by Friday"*.
*   **Smart Scheduling**: Automatically parses relative dates (tomorrow, next week) into precise ISO timestamps.

### 👥 Advanced Community Management
*   **Member Controls**: Admins can now promote users to Admin or remove members from workspaces.
*   **Invite Link Hub**: A dedicated management interface to generate and share `helm://invite` deep links.
*   **Role-Based Security**: Backend-enforced permissions ensuring team data is only accessible to authorized members.

### ✏️ Task Evolution
*   **Full CRUD Support**: Restored and improved task editing. Modify titles, descriptions, priorities, and categories on the fly.
*   **Instant Sync**: Every edit is automatically synchronized between your local device and the cloud via Supabase.
*   **Smart Categorization**: Tags are now part of the global sync engine, keeping your organization consistent everywhere.

### 🛡️ Core Stability & v2.1 Refinements
*   **Cross-Platform Unity**: Resolved major compilation and runtime issues across Chrome, Windows, and Android.
*   **Overflow Protection**: Fixed critical rendering issues (RenderFlex) in sidebars and task cards for a smooth responsive experience.
*   **Resilient Startup**: Optimized app initialization to prevent hangs during database migration and connectivity checks.

---

## 🛠 Tech Stack
*   **Framework**: Flutter (Material 3)
*   **AI Engine**: Google Generative AI (Gemini 1.5 Flash)
*   **Cloud Backend**: Supabase (PostgreSQL, Realtime, RLS)
*   **Primary Storage**: Hive (High-speed NoSQL for seamless Web/Desktop/Mobile support)
*   **Deep Linking**: app_links (Cross-platform invite routing)

---

## ⚙️ Installation & Setup

### Prerequisites
*   **Flutter SDK**: ^3.38.4
*   **Android**: JDK 17 (LTS) and SDK 36.
*   **Windows**: Visual Studio 2022.

### Steps
1.  **Clone the Repo**:
    ```bash
    git clone https://github.com/your-repo/helm.git
    cd helm
    ```
2.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Environment Setup**:
    Create a `.env` file in the root directory and add your Gemini API key:
    ```text
    GEMINI_API_KEY=your_key_here
    ```
4.  **Run the App**:
    ```bash
    flutter run
    ```

---

## 🔐 Security Note
Helm 2.2 utilizes an isolated `internal` schema in Supabase for private logic, significantly hardening the database against unauthorized access while simplifying client-side membership checks.
