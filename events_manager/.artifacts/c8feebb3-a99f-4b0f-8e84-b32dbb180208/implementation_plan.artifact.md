# Community Invite System Implementation Plan

This plan outlines the steps to implement a deep-link-based community invite system for Helm, enabling users to join communities via `helm://invite?communityId=XYZ`.

## Proposed Changes

### 1. Native Configuration
- **[Modify] [AndroidManifest.xml](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/android/app/src/main/AndroidManifest.xml)**: Add an `<intent-filter>` to handle the `helm://` scheme.
- **iOS (Manual)**: I will provide the XML snippet for `Info.plist` (since the `ios` directory is currently missing in your project root).

### 2. Dependencies
- **[Modify] [pubspec.yaml](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/pubspec.yaml)**: Add `app_links` for deep link interception.

### 3. Backend Logic (Supabase)
- **[Modify] [supabase_service.dart](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/lib/services/supabase_service.dart)**:
    - Add `joinCommunity(String communityId)`:
        - Checks if the user is authenticated.
        - Safely inserts a record into `community_members`.
        - Handles errors (already a member, invalid community).

### 4. Deep Link Service
- **[NEW] [lib/services/invite_service.dart](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/lib/services/invite_service.dart)**:
    - Use `AppLinks` to listen for incoming URLs.
    - Handle "cold starts" (initial link) and "background" events.
    - Parse `communityId` from query parameters.
    - Implement the "Auth State Guard": If not logged in, store the ID and redirect to onboarding/login.

### 5. App Integration
- **[Modify] [main.dart](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/lib/main.dart)**:
    - Initialize `InviteService` in `main()` after Supabase.
    - Set up a listener to trigger the join logic once the user logs in.

## Verification Plan

### Manual Verification
- **Cold Start**: Close the app completely, then run `adb shell am start -W -a android.intent.action.VIEW -d "helm://invite?communityId=TEST_ID" com.example.helm`.
- **Background**: Open the app, then trigger the same `adb` command.
- **Auth Guard**: Trigger the link while logged out, log in, and verify the user is automatically added to the community.
- **Error Handling**: Test with an invalid `communityId` and verify the app displays a clear error message.
