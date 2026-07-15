# Helm - Team Event & Task Management

**Helm** is a high-performance, team-oriented task management system optimized for **Android** and **Windows**. Built with Flutter and the Isar Database, Helm provides a premium, reactive experience for tracking team progress and personal productivity.

![Aesthetic](https://img.shields.io/badge/Aesthetic-Slate%20%26%20Mint-88C0A4)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows-blue)

## 🚀 Key Features

### 📊 Team Velocity Dashboard
*   **Actionable Snapshots**: A 60/40 dual-card layout at the top of your dashboard.
*   **Progress Gauges**: Thick Circular and Linear indicators showing real-time completion percentages.
*   **Streak Tracking**: Gamified consistency tracking with a "Streak" flame indicator.
*   **Quick Controls**: Manage Daily Reminders and global Font Size directly from the dashboard.

### 🎨 Premium UI/UX
*   **Slate & Mint Aesthetic**: A modern, deep-slate charcoal background with vibrant mint-green accents.
*   **Material 3 Ready**: Full use of M3 components, including Segmented Buttons and elevated surface depths.
*   **Haptic Micro-Interactions**: Subtle tactile feedback on every toggle, button press, and swipe.
*   **Context-Aware Themes**: Seamlessly switches between a crisp White Light Mode and a deep Slate Dark Mode.

### 🛠 Robust Core Functionality
*   **Team Schema**: Support for Status (To-Do, In Progress, Done), Priority (Low, Medium, High), and multiple Assignees per task.
*   **Nested Sub-Tasks**: Create hierarchical task trees with "L-shaped" visual connectors.
*   **Deep Undo System**: Accidents happen. Swipe to delete and instantly restore tasks with all categories and assignees intact.
*   **Daily Reminders**: Timezone-aware notification service for morning briefings (9:00 AM).

### 📱 Fully Responsive
*   **Adaptive Sidebar**: A persistent navigation sidebar on Desktop (>900px) that transforms into a sleek drawer on Mobile.
*   **Zero-Overflow Layouts**: Uses `LayoutBuilder` to intelligently stack dashboard components vertically on narrow screens.

## 🛠 Tech Stack
*   **Framework**: Flutter (Material 3)
*   **Database**: Isar (High-performance NoSQL)
*   **State Management**: Provider (Centralized Theme & Settings)
*   **Local Storage**: path_provider
*   **Notifications**: flutter_local_notifications (Timezone-aware)

## ⚙️ Installation & Setup

### Prerequisites
*   **Flutter SDK**: ^3.0.0
*   **Windows Build Tools**: Visual Studio 2022 with "Desktop development with C++" workload.
*   **Important (Windows Notifications)**: Ensure "**C++ ATL for latest v143 build tools**" is installed via the Visual Studio Installer to enable the reminder system.

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
    # For Windows
    flutter run -d windows
    
    # For Android
    flutter run -d android
    ```

## ✅ Project Status
Helm is currently feature-complete for its initial release, featuring a stabilized context-aware architecture and full native build support for Android and Windows.
