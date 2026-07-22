# Helm - Team Event & Task Management

**Helm** is a high-performance, team-oriented task management system optimized for **Android**, **Windows**, and **Linux**. Built with Flutter and the Isar Database, Helm provides a premium, reactive experience for tracking team progress and personal productivity.

![Aesthetic](https://img.shields.io/badge/Aesthetic-Slate%20%26%20Mint-88C0A4)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Linux-blue)

## 🚀 Key Features

### 📊 Optimized Velocity Dashboard
*   **Actionable Snapshots**: A responsive 60/40 dual-card layout at the top of your dashboard.
*   **Performance Tuning**: High-speed list rendering using in-memory grouping and optimized Isar queries.
*   **Responsive Visibility**: Intelligent UI that hides "Quick Settings" on narrow mobile screens (<900px) to maximize task visibility.
*   **Progress Gauges**: Compact Circular and Linear indicators showing real-time completion percentages.
*   **Quick Controls**: Unified state-management for managing Reminders and global Font Size directly from the dashboard.

### 🔔 Granular Notification Settings
*   **Essential Alerts**: Dedicated controls for Task Assignments, Due Date Reminders (24h lead), and Community Mentions.
*   **General & Promotional**: Opt-in/out of Daily Briefings and News & Offers separately.
*   **Mint-Green Styling**: Clean, Material 3 toggles that adhere to the app's premium aesthetic.

### 🤖 Hands-Free AI Voice UI
*   **Listening Overlay**: Modern pulsing microphone animation with real-time state feedback.
*   **Smart Transitions**: Automatically shifts from listening to processing and success states with auto-dismissal.
*   **Adaptive Trigger**: Slides up as a BottomSheet on mobile or appears as a centered floating dialog on desktop.

### 🎨 Premium UI/UX
*   **Slate & Mint Aesthetic**: A modern, deep-slate charcoal background with vibrant mint-green accents.
*   **Semantic Priority Colors**: Task cards subtly shift color based on priority (Warm red tint for High, Calm blue-grey for Low).
*   **Safe Area Optimized**: Guaranteed UI stability on devices with notches or system bars.
*   **Haptic Micro-Interactions**: Subtle tactile feedback on every toggle, button press, and swipe.
*   **Context-Aware Themes**: Seamlessly switches between a crisp White Light Mode and a deep Slate Dark Mode.

### 🏗 Architecture & Collaboration
*   **Repository Pattern**: Clean separation of concerns using `EventRepository` and `CategoryRepository`.
*   **Centralized State**: Unified state management via `Provider` and a robust `ThemeProvider`.
*   **Communities Tree**: Hierarchical organization using `ExpansionTile` for professional project mapping.
*   **Nested Sub-Tasks**: Create hierarchical task trees with "L-shaped" visual connectors.
*   **Advanced Undo System**: Robust restoration with deep-copy logic ensuring all categories and assignees are perfectly preserved.

## 🛠 Tech Stack
*   **Framework**: Flutter (Material 3)
*   **Database**: Isar (High-performance NoSQL)
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
