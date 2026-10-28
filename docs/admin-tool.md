# Feedback admin tool (local operator use only)

`tools/admin/admin.html` is a single-file read-only dashboard for the `feedback`
table. It exists because the table is not exposed to the app itself.

## Why it lives outside `web/`

Anything inside `helm/web/` is copied into the Flutter web build and served
publicly at `/<filename>`. This page asks the operator for a **`service_role`**
key, which bypasses every Row-Level Security policy. Shipping that page to
production handed the key-harvesting form to the public, next to a stored-XSS
sink in the feedback renderer.

The page is now:

- **outside** the build (not deployed — see `helm/web/` for what is),
- **escaped** — feedback rows are rendered with `textContent`, never `innerHTML`,
  so a malicious submission cannot execute in a page that holds a
  `service_role` key,
- **non-persistent** — the key is kept in a JS variable for the tab's lifetime;
  it is never written to `localStorage` or a cookie.

## Usage

1. Open the file directly from disk (double-click, or
   `start tools/admin/admin.html` on Windows).
2. Paste the `service_role` key from Supabase → Project Settings → API.
3. Click **Refresh**.

Never deploy this file, never copy it back into `helm/web/`, and never paste its
key into a page served over the network.

## Known limitations / follow-ups

- A raw `service_role` key in the browser is a blunt instrument. The proper fix
  is an authenticated admin route backed by an RLS policy
  (`internal.role_weight(...) = 3`) and a `security definer` RPC, so no
  long-lived key ever reaches the client. Tracked as Phase 3 in
  [`security-remediation-plan.md`](./security-remediation-plan.md).
- The page has no pagination; it loads every row. Fine for the current volume.
