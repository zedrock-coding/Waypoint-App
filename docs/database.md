# Helm — Database

| | |
|---|---|
| **Engine** | PostgreSQL (Supabase) |
| **Client** | `helm/lib/services/`, `helm/lib/providers/task_provider.dart` |
| **Last updated** | 2026-10-29 |
| **Verification status** | ⚠️ **Unverified against production.** This describes the schema and policy the client code expects. No live schema dump was available when this was written; treat it as the specification, not a guarantee. |

---

## 1. Ground rules

1. **RLS is the security boundary.** The Supabase URL and publishable key are
   public (they ship in `helm/web/config.js` and every APK). Anything a
   client-side check prevents, a determined user can bypass. Client checks in
   `TaskDetailPage` are UX only.
2. **Never put `service_role` anywhere near the client.** The admin console at
   `tools/admin/` runs locally and is never copied into `build/web`.
3. **`auth.uid()` is the identity.** Every policy predicate must be anchored on
   it, directly or via a membership lookup.

---

## 2. Tables

### `tasks`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | Generated client-side (Hive row id). |
| `title` | `text` | |
| `description` | `text` | |
| `community_id` | `uuid` → `communities.id` | `null` = personal task. |
| `category_ids` | `uuid[]` | References `categories.id`; no FK on array elements. |
| `assignees` | `uuid[]` | `auth.users.id` values. |
| `subtasks` | `jsonb` | `[{ "title": text, "is_completed": bool }]`. |
| `user_id` | `uuid` → `auth.users.id` | Creator. Drives RBAC. |
| `priority` | `text` | `low` \| `medium` \| `high`. |
| `status` | `text` | `To Do` \| `In Progress` \| `Done` (written via `_statusToString`). |
| `is_completed` | `boolean` | Denormalised mirror of `status == 'Done'`. |
| `order` | `integer` | Manual drag ordering within a list. |
| `due_at` | `timestamptz` | `null` = no deadline. |
| `created_at` | `timestamptz` | |
| `updated_at` | `timestamptz` | Conflict key for last-write-wins **and** the reset trigger for the 2-comment limit. |

`updated_at` is load-bearing. Any write that changes `title`, `description`,
`status`, `priority`, or `subtasks` must also bump it, otherwise the comment
quota never resets.

### `task_comments`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | |
| `task_id` | `uuid` → `tasks.id` | |
| `user_id` | `uuid` → `auth.users.id` | |
| `user_name` | `text` | Denormalised display name at write time. |
| `comment_text` | `text` | |
| `created_at` | `timestamptz` | Compared against `tasks.updated_at`. |

### `communities`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | |
| `name` | `text` | |
| `creator_id` | `uuid` → `auth.users.id` | |
| `created_at` | `timestamptz` | |

### `community_members`

| Column | Type | Notes |
|---|---|---|
| `community_id` | `uuid` → `communities.id` | |
| `user_id` | `uuid` → `auth.users.id` | |
| `role` | `text` | `owner` \| `admin` \| `member`. |
| `full_name` | `text` | May be absent; the client also reads it from the RPC below. |

Primary key should be `(community_id, user_id)`.

### `categories`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | Hive uses the same id as its box key. |
| `name` | `text` | |
| `user_id` | `uuid` → `auth.users.id` | Per-user, not per-community. |

### `notifications`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | |
| `user_id` | `uuid` → `auth.users.id` | Recipient. |
| `title` | `text` | |
| `body` | `text` | |
| `type` | `text` | Drives the feed icon. |
| `related_id` | `uuid` | Task id the client opens when the notification is tapped. |
| `is_read` | `boolean` | Bell counts `is_read = false`. |
| `created_at` | `timestamptz` | Feed sorts descending, limit 20. |

Clients only ever `update({is_read: true})` filtered by `user_id`; they never
insert. Row creation belongs to server-side triggers (`notify_task_assignees`).

### `feedback`

Public form table written by `helm/web/feedback.html` with the publishable key
as `anon`. Columns: `id`, `name`, `email`, `message`, `created_at`.

⚠️ Open: `anon` still has `insert`. Closing it means moving submission behind an
Edge Function; see `supabase/migrations/20261029110200_task_triggers.sql` (the
revoke is present but commented out).

### `ai_usage` (from `supabase/migrations/20261028120000_ai_rate_limit.sql`)

| Column | Type | Notes |
|---|---|---|
| `user_id` | `uuid` → `auth.users.id` | |
| `usage_date` | `date` | UTC day. |
| `request_count` | `integer` | `>= 0`. |

Primary key `(user_id, usage_date)`. RLS enabled with **zero policies**, so no
client role can read or write it. The SECURITY DEFINER function
`consume_ai_quota(p_limit)` is the only access path.

### Storage

Bucket `avatars`: one object per user, path prefixed by `auth.uid()`. Public
read is acceptable; writes must be restricted to the owner's own prefix.

---

## 3. RPCs

| Function | Kind | Contract |
|---|---|---|
| `get_user_communities()` | SECURITY DEFINER, `authenticated` | Returns the caller's communities. Must not accept a user id parameter. |
| `get_community_member_names(p_community_id uuid)` | SECURITY DEFINER, `authenticated` | Returns members (`user_id`, `full_name`, `role`) **only** for a community the caller belongs to. Must raise or return empty otherwise. |
| `delete_user_account()` | SECURITY DEFINER, `authenticated` | Deletes the caller's own rows and `auth.users` record. Must derive identity from `auth.uid()` alone. |
| `consume_ai_quota(p_limit integer default 30)` | SECURITY DEFINER, `authenticated` | Increments today's counter and raises `rate_limit_exceeded` (`P0001`) at the limit. Returns the remaining allowance. |

All SECURITY DEFINER functions must set `search_path = public, pg_temp` and
`revoke all … from public, anon` before `grant execute … to authenticated`.

---

## 4. Intended RLS policy set

> ⚠️ This is the policy the app needs. Confirm it matches production before
> relying on it.

Enable RLS on every table. Default deny; then:

### `tasks`

| Operation | Predicate |
|---|---|
| `select` | `community_id is null and user_id = auth.uid()` **or** `community_id in (select community_id from community_members where user_id = auth.uid())` |
| `insert` | owner/community member, and `user_id = auth.uid()` (personal) or caller is a member of `community_id`. |
| `update` | creator, or caller's role weight ≥ creator's role weight in that community (see `§5`). |
| `delete` | creator, or `owner`/`admin` of the community. |

### `task_comments`

| Operation | Predicate |
|---|---|
| `select` | caller can `select` the parent task. |
| `insert` | caller can `select` the parent task **and** `user_id = auth.uid()` **and** fewer than 2 of the caller's comments exist with `created_at >= tasks.updated_at`. |
| `update`/`delete` | `user_id = auth.uid()` only. |

The comment quota must be enforced in the database. The client computes the
same rule (`task_rules.dart`) purely to disable the input.

### `communities` / `community_members`

| Operation | Predicate |
|---|---|
| `select` | caller is a member. |
| `insert` (community) | `creator_id = auth.uid()`. |
| member management | `owner` or `admin` of that community; an `owner` row can never be demoted or removed. |
| `delete` (community) | `creator_id = auth.uid()`. |

### `categories`

Full CRUD restricted to `user_id = auth.uid()`.

### `notifications`

`select` and `update` restricted to `user_id = auth.uid()`. No client `insert`.

### `avatars`

Read for authenticated users; write only under `auth.uid()/…`.

---

## 5. Role weights

The weight comparison lives in two places and must stay in sync:

| Role | Weight | Capabilities |
|---|---|---|
| `owner` | 3 | Everything; cannot be demoted or removed. |
| `admin` | 2 | Manage members and tasks; cannot demote/remove owners or other admins. |
| `member` | 1 | View and comment; cannot edit tasks created by a higher weight. |

Client: `TaskDetailContent._checkPermissions()` (fails closed — an unknown
creator or a failed roster lookup means read-only).
Server: the `update`/`delete` predicates above.

---

## 6. Offline queue interaction

The client writes to Hive first and replays through `SyncService`:

| Action | Sent as |
|---|---|
| `create` | `upsert(payload)` |
| `update` | `update(patch).eq('id', id)` — **not** upsert |
| `delete` | `delete().eq('id', id)` |

Updates must be PATCHes: an upsert with a partial payload can insert a truncated
row when the server copy is gone. Failures are retried up to 5 times with
exponential backoff and then left queued.

Because replay is asynchronous, a policy that rejects a replayed write shows up
as a stuck queue entry rather than an error dialog. The header badge
(`SyncService.pendingChanges`) is how a stuck queue becomes visible.

---

## 7. Migration policy

- One change per file, named `YYYYMMDDHHMMSS_description.sql`, placed in
  `supabase/migrations/`.
- Migrations must be idempotent (`if not exists`, `create or replace`,
  `drop policy if exists` before `create policy`).
- Never edit an applied migration; add a new one.
- Anything that changes a table also gets its policy statements in the same
  file, so a table is never left without RLS.
- All 5 migrations are applied to remote project `eknzdxexfcfdmqvbyvxt`.

### 7.1 Applied migrations

| File | Contents | Status |
|---|---|---|
| `20261028120000_ai_rate_limit.sql` | `ai_usage` table and `consume_ai_quota()` function | Applied |
| `20261029110000_internal_helpers.sql` | `internal` schema, `role_weight()`, `is_member()`, `communities.creator_id` default | Applied |
| `20261029110100_rls_policies.sql` | RLS enable + policies for tasks, comments, communities, members, categories, notifications (legacy policies dropped) | Applied |
| `20261029110200_task_triggers.sql` | `updated_at` stamping, comment quota, owner-demotion guard, assignment notifications | Applied |
| `20261029110300_storage_avatars.sql` | Public read, owner-only write under `<uid>/` | Applied |
| `supabase/tests/rls_test.sql` | pgTAP coverage for local test runs | Authored |

Baseline schema before migrations is captured at `docs/baseline_schema.sql`.


---

## 8. Open verification items

1. Dump the live schema (`supabase db dump --schema public`) and reconcile it
   with §2. `supabase/migrations/0001_baseline.sql` does not exist yet.
2. Confirm RLS is enabled on every table and that no table has a permissive
   `using (true)` policy.
3. Apply the four migrations in §7.1 and run `supabase test db`.
4. Confirm `ai_usage` and `consume_ai_quota` exist in production.
5. Confirm the `avatars` bucket policies restrict writes to the owner prefix.
6. Verify at the API, not in the UI: two accounts (one Owner, one Member) — the
   Member's edit must fail with `curl`, not just be hidden by `AbsorbPointer`.
7. Decide the `feedback` path: Edge Function + captcha, or keep `anon` insert.
