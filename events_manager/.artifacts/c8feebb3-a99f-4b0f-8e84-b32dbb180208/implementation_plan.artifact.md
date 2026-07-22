# Expanded Notifications Settings Implementation Plan

This plan outlines the steps to expand the notification settings in the Helm app, providing users with more granular control over their alerts.

## Proposed Changes

### 1. Data Model Updates
- **[Modify] [settings.dart](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/lib/models/settings.dart)**: Add new boolean fields for:
    - `taskAssignmentsEnabled` (Default: `true`)
    - `dueDateRemindersEnabled` (Default: `true`)
    - `communityMentionsEnabled` (Default: `true`)
    - `dailyBriefingEnabled` (Default: `true` - replaces `remindersEnabled`)
    - `newsAndOffersEnabled` (Default: `false`)

### 2. State Management Updates
- **[Modify] [theme_provider.dart](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/lib/theme_provider.dart)**: Add toggle methods for each new notification setting.

### 3. UI Implementation
- **[Modify] [settings_page.dart](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/lib/settings_page.dart)**:
    - Replace the existing "Daily Reminders" toggle.
    - Implement two new sections: "Essential Alerts" and "General & Promotional".
    - Use `Card` containers with consistent styling for each section.
    - Ensure `SwitchListTile` widgets follow the specified defaults and styling.

## Verification Plan

### Automated Tests
- I'll verify the code compiles (mentally and via `analyze_file`).
- *Note*: The user will need to run `flutter pub run build_runner build` to regenerate the Isar schemas.

### Manual Verification
- Verify the new sections appear in the Settings page.
- Ensure toggles persist correctly in the database (via `ThemeProvider`).
- Check UI consistency with the dark theme.
