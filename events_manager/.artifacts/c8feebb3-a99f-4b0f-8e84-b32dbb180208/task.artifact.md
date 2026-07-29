# Community Invite System Implementation Tasks

- `[x]` **Phase 1: Configuration & Setup**
    - `[x]` Add `app_links` to `pubspec.yaml`.
    - `[x]` Configure `AndroidManifest.xml` for `helm://invite` deep links.
    - `[x]` Provide `Info.plist` snippet for iOS.
- `[x]` **Phase 2: Service Implementation**
    - `[x]` Add `joinCommunity` to `lib/services/supabase_service.dart`.
    - `[x]` Create `lib/services/invite_service.dart` to handle URL interception and auth-guarding.
- `[x]` **Phase 3: Integration**
    - `[x]` Initialize `InviteService` in `main.dart`.
    - `[x]` Set up the global listener for post-login joins.
- `[ ]` **Phase 4: Verification**
    - `[ ]` Verify cold-start and background link handling.
    - `[ ]` Update walkthrough with usage instructions.
