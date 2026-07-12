# Helm - Event & Task Manager

Helm is a lightweight, high-performance task and event management system built with Flutter and the Isar Database. Designed for both mobile and desktop use, it features a robust team management structure and deep UI customization.

## 🚀 Key Features

### 1. Team & Project Management
*   **Status Tracking:** Manage lifecycle with `To Do`, `In Progress`, and `Done` states.
*   **Priority Levels:** Visual indicators for `High`, `Medium`, and `Low` importance.
*   **Assignee System:** Add multiple team members to any task using a dynamic chip-input system.
*   **Sub-tasks:** Hierarchical support with self-referential parent-child relationships.
*   **Visual Hierarchy:** Subtle 'L-shaped' tree lines visually connect parent tasks to their child sub-tasks in the editor.

### 2. Advanced Organization
*   **Unlimited Categories:** Categorize tasks without limits using a flexible linking system.
*   **Optimized Sorting:** Mandatory category-based sorting that queries the database per-category for maximum memory efficiency.
*   **Collapsible Sections:** A clean dashboard UI using `ExpansionTiles` to group tasks by category.
*   **Category Filtering:** A dedicated dropdown menu to focus on specific project areas instantly.

### 3. Deep UI Customization
*   **Global Font Scaling:** A 5-point selection system (Very Small to Large) that scales the entire UI proportionally using `MediaQuery`.
*   **Theme Engine:** 
    *   Native Light and Dark modes.
    *   **Custom JSON Themes:** Upload your own color schemes.
    *   **Seed Color System:** Dynamically generate entire palettes from a single base color.

### 4. Interactive UX
*   **Swipe Gestures:**
    *   **Swipe Right:** Instantly mark a task as "Done".
    *   **Swipe Left:** Quick delete with a safety confirmation pop-up.
*   **Undo System:** Accidental deletions can be reversed with a single tap, restoring all data including category links.
*   **Responsive Desktop Shell:** A persistent sidebar designed specifically for wide-screen productivity.
*   **Status Animations:** Micro-animations for status toggles using `AnimatedSwitcher` for satisfying visual feedback.
*   **Keyboard Shortcuts:** Full desktop productivity with `Escape` to close and `Enter` to save (smart-disabled in multiline fields).
*   **Data Protection:** Built-in "Unsaved Changes" warning prevents accidental data loss when exiting the editor.

## 🛠 Technical Stack
*   **Framework:** Flutter (Material 3)
*   **Database:** Isar (NoSQL)
*   **State Management:** Reactive Streams (Broadcast)
*   **Architecture:** App Shell pattern for unified navigation.

## 🏗 Setup & Installation
1.  Ensure you have Flutter installed.
2.  Run `flutter pub get` to install dependencies.
3.  Generate the database schema:
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```
4.  Launch the app: `flutter run`

## 🎨 Custom Theme Example
Users can modify the look of Helm by uploading a JSON file with the following structure:
```json
{
  "seedColor": "0xFFE91E63",
  "brightness": "dark",
  "backgroundColor": "0xFF1A1A1A",
  "comment": "Colors must be in 0xAARRGGBB format"
}
```
