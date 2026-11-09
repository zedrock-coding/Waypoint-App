-- Migration: 20261109194000_notifications_insert_policy.sql
-- Allow authenticated users to insert notifications for themselves (e.g. daily briefings, system reminders)

drop policy if exists notifications_insert on public.notifications;
create policy notifications_insert on public.notifications
  for insert to authenticated
  with check (user_id = auth.uid());

