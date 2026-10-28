-- Internal helpers used by RLS policies and triggers.
--
-- ⚠️ AUTHORED, NOT APPLIED. This file has never been run against a real
-- database (no Supabase CLI / DB credentials were available). Apply it to a
-- branch database first, then promote. See docs/database.md §7–§8.
--
-- Why a separate schema: PostgREST only exposes `public` (and explicitly
-- configured schemas), so functions in `internal` cannot be called over the
-- REST API. They are still usable from policies, which run inside Postgres.

create schema if not exists internal;

comment on schema internal is
  'RLS/trigger helpers. Not exposed through PostgREST; not an API surface.';

-- Role weight, mirroring AGENTS.md §5. Unknown / absent membership is 0, which
-- fails every comparison, so a missing membership never grants access.
create or replace function internal.role_weight(
  p_community_id uuid,
  p_user_id uuid
)
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (
      select case lower(btrim(m.role))
               when 'owner' then 3
               when 'admin' then 2
               when 'member' then 1
               else 0
             end
      from public.community_members m
      where m.community_id = p_community_id
        and m.user_id = p_user_id
      limit 1
    ),
    0
  );
$$;

comment on function internal.role_weight(uuid, uuid) is
  'Owner=3, admin=2, member=1, non-member=0 (AGENTS.md §5).';

-- Membership test used by the read policies.
create or replace function internal.is_member(
  p_community_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select internal.role_weight(p_community_id, p_user_id) > 0;
$$;

-- SECURITY DEFINER is what keeps `community_members` policies from recursing:
-- the helper reads the table as its owner, so evaluating the policy does not
-- re-enter the policy.
revoke all on function internal.role_weight(uuid, uuid) from public, anon;
revoke all on function internal.is_member(uuid, uuid) from public, anon;
grant usage on schema internal to authenticated;
grant execute on function internal.role_weight(uuid, uuid) to authenticated;
grant execute on function internal.is_member(uuid, uuid) to authenticated;

-- The client inserts a community with only `name`, so the creator must be
-- filled in server-side. If this default is already present this is a no-op.
do $$
begin
  if to_regclass('public.communities') is not null then
    alter table public.communities alter column creator_id set default auth.uid();
  end if;
end $$;
