-- Migration: 20261108_performance_and_protection.sql
-- Video 3 (31 Performance Optimization Techniques) & Video 4 (20 Data Protection Safeguards)

-- ============================================================================
-- 1. Soft Delete Schema Additions (Safeguard 11: Soft Deletes / Trash Bins)
-- ============================================================================

ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE public.subtasks ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'task_comments') THEN
        ALTER TABLE public.task_comments ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'communities') THEN
        ALTER TABLE public.communities ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'categories') THEN
        ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
    END IF;
END $$;

-- ============================================================================
-- 2. Query Filtering & Performance Indexes (Video 3 Technique 17: Database Indexing)
-- ============================================================================

-- Fast active task retrieval by community & status
CREATE INDEX IF NOT EXISTS idx_tasks_community_status_active 
    ON public.tasks (community_id, status) 
    WHERE deleted_at IS NULL;

-- Fast active task retrieval by user & due_at
CREATE INDEX IF NOT EXISTS idx_tasks_user_due_active 
    ON public.tasks (user_id, due_at) 
    WHERE deleted_at IS NULL;

-- Fast active task retrieval by user & status
CREATE INDEX IF NOT EXISTS idx_tasks_user_status_active 
    ON public.tasks (user_id, status) 
    WHERE deleted_at IS NULL;

-- Fast subtask retrieval
CREATE INDEX IF NOT EXISTS idx_subtasks_task_id_active 
    ON public.subtasks (task_id) 
    WHERE deleted_at IS NULL;

-- Task comments index
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'task_comments') THEN
        CREATE INDEX IF NOT EXISTS idx_task_comments_task_created_active 
            ON public.task_comments (task_id, created_at) 
            WHERE deleted_at IS NULL;
    END IF;
END $$;

-- ============================================================================
-- 3. Audit Logging (Safeguards 16: Immutable Audit Logs & 17: Change Data Capture)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    operation TEXT NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE', 'SOFT_DELETE', 'RESTORE'
    performed_by UUID,
    old_data JSONB,
    new_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Immutable audit logs: Deny all client updates and deletes
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS audit_logs_read_admins ON public.audit_logs;
CREATE POLICY audit_logs_read_admins ON public.audit_logs
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.community_members
            WHERE user_id = auth.uid() AND role IN ('owner', 'admin')
        )
    );

-- Audit log trigger function
CREATE OR REPLACE FUNCTION public.log_audit_event()
RETURNS TRIGGER AS $$
DECLARE
    current_user_id UUID;
    op TEXT;
BEGIN
    current_user_id := auth.uid();
    IF TG_OP = 'DELETE' THEN
        INSERT INTO public.audit_logs (table_name, record_id, operation, performed_by, old_data)
        VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', current_user_id, to_jsonb(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
            op := 'SOFT_DELETE';
        ELSIF OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL THEN
            op := 'RESTORE';
        ELSE
            op := 'UPDATE';
        END IF;
        INSERT INTO public.audit_logs (table_name, record_id, operation, performed_by, old_data, new_data)
        VALUES (TG_TABLE_NAME, NEW.id, op, current_user_id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO public.audit_logs (table_name, record_id, operation, performed_by, new_data)
        VALUES (TG_TABLE_NAME, NEW.id, 'INSERT', current_user_id, to_jsonb(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach audit trigger to tasks
DROP TRIGGER IF EXISTS audit_tasks_trigger ON public.tasks;
CREATE TRIGGER audit_tasks_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.tasks
    FOR EACH ROW EXECUTE FUNCTION public.log_audit_event();

-- ============================================================================
-- 4. Batch Mutation Cap Safeguard (Safeguards 5: Batch Size Caps & 8: Server-Side Enforcement)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.check_batch_mutation_cap()
RETURNS TRIGGER AS $$
DECLARE
    affected_count INTEGER;
BEGIN
    IF TG_OP = 'DELETE' THEN
        SELECT COUNT(*) INTO affected_count FROM old_table;
    ELSIF TG_OP = 'UPDATE' THEN
        SELECT COUNT(*) INTO affected_count FROM new_table;
    ELSE
        RETURN NULL;
    END IF;

    -- Hard safeguard ceiling: 100 rows per transaction statement
    IF affected_count > 100 THEN
        RAISE EXCEPTION 'Safeguard Violation: Batch mutation exceeds maximum limit of 100 records (attempted % records). Use paginated chunks or contact an administrator.', affected_count;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS enforce_batch_cap_tasks_delete ON public.tasks;
CREATE TRIGGER enforce_batch_cap_tasks_delete
    AFTER DELETE ON public.tasks
    REFERENCING OLD TABLE AS old_table
    FOR EACH STATEMENT EXECUTE FUNCTION public.check_batch_mutation_cap();

DROP TRIGGER IF EXISTS enforce_batch_cap_tasks_update ON public.tasks;
CREATE TRIGGER enforce_batch_cap_tasks_update
    AFTER UPDATE ON public.tasks
    REFERENCING NEW TABLE AS new_table
    FOR EACH STATEMENT EXECUTE FUNCTION public.check_batch_mutation_cap();

-- ============================================================================
-- 5. Soft-Delete RLS Policy Updating (Safeguards 3: Role-Based Deletion Access & 11)
-- ============================================================================

-- Active tasks query policy excludes soft-deleted records
DROP POLICY IF EXISTS tasks_select ON public.tasks;
CREATE POLICY tasks_select ON public.tasks
    FOR SELECT TO authenticated
    USING (
        (
            user_id = auth.uid()
            OR (community_id IS NOT NULL AND internal.is_member(community_id, auth.uid()))
        )
        AND deleted_at IS NULL
    );

-- User trash bin view: users can view their own soft-deleted items to recover them
DROP POLICY IF EXISTS tasks_select_trash ON public.tasks;
CREATE POLICY tasks_select_trash ON public.tasks
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        AND deleted_at IS NOT NULL
    );

-- Hard deletes restricted to community owners (Safeguard 3)
DROP POLICY IF EXISTS tasks_delete ON public.tasks;
CREATE POLICY tasks_delete ON public.tasks
    FOR DELETE TO authenticated
    USING (
        user_id = auth.uid()
        OR (
            community_id IS NOT NULL
            AND internal.role_weight(community_id, auth.uid()) >= 3 -- Owner only for hard delete
        )
    );

