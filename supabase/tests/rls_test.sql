-- pgTAP tests for the RLS policies and triggers in supabase/migrations/.
--
-- Run with:  supabase test db
--
-- ⚠️ NEVER EXECUTED against a real database. Treat the first green run as the
-- evidence; everything here is unverified until then.
--
-- The whole file runs in one transaction that is rolled back, so it is safe to
-- point at a branch database.

begin;

set local search_path = public, extensions;

create extension if not exists pgtap;

select plan(10);

-- ---------------------------------------------------------------- fixtures --
--
-- owner    = 1111…   admin = 2222…   member = 3333…   outsider = 4444…
-- community = aaaa…  owner's task = bbbb…

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data
)
values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111',
   'authenticated', 'authenticated', 'owner@test.local',
   crypt('password', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{"full_name":"Owner"}'),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222',
   'authenticated', 'authenticated', 'admin@test.local',
   crypt('password', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{"full_name":"Admin"}'),
  ('00000000-0000-0000-0000-000000000000', '33333333-3333-3333-3333-333333333333',
   'authenticated', 'authenticated', 'member@test.local',
   crypt('password', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{"full_name":"Member"}'),
  ('00000000-0000-0000-0000-000000000000', '44444444-4444-4444-4444-444444444444',
   'authenticated', 'authenticated', 'outsider@test.local',
   crypt('password', gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{"full_name":"Outsider"}')
on conflict (id) do nothing;

insert into public.communities (id, name, creator_id)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test Community',
        '11111111-1111-1111-1111-111111111111')
on conflict (id) do nothing;

insert into public.community_members (community_id, user_id, role)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'owner'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'admin'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333', 'member')
on conflict do nothing;

insert into public.tasks (
  id, title, community_id, user_id, assignees,
  priority, status, is_completed, "order", subtasks
)
values (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Owner task',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '11111111-1111-1111-1111-111111111111', '{}',
  'medium', 'toDo', false, 0, '[]'::jsonb
)
on conflict (id) do nothing;

-- ------------------------------------------------------- read isolation -----

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);

select is(
  (select count(*) from public.tasks
    where community_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  0::bigint,
  'a non-member cannot see community tasks'
);

select is(
  (select count(*) from public.communities
    where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  0::bigint,
  'a non-member cannot see the community row'
);

select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);

select is(
  (select count(*) from public.tasks
    where community_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  1::bigint,
  'a member can see community tasks'
);

-- ------------------------------------------------------------ task RBAC ----

-- Member (weight 1) tries to edit the owner's (weight 3) task. RLS filters the
-- row out, so the statement affects nothing.
update public.tasks
   set title = 'hijacked'
 where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

reset role;

select is(
  (select title from public.tasks where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  'Owner task',
  'a member cannot edit a task created by the owner'
);

-- The owner can edit their own task.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

update public.tasks
   set title = 'Owner edited'
 where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

reset role;

select is(
  (select title from public.tasks where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  'Owner edited',
  'the owner can edit their own task'
);

-- ------------------------------------------------------- comment quota ------

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);

insert into public.task_comments (task_id, user_id, user_name, comment_text)
values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '33333333-3333-3333-3333-333333333333',
   'Member', 'first'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '33333333-3333-3333-3333-333333333333',
   'Member', 'second');

select throws_ok(
  $$
    insert into public.task_comments (task_id, user_id, user_name, comment_text)
    values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
            '33333333-3333-3333-3333-333333333333', 'Member', 'third')
  $$,
  'P0001',
  'comment_limit_reached',
  'a third comment is rejected'
);

-- The owner edits the task, which moves updated_at and resets the quota.
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

update public.tasks
   set title = 'Owner edited again'
 where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);

select lives_ok(
  $$
    insert into public.task_comments (task_id, user_id, user_name, comment_text)
    values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
            '33333333-3333-3333-3333-333333333333', 'Member', 'after reset')
  $$,
  'the quota resets after the task is updated'
);

-- ------------------------------------------------------- role hierarchy -----

-- Admin (2) vs admin (2): the policy requires strictly greater, so the update
-- matches no rows.
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

update public.community_members
   set role = 'member'
 where community_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
   and user_id = '22222222-2222-2222-2222-222222222222';

reset role;

select is(
  (select role from public.community_members
    where community_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      and user_id = '22222222-2222-2222-2222-222222222222'),
  'admin',
  'an admin cannot demote another admin'
);

-- The owner-demotion guard is a trigger, not a policy, so exercise it as an
-- actor that bypasses RLS (service_role equivalent).
select throws_ok(
  $$
    update public.community_members
       set role = 'member'
     where community_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
       and user_id = '11111111-1111-1111-1111-111111111111'
  $$,
  'P0001',
  'owner_cannot_be_demoted',
  'the owner role cannot be demoted, even without RLS'
);

-- ------------------------------------------------------- notifications ------

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);

select throws_ok(
  $$
    insert into public.notifications (user_id, type, title, body, is_read)
    values ('22222222-2222-2222-2222-222222222222', 'spoof', 'x', 'y', false)
  $$,
  '42501',
  null,
  'a client cannot insert notifications (no insert policy)'
);

reset role;

select * from finish();
rollback;
