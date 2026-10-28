-- Row Level Security: the actual authorization boundary.
--
-- ⚠️ AUTHORED, NOT APPLIED. Apply to a branch database and verify with
-- supabase/tests/rls_test.sql before promoting. A wrong policy can lock users
-- out of their own data; docs/database.md §8 lists what to check.
--
-- Shape of every policy below: deny by default, then allow only the owner or a
-- community member whose role weight satisfies the rule in AGENTS.md §5.
--
-- Policies are written `to authenticated` on purpose: anonymous visitors have no
-- business reading any of these tables.

-- ---------------------------------------------------------------- tasks -----

alter table public.tasks enable row level security;

drop policy if exists tasks_select on public.tasks;
create policy tasks_select on public.tasks
  for select to authenticated
  using (
    user_id = auth.uid()
    or (community_id is not null and internal.is_member(community_id, auth.uid()))
  );

drop policy if exists tasks_insert on public.tasks;
create policy tasks_insert on public.tasks
  for insert to authenticated
  with check (
    (community_id is null and user_id = auth.uid())
    or (community_id is not null and internal.is_member(community_id, auth.uid()))
  );

-- Editing a task requires a role weight at least equal to the creator's.
-- `with check` re-evaluates the NEW row, so a write cannot smuggle the task into
-- another community or hand ownership to someone else.
drop policy if exists tasks_update on public.tasks;
create policy tasks_update on public.tasks
  for update to authenticated
  using (
    user_id = auth.uid()
    or (
      community_id is not null
      and internal.role_weight(community_id, auth.uid())
          >= internal.role_weight(community_id, user_id)
    )
  )
  with check (
    user_id = auth.uid()
    or (
      community_id is not null
      and internal.role_weight(community_id, auth.uid())
          >= internal.role_weight(community_id, user_id)
    )
  );

-- Deleting is stricter than editing: creator, or admin/owner of the community.
drop policy if exists tasks_delete on public.tasks;
create policy tasks_delete on public.tasks
  for delete to authenticated
  using (
    user_id = auth.uid()
    or (
      community_id is not null
      and internal.role_weight(community_id, auth.uid()) >= 2
    )
  );

-- --------------------------------------------------------- task_comments ----
-- Reading a comment must follow the parent task's visibility, so the policy
-- delegates to `tasks` (which is itself RLS-filtered). The 2-comment quota is
-- enforced by a trigger, not here — a `with check` cannot count rows.

alter table public.task_comments enable row level security;

drop policy if exists task_comments_select on public.task_comments;
create policy task_comments_select on public.task_comments
  for select to authenticated
  using (
    exists (
      select 1 from public.tasks t where t.id = task_comments.task_id
    )
  );

drop policy if exists task_comments_insert on public.task_comments;
create policy task_comments_insert on public.task_comments
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.tasks t where t.id = task_comments.task_id
    )
  );

drop policy if exists task_comments_update on public.task_comments;
create policy task_comments_update on public.task_comments
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists task_comments_delete on public.task_comments;
create policy task_comments_delete on public.task_comments
  for delete to authenticated
  using (user_id = auth.uid());

-- ------------------------------------------------------------ communities ---

alter table public.communities enable row level security;

drop policy if exists communities_select on public.communities;
create policy communities_select on public.communities
  for select to authenticated
  using (
    creator_id = auth.uid()
    or internal.is_member(id, auth.uid())
  );

drop policy if exists communities_insert on public.communities;
create policy communities_insert on public.communities
  for insert to authenticated
  with check (creator_id = auth.uid());

drop policy if exists communities_update on public.communities;
create policy communities_update on public.communities
  for update to authenticated
  using (internal.role_weight(id, auth.uid()) >= 2)
  with check (internal.role_weight(id, auth.uid()) >= 2);

drop policy if exists communities_delete on public.communities;
create policy communities_delete on public.communities
  for delete to authenticated
  using (creator_id = auth.uid());

-- ----------------------------------------------------- community_members ----

alter table public.community_members enable row level security;

drop policy if exists community_members_select on public.community_members;
create policy community_members_select on public.community_members
  for select to authenticated
  using (
    user_id = auth.uid()
    or internal.is_member(community_id, auth.uid())
  );

-- Joining by invite link inserts your own `member` row. The creator's `owner`
-- row is inserted right after the community itself. Promotion is never an
-- insert: a self-join cannot claim a higher role.
drop policy if exists community_members_insert on public.community_members;
create policy community_members_insert on public.community_members
  for insert to authenticated
  with check (
    (user_id = auth.uid() and role = 'member')
    or (
      role = 'owner'
      and exists (
        select 1 from public.communities c
        where c.id = community_members.community_id
          and c.creator_id = auth.uid()
      )
    )
    or internal.role_weight(community_id, auth.uid()) >= 2
  );

-- Strictly greater weight, so an admin can never demote another admin.
drop policy if exists community_members_update on public.community_members;
create policy community_members_update on public.community_members
  for update to authenticated
  using (
    internal.role_weight(community_id, auth.uid())
      > internal.role_weight(community_id, user_id)
  )
  with check (
    internal.role_weight(community_id, auth.uid())
      > internal.role_weight(community_id, user_id)
  );

-- Leave the community yourself, or remove someone with a lower weight. Owner
-- rows are never removable from the client: dissolve the community instead.
drop policy if exists community_members_delete on public.community_members;
create policy community_members_delete on public.community_members
  for delete to authenticated
  using (
    role <> 'owner'
    and (
      user_id = auth.uid()
      or internal.role_weight(community_id, auth.uid())
         > internal.role_weight(community_id, user_id)
    )
  );

-- -------------------------------------------------------------- categories --
-- Personal, per-user data.

alter table public.categories enable row level security;

drop policy if exists categories_all on public.categories;
create policy categories_all on public.categories
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ------------------------------------------------------------ notifications --
-- Written by triggers (assignment, mentions). Clients may only read their own
-- and mark them read.

alter table public.notifications enable row level security;

drop policy if exists notifications_select on public.notifications;
create policy notifications_select on public.notifications
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists notifications_update on public.notifications;
create policy notifications_update on public.notifications
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
