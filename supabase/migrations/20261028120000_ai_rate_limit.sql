-- Per-user daily quota for the `ai` Edge Function.
--
-- Without this, the AI endpoint is an unbounded spending channel: any
-- authenticated account can call Gemini as fast as it can send requests.
-- Quota is keyed on (user, UTC day) and consumed by a SECURITY DEFINER function
-- so the table itself is never readable or writable by clients.

create table if not exists public.ai_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  usage_date date not null default ((now() at time zone 'utc')::date),
  request_count integer not null default 0 check (request_count >= 0),
  primary key (user_id, usage_date)
);

comment on table public.ai_usage is
  'Daily AI request counters. Only public.consume_ai_quota() touches this table.';

alter table public.ai_usage enable row level security;

-- No policies on purpose: RLS with zero policies denies every client role.
-- The SECURITY DEFINER function below is the only access path.

create or replace function public.consume_ai_quota(p_limit integer default 30)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_count integer;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  if p_limit is null or p_limit < 1 then
    raise exception 'invalid_limit' using errcode = '22023';
  end if;

  insert into public.ai_usage (user_id, usage_date, request_count)
  values (v_uid, (now() at time zone 'utc')::date, 1)
  on conflict (user_id, usage_date) do update
    set request_count = public.ai_usage.request_count + 1
    where public.ai_usage.request_count < p_limit
  returning request_count into v_count;

  -- The WHERE clause above makes the upsert affect zero rows once the limit is
  -- reached, so RETURNING yields NULL and we refuse the request.
  if v_count is null then
    raise exception 'rate_limit_exceeded' using errcode = 'P0001';
  end if;

  return greatest(p_limit - v_count, 0);
end;
$$;

revoke all on function public.consume_ai_quota(integer) from public;
revoke all on function public.consume_ai_quota(integer) from anon;
grant execute on function public.consume_ai_quota(integer) to authenticated;
