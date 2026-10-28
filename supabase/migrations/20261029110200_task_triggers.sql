-- Triggers that mirror the business rules in AGENTS.md §5.
--
-- ⚠️ AUTHORED, NOT APPLIED. Verify on a branch database first (see
-- supabase/tests/rls_test.sql) before promoting to production.

-- ---------------------------------------------------------------- tasks -----

-- `updated_at` is the conflict key for last-write-wins *and* the reset point for
-- the 2-comment limit, so it must move exactly when the task actually changes.
--
-- Always stamping `now()` would let an identical re-save (reorder replay,
-- realtime echo) wipe everyone's comment allowance. Trusting the client value
-- would let a client send a future timestamp and never be quota-limited again.
-- So: bump on a real property change, otherwise keep the old value.
create or replace function internal.touch_task_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    new.updated_at := now();
    return new;
  end if;

  if new.title          is distinct from old.title
     or new.description  is distinct from old.description
     or new.status       is distinct from old.status
     or new.priority     is distinct from old.priority
     or new.subtasks     is distinct from old.subtasks
     or new.assignees    is distinct from old.assignees
     or new.category_ids is distinct from old.category_ids
     or new.due_at       is distinct from old.due_at
     or new.is_completed is distinct from old.is_completed
     or new."order"      is distinct from old."order"
     or new.community_id is distinct from old.community_id then
    new.updated_at := now();
  else
    new.updated_at := old.updated_at;
  end if;

  return new;
end;
$$;

drop trigger if exists tasks_touch_updated_at on public.tasks;
create trigger tasks_touch_updated_at
  before insert or update on public.tasks
  for each row execute function internal.touch_task_updated_at();

-- Assignment notifications. CHANGELOG 0.3.2 claimed these existed; nothing in
-- the repo inserted them, so `notifications` was always empty in practice.
create or replace function internal.notify_task_assignees()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_assignee text;
  v_previous text[];
begin
  v_previous := case when tg_op = 'UPDATE'
                     then coalesce(old.assignees, '{}'::text[])
                     else '{}'::text[]
                end;

  for v_assignee in
    select a from unnest(coalesce(new.assignees, '{}'::text[])) as a
    except
    select p from unnest(v_previous) as p
  loop
    -- Never notify yourself, and ignore malformed ids rather than failing the
    -- whole write over a bad array element.
    if v_assignee ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       and v_assignee::uuid is distinct from new.user_id then
      insert into public.notifications (user_id, type, title, body, related_id, is_read)
      values (
        v_assignee::uuid,
        'task_assignment',
        'New task assigned',
        new.title,
        new.id,
        false
      );
    end if;
  end loop;

  return null;
end;
$$;

drop trigger if exists tasks_notify_assignees on public.tasks;
create trigger tasks_notify_assignees
  after insert or update on public.tasks
  for each row execute function internal.notify_task_assignees();

-- --------------------------------------------------------- task_comments ----

-- AGENTS.md §5: at most 2 comments per user per task where
-- `created_at >= tasks.updated_at`. Any real task update moves `updated_at`
-- (see the trigger above), which resets every user's allowance.
--
-- The client computes the same rule to disable the input, but this is the
-- enforcement point.
create or replace function internal.enforce_comment_quota()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_task_updated timestamptz;
  v_count integer;
begin
  select t.updated_at into v_task_updated
  from public.tasks t
  where t.id = new.task_id;

  if v_task_updated is null then
    raise exception 'task_not_found' using errcode = 'P0002';
  end if;

  -- RLS already guarantees the caller can see the task; also enforce that the
  -- comment is authored by the caller so a forged user_id cannot consume
  -- someone else's quota.
  if new.user_id is distinct from auth.uid() then
    raise exception 'comment_author_mismatch' using errcode = 'P0001';
  end if;

  select count(*) into v_count
  from public.task_comments c
  where c.task_id = new.task_id
    and c.user_id = new.user_id
    and c.created_at >= v_task_updated;

  if v_count >= 2 then
    raise exception 'comment_limit_reached' using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists task_comments_enforce_quota on public.task_comments;
create trigger task_comments_enforce_quota
  before insert on public.task_comments
  for each row execute function internal.enforce_comment_quota();

-- ----------------------------------------------------- community_members ----

-- The RLS policy already blocks demotion; this trigger makes the invariant hold
-- even for writes that bypass RLS (service_role, migrations, a mistaken admin
-- script). Owner is 3 and cannot be demoted (AGENTS.md §5).
create or replace function internal.protect_owner_role()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if old.role = 'owner' and new.role is distinct from 'owner' then
    raise exception 'owner_cannot_be_demoted' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists community_members_protect_owner on public.community_members;
create trigger community_members_protect_owner
  before update of role on public.community_members
  for each row execute function internal.protect_owner_role();

-- --------------------------------------------------------------- feedback ---
-- The feedback form posts with the publishable key as `anon`. Revoking the
-- insert closes a spam channel, but it also breaks that form, so it is left
-- commented out until the submission moves behind the `ai`-style Edge Function.
-- See docs/database.md §8.
--
-- revoke insert on public.feedback from anon;
