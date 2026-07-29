# Community Invite System Walkthrough

I have implemented a secure, deep-link-based community invite system for Helm. This allows admins to share a link that automatically joins users into communities.

## Key Accomplishments

### 1. Native Deep Link Interception
- **Android**: Configured `AndroidManifest.xml` to handle the `helm://invite` scheme. The app will now automatically open when a link like `helm://invite?communityId=XYZ` is tapped.
- **iOS Configuration**: Add the following XML snippet to your `ios/Runner/Info.plist` file:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLName</key>
    <string>helm</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>helm</string>
    </array>
  </dict>
</array>
```

### 2. Intelligent Interception Logic
- **`InviteService`**: Implemented a robust listener using the `app_links` package.
- **State Persistence**: If an unauthenticated user clicks a link, the service securely stores the `communityId` in memory.
- **Auto-Join on Login**: Added an `onAuthStateChange` listener that automatically executes the `joinCommunity` logic the moment the user successfully signs in.

### 3. Secure Supabase Integration
- **`joinCommunity`**: Added a dedicated method to `SupabaseService` that:
    - Validates the current session.
    - Prevents duplicate memberships.
    - Inserts the member with the default 'member' role into the `community_members` table.

## Summary of Changes

### [Services]
- `[NEW]` [invite_service.dart](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/lib/services/invite_service.dart): The hub for link handling and auth-guarding.
- `[MODIFY]` [supabase_service.dart](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/lib/services/supabase_service.dart): Added joining logic.

### [Native & Config]
- `[MODIFY]` [AndroidManifest.xml](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/android/app/src/main/AndroidManifest.xml): Enabled custom scheme handling.
- `[MODIFY]` [pubspec.yaml](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/pubspec.yaml): Added `app_links` dependency.

### [Core Files]
- `[MODIFY]` [main.dart](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/lib/main.dart): Bootstrapped the invite service.

## Verification Instructions

### 1. Test via CLI (Android)
While the app is closed or in background:
```bash
adb shell am start -W -a android.intent.action.VIEW -d "helm://invite?communityId=XYZ" com.example.helm
```

### 2. Test Auth Flow
- Log out of the app.
- Click an invite link.
- Log in.
- Verify in your Supabase dashboard that the user has been added to community `XYZ`.
