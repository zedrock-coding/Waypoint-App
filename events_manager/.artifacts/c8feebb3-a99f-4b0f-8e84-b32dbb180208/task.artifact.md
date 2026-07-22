# Global Keyboard Shortcuts Fix Tasks

- `[x]` **Phase 1: Fix Activator Logic**
    - `[x]` Update `SingleActivator` in `app_shell.dart` to support both Ctrl and Meta independently.
- `[x]` **Phase 2: Ensure Keyboard Focus**
    - `[x]` Wrap `AppShell` body in a `Focus` widget with `autofocus: true`.
- `[ ]` **Phase 3: Verification**
    - `[ ]` Test Ctrl+N, Ctrl+F, and Ctrl+Space on Desktop.
    - `[ ]` Verify Cmd+N, Cmd+F, and Cmd+Space for Mac users.
