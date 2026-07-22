# Fix Global Keyboard Shortcuts

This plan addresses the issue where `Ctrl+F` and `Ctrl+N` shortcuts are not triggering as expected.

## User Review Required

> [!NOTE]
> The previous implementation required both `Ctrl` AND `Meta` (Win/Cmd) keys to be pressed simultaneously because of how `SingleActivator` was configured. I will separate these to support standard platform modifiers correctly.

## Proposed Changes

### 1. Fix Activator Logic
- **[Modify] [app_shell.dart](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/lib/app_shell.dart)**: Update the `Shortcuts` mapping to use separate activators for `Control` and `Meta` keys. This ensures `Ctrl+N` works on Windows/Linux and `Cmd+N` works on macOS.

### 2. Ensure Keyboard Focus
- **[Modify] [app_shell.dart](file:///C:/Users/Lenovo/StudioProjects/EventsManager/events_manager/lib/app_shell.dart)**: Wrap the core UI in a `Focus` widget with `autofocus: true`. Shortcuts in Flutter only trigger when the `Shortcuts` widget or one of its descendants has focus.

## Verification Plan

### Manual Verification
- Test `Ctrl+N` to open the task form.
- Test `Ctrl+F` to open the search bar.
- Test `Ctrl+Space` to trigger AI voice UI.
- Verify these work on both the Dashboard and other pages wrapped in `AppShell`.
