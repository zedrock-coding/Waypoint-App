# Helm - Team Event & Task Management

**Helm** is a high-performance, team-oriented task management system optimized for **Android**, **Windows**, and **Linux**. Built with Flutter and the Isar Database, Helm provides a premium, reactive experience for tracking team progress and personal productivity.

![Aesthetic](https://img.shields.io/badge/Aesthetic-Slate%20%26%20Mint-88C0A4)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Linux-blue)

## 🚀 Key Features

### 📊 Optimized Velocity Dashboard
*   **Master-Detail Desktop Layout**: A professional workspace for large screens with a sliding task detail panel.
*   **Actionable Snapshots**: A responsive dual-card layout at the top of your dashboard.
*   **Performance Tuning**: High-speed list rendering using in-memory grouping and optimized Isar queries.
*   **Responsive Visibility**: Intelligent UI that hides "Quick Settings" on narrow mobile screens (<900px) to maximize task visibility.
*   **Progress Gauges**: Compact Circular and Linear indicators showing real-time completion percentages.
*   **Quick Controls**: Unified state-management for managing Reminders and global Font Size directly from the dashboard.

### 📝 Intelligent Task Management
*   **Drag & Drop Reordering**: Intuitively prioritize your tasks using a reorderable list with custom drag handles.
*   **Wobble Animation**: Visual feedback during drag-and-drop with a playful oscillation effect.
*   **Hero Transitions**: Smooth, high-fidelity animations when navigating between the list and task details.
*   **Nested Sub-Tasks**: Create hierarchical task trees with visual connectors.

### 🤖 Multi-Modal AI Assistant
*   **Hands-Free Voice UI**: Modern pulsing microphone animation with real-time state feedback and smart transitions.
*   **AI Text Chat**: A sliding end-drawer fallback for text-based task commands and assistant interactions.
*   **Adaptive Trigger**: Seamlessly switches between BottomSheet (Mobile) and Dialog/Drawer (Desktop).

### 🔍 Global Search & Filtering
*   **Deep Indexing**: Instantly find tasks by title or description using optimized database queries.
*   **Custom Search UI**: A bespoke, themed search experience with mint-green accents and interactive community filters.
*   **Recent Searches**: Quickly access common search terms and filter by communities via interactive chips.

### 🔔 Performance-Optimized Notifications
*   **Activity Feed**: A dedicated notification center for overdue tasks, assignments, and invites.
*   **Windows Lag-Fix**: Custom state-based overlay system that eliminates UI jank on desktop platforms.
*   **Granular Settings**: Dedicated controls for Task Alerts, Daily Briefings, and Promotional updates.

### 🎨 Premium UI/UX & Onboarding
*   **Slate & Mint Aesthetic**: A modern, deep-slate charcoal background with vibrant mint-green accents.
*   **Interactive Onboarding**: A beautiful 3-page swipeable introduction for new users.
*   **Account Management**: A dedicated Account Settings screen for profile and security management.
*   **Safe Area Optimized**: Guaranteed UI stability on devices with notches or system bars.
*   **Haptic Micro-Interactions**: Tactile feedback on toggles, button presses, and drag-and-drop actions.

### 🏗 Architecture & Collaboration
*   **Supabase Backend**: Integrated PostgreSQL database with Row Level Security (RLS) for secure, scalable data management.
*   **Community Invite System**: Seamless joining experience via deep links (`helm://invite`) with intelligent auth-state guarding.
*   **Repository Pattern**: Clean separation of concerns using `EventRepository`, `CategoryRepository`, and `SupabaseService`.
*   **Centralized State**: Unified state management via `Provider` and a robust `ThemeProvider`.
*   **Communities Tree**: Hierarchical organization using `ExpansionTile` for professional project mapping.
*   **Advanced Undo System**: Robust restoration with deep-copy logic ensuring all categories and assignees are perfectly preserved.

## 🛠 Tech Stack
*   **Framework**: Flutter (Material 3)
*   **Backend**: Supabase (PostgreSQL, Auth, RLS)
*   **Database**: Isar (High-performance Local NoSQL)
*   **Deep Linking**: app_links
*   **State Management**: Provider (Centralized Theme & Settings)
*   **Local Storage**: path_provider
*   **Notifications**: flutter_local_notifications (Timezone-aware)
*   **Versioning**: package_info_plus (Dynamic version tracking)
*   **Localization/Formatting**: intl

## ⚙️ Installation & Setup

### Prerequisites
*   **Flutter SDK**: ^3.11.0
*   **Windows Build Tools**: Visual Studio 2022 with "Desktop development with C++" workload.
*   **Linux Build Tools**: `clang`, `cmake`, `pkg-config`, `ninja-build`, and GTK development headers.

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
3.  **Generate Database Schemas**:
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```
4.  **Run the App**:
    ```bash
    flutter run
    ```

---

## 🔐 Generating a Signed APK for Android
See the official [Flutter documentation](https://docs.flutter.dev/deployment/android) for details on setting up keystores and release properties.
