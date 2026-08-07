# Phase 3: Community Collaboration & Shared Invitations

This plan implements the "Helm Communities" feature, allowing users to create shared workspaces and invite others via deep links.

## User Review Required

> [!IMPORTANT]
> **Deep Link Configuration**: For `helm://invite` links to work on physical devices, you must configure your Android/iOS intent filters. I have already added the Android filter to your `AndroidManifest.xml`, but you will need to register the scheme in the Supabase Dashboard as a valid redirect URL if you plan to use it for Email Auth.

## Proposed Changes

### 1. Community Lifecycle (Backend & Service)
- **[Modify] [supabase_service.dart](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/lib/services/supabase_service.dart)**:
    - Add `createCommunity(String name)`: Creates a community and automatically adds the creator as an 'admin'.
    - Add `getCommunityMembers(String communityId)`: Fetches the member list for the "Manage Members" view.
- **[Modify] [SQL]**: Add a trigger to automatically add the creator of a community to `community_members`.

### 2. Community Hub UI
- **[Modify] [community_list_view.dart](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/lib/community_list_view.dart)**:
    - Add a "Create Community" button/card.
    - Implement a simple dialog to input the new community name.

### 3. Sharing & Invitations
- **[NEW] [community_manage_page.dart](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/lib/community_manage_page.dart)**:
    - A screen to view members and their roles.
    - A prominent "Invite Member" button that generates a `helm://invite?communityId=...` link and copies it to the clipboard.

### 4. Navigation Integration
- **[Modify] [main.dart](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/lib/main.dart)**:
    - Add the `/manage-community` route.

## Verification Plan

### Manual Verification
- **Creation**: Create a community called "Team Alpha" and verify it appears in your sidebar.
- **Invitations**: Go to "Manage Members", tap "Invite", and verify a link is copied to your clipboard.
- **Joining**: Paste that link into a browser or another device's terminal (`adb shell am start -a android.intent.action.VIEW -d "helm://invite?communityId=..."`) and verify you are added to the group.
- **Collaboration**: Create a task in the new community and verify it's tagged with the community name.
