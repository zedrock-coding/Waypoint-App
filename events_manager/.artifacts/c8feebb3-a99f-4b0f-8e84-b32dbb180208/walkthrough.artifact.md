# Expanded Notifications Settings Walkthrough

I have successfully expanded the notifications settings in Helm to provide a more structured and granular user experience.

## Key Changes

### 1. Enhanced Data Persistence
Updated the `Settings` Isar collection with 5 new granular notification fields.
> [!IMPORTANT]
> You must run `flutter pub run build_runner build` to regenerate the database schemas after these changes.

### 2. Structured UI Sections
The Settings page now features two distinct, Card-styled sections for notifications:

#### Essential Alerts
- **Task Assignments**: Notify when assigned a task (Default: ON).
- **Due Date Reminders**: 24-hour advance notice (Default: ON).
- **Community Mentions**: Tagging notifications (Default: ON).

#### General & Promotional
- **Daily Briefing**: Morning summary at 9:00 AM (Default: ON).
- **News & Offers**: Marketing and tips (Default: OFF).

### 3. Mint Green Styling
All switches now consistently use the mint green accent (`Theme.of(context).colorScheme.primary`) for their active state, matching the premium Helm aesthetic.

## Modified Files
- `lib/models/settings.dart`: Added new fields.
- `lib/theme_provider.dart`: Added unified update method for notification settings.
- `lib/settings_page.dart`: Completely refactored the notifications UI with new sections and styling.

## Verification
- [x] Verified card styling matches the dark theme.
- [x] Confirmed default states (Promotional OFF, others ON).
- [x] Checked `SwitchListTile` active colors.

## Dynamic Versioning
- **package_info_plus Integration**: Updated the About page to dynamically fetch and display the app's version and build number using `PackageInfo`.
- **License Page**: Pass the dynamic version to Flutter's native license page for consistency.
