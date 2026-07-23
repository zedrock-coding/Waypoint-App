# Fix Windows App Lag Tasks

- `[x]` **Phase 1: Component Optimization**
    - `[x]` Remove `shrinkWrap: true` from `NotificationFeedUI` in `lib/widgets/notification_feed.dart`.
    - `[x]` Add explicit constraints/height for desktop rendering.
- `[x]` **Phase 2: Navigation Refinement**
    - `[x]` Replaced `showMenu` with a high-performance state-based overlay.
    - `[x]` Integrated `CompositedTransformFollower` for snappy desktop positioning.
    - `[x]` Added click-outside-to-close logic.
- `[x]` **Phase 3: Verification**
    - `[x]` Verified fluid UI interactions on Windows.
