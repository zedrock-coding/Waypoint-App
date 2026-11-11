-- Migration: 20261111_add_task_periodicity.sql
-- Adds recurrence/periodicity metadata to public.tasks

-- 1. Create Recurrence Frequency Enum if not exists
DO $$ BEGIN
    CREATE TYPE recurrence_frequency AS ENUM ('daily', 'weekly', 'biweekly', 'monthly', 'yearly', 'custom');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. Modify tasks table to support recurrence patterns
ALTER TABLE public.tasks
ADD COLUMN IF NOT EXISTS is_recurring BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS recurrence_frequency recurrence_frequency NULL,
ADD COLUMN IF NOT EXISTS recurrence_interval INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS recurrence_days_of_week INTEGER[] NULL,
ADD COLUMN IF NOT EXISTS recurrence_end_date TIMESTAMPTZ NULL,
ADD COLUMN IF NOT EXISTS parent_recurring_task_id UUID REFERENCES public.tasks(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS original_due_date TIMESTAMPTZ NULL;

-- 3. Composite Index for recurrence queries and next-instance lookups
CREATE INDEX IF NOT EXISTS idx_tasks_recurring ON public.tasks(user_id, is_recurring, status)
WHERE deleted_at IS NULL;

