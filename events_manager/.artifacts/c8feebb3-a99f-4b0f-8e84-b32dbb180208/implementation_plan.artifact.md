# Fix Windows App Notification Menu Lag

This plan addresses the performance issues (lag) reported on the Windows app when clicking the notification icon.

## Proposed Changes

### [Component] UI / Widgets
#### [MODIFY] [notification_feed.dart](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/lib/widgets/notification_feed.dart)
- Remove `shrinkWrap: true` from the `ListView.builder`. `shrinkWrap` is performance-heavy as it forces a layout pass to calculate total height.
- Replace `Flexible` with a more efficient structure.
- Wrap the main container in a `SizedBox` with a fixed or constrained height for desktop to prevent layout thrashing.

### [Component] Core Logic
#### [MODIFY] [app_shell.dart](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/lib/app_shell.dart)
- Simplify the `showMenu` positioning logic.
- Consider using a `BoxConstraints` to enforce a stable size for the menu.
- If lag persists, migrate from `showMenu` (which is designed for simple items) to a lightweight `OverlayEntry` or a `showDialog` with a tailored position, which is more robust for complex UI components on desktop.

---

## Verification Plan

### Manual Verification
- Tap the notification bell on Windows and verify the menu opens instantly without UI freezing.
- Scroll through the mock notifications and ensure scrolling is fluid.
- Verify that the layout remains responsive and fits correctly below the bell icon.
