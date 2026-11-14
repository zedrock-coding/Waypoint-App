-- Migration: 20261114143000_community_task_completion_rls.sql
-- Allow task completion and updates for community assignees and community members,
-- while preserving strict deletion guards (Admins/Owners or creator only).

DROP POLICY IF EXISTS tasks_update ON public.tasks;
CREATE POLICY tasks_update ON public.tasks
  FOR UPDATE TO authenticated
  USING (
    user_id = auth.uid()
    OR (
      community_id IS NOT NULL
      AND (
        auth.uid()::text = ANY(assignees)
        OR internal.role_weight(community_id, auth.uid()) >= internal.role_weight(community_id, user_id)
        OR internal.is_member(community_id, auth.uid())
      )
    )
  )
  WITH CHECK (
    user_id = auth.uid()
    OR (
      community_id IS NOT NULL
      AND (
        auth.uid()::text = ANY(assignees)
        OR internal.role_weight(community_id, auth.uid()) >= internal.role_weight(community_id, user_id)
        OR internal.is_member(community_id, auth.uid())
      )
    )
  );
