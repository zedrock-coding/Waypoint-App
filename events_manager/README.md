# Helm - Team Event & Task Management

**Helm** is a high-performance, team-oriented task management system optimized for **Android**, **Windows**, and **Linux**. Built with Flutter and the Isar Database, Helm provides a premium, reactive experience for tracking team progress and personal productivity.

![Aesthetic](https://img.shields.io/badge/Aesthetic-Slate%20%26%20Mint-88C0A4)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Linux-blue)

## 🚀 Key Features

### 📊 Team Velocity Dashboard
*   **Actionable Snapshots**: A 60/40 dual-card layout at the top of your dashboard.
*   **Progress Gauges**: Thick Circular and Linear indicators showing real-time completion percentages.
*   **Streak Tracking**: Gamified consistency tracking with a "Streak" flame indicator.
*   **Interactive Goals**: Adjust daily task targets directly from the dashboard via a sleek edit dialog.
*   **Quick Controls**: Manage Daily Reminders and global Font Size directly from the dashboard.

### 🤖 Hands-Free AI Voice UI
*   **Listening Overlay**: Modern pulsing microphone animation with real-time state feedback.
*   **Smart Transitions**: Automatically shifts from listening to processing and success states with auto-dismissal.
*   **Adaptive Trigger**: Slides up as a BottomSheet on mobile or appears as a centered floating dialog on desktop.

### 🎨 Premium UI/UX
*   **Slate & Mint Aesthetic**: A modern, deep-slate charcoal background with vibrant mint-green accents.
*   **Semantic Priority Colors**: Task cards subtly shift color based on priority (Warm red tint for High, Calm blue-grey for Low).
*   **Material 3 Ready**: Full use of M3 components, including Segmented Buttons and elevated surface depths.
*   **Haptic Micro-Interactions**: Subtle tactile feedback on every toggle, button press, and swipe.
*   **Context-Aware Themes**: Seamlessly switches between a crisp White Light Mode and a deep Slate Dark Mode.

### 🛠 Robust Core Functionality & Collaboration
*   **Communities Tree**: Hierarchical "Communities" section using `ExpansionTile` for professional project organization.
*   **Role-Based Access**: Level 1 (Admin) and Level 2 (User) roles with strictly gated UI controls for task assignments.
*   **Community Gating**: Securely filter assignee lists based on the active community context.
*   **Nested Sub-Tasks**: Create hierarchical task trees with "L-shaped" visual connectors.
*   **Advanced Undo System**: Robust restoration with deep-copy logic ensuring all categories and assignees are perfectly preserved.
*   **Intelligent Input**: Add assignees rapidly using commas or the Enter key.
*   **Secure Invitations**: Generate and copy community invite links directly from the Settings page.

### 📱 Fully Responsive
*   **Adaptive Sidebar**: A persistent navigation sidebar on Desktop (>800px) that transforms into a sleek drawer on Mobile.
*   **Desktop Pro**: Optimized task forms open in constrained floating windows for better screen utilization.
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
*   **Linux Build Tools**: `clang`, `cmake`, `pkg-config`, `ninja-build`, and GTK development headers (`libgtk-3-dev` on Debian/Ubuntu).
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
    
    # For Linux
    flutter run -d linux
    ```

---

## 🔐 Generating a Signed APK for Android

To prepare **Helm** for the Google Play Store or private distribution, follow these steps:

### 1. Create a Keystore
Run the following command in your terminal to generate a secure upload key:
```bash
keytool -genkey -v -keystore helm-release.keystore -alias helm -keyalg RSA -keysize 2048 -validity 10000
```
*Keep your password and the `.keystore` file safe!*

### 2. Configure Gradle
Create a file named `android/key.properties` and add your credentials (replacing `your_password` with the actual passwords you chose):
```properties
storePassword=your_password
keyPassword=your_password
keyAlias=helm
storeFile=../helm-release.keystore
```

### 3. Build the Release
Execute the following command to generate the signed APK:
```bash
flutter build apk --release
```
The final file will be located at: `build/app/outputs/flutter-apk/app-release.apk`
