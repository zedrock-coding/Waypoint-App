# Waypoint / Helm Disaster Recovery Runbook

| Parameter | SLA / Objective | Notes |
|---|---|---|
| **Recovery Point Objective (RPO)** | **< 5 minutes** | Supabase Point-in-Time Recovery (PITR) WAL log shipping |
| **Recovery Time Objective (RTO)** | **< 30 minutes** | Staging fork promotion or backup dump restore |
| **Data Scope** | Database, Storage Buckets, Audit Logs | PostgreSQL + S3-compatible Object Storage |

---

## 1. Automated Safeguard Architecture

1. **Continuous Write-Ahead Log (WAL) Archiving (Safeguard 15)**:
   - Supabase Point-in-Time Recovery (PITR) continuously streams database transaction logs.
   - Any point in time within the retention window (7 to 30 days) is restorable with second-level precision.
2. **Soft Deletions (Safeguard 11)**:
   - All standard client deletions execute `UPDATE ... SET deleted_at = NOW()` rather than hard `DELETE`.
   - Deleted tasks and categories remain recoverable for 30 days via the trash bin.
3. **Hard Ceiling Batch Mutation Trigger (Safeguards 5 & 8)**:
   - `enforce_batch_cap_tasks_delete` and `enforce_batch_cap_tasks_update` immediately abort transactions mutating more than 100 rows in a single statement.
4. **Immutable Audit Trail (Safeguards 16 & 17)**:
   - The `audit_logs` table records every state mutation (`INSERT`, `UPDATE`, `DELETE`, `SOFT_DELETE`, `RESTORE`) with old and new JSON payloads.
   - RLS strictly blocks client modification or deletion of `audit_logs`.

---

## 2. Emergency Recovery Scenarios & Procedures

### Scenario A: Accidental Bulk Task Deletion / Overwrite
- **Detection**: Spike in user reports or elevated entries in `audit_logs` where `operation = 'DELETE'`.
- **Mitigation (Soft Delete Recovery)**:
  ```sql
  -- Inspect soft-deleted records affected within the last hour
  SELECT id, title, deleted_at FROM public.tasks
  WHERE deleted_at >= NOW() - INTERVAL '1 hour';

  -- Restore records
  UPDATE public.tasks
  SET deleted_at = NULL
  WHERE deleted_at >= NOW() - INTERVAL '1 hour';
  ```

### Scenario B: Catastrophic Table Corruption / Rogue Script
- **Action**: Invoke Point-in-Time Recovery (PITR) to a timestamp 60 seconds prior to incident.
  1. Go to Supabase Dashboard > Database > Backups > Point in Time.
  2. Select target timestamp: `T_incident - 60 seconds`.
  3. Spin up restored instance to verify data integrity.
  4. Repoint application environment variables to restored instance or promote fork.

### Scenario C: Service Role Credential Leak
- **Immediate Action**:
  1. Revoke and rotate `service_role` key in Supabase Project Settings > API.
  2. Update Edge Function secrets immediately:
     ```bash
     supabase secrets set SERVICE_ROLE_KEY=new_key_here
     ```
  3. Invalidate active operator sessions.

---

## 3. Staging Verification & Disaster Drill Schedule (Safeguard 13 & 20)

- **Monthly Drill**: Perform sandbox database restore into staging project to test restore runbook.
- **Migration Gate**: Schema changes must run through `supabase db lint` and pass pgTAP suites on staging before production deployment.

