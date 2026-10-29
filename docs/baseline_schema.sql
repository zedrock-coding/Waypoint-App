


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."cleanup_empty_communities"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- If no members exist for this community ID anymore...
    IF NOT EXISTS (SELECT 1 FROM public.community_members WHERE community_id = OLD.community_id) THEN
        -- Delete the community and purge its tasks to save storage
        DELETE FROM public.communities WHERE id = OLD.community_id;
        DELETE FROM public.tasks WHERE community_id = OLD.community_id;
    END IF;
    RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."cleanup_empty_communities"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_user_account"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- We delete from the auth.users table using the caller's ID
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;


ALTER FUNCTION "public"."delete_user_account"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_community_member_names"("p_community_id" "uuid") RETURNS TABLE("user_id" "uuid", "role" "text", "full_name" "text", "avatar_url" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cm.user_id,
        cm.role,
        COALESCE((u.raw_user_meta_data->>'full_name')::TEXT, u.email::TEXT) as full_name,
        (u.raw_user_meta_data->>'avatar_url')::TEXT as avatar_url
    FROM 
        public.community_members cm
    JOIN 
        auth.users u ON cm.user_id = u.id
    WHERE 
        cm.community_id = p_community_id;
END;
$$;


ALTER FUNCTION "public"."get_community_member_names"("p_community_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_communities"() RETURNS TABLE("id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY SELECT cm.community_id FROM public.community_members cm WHERE cm.user_id = auth.uid();
END;
$$;


ALTER FUNCTION "public"."get_my_communities"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_community_ids"() RETURNS SETOF "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
    SELECT community_id FROM public.community_members WHERE user_id = auth.uid();
$$;


ALTER FUNCTION "public"."get_my_community_ids"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_role_weight"("p_role" "text") RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
BEGIN
  RETURN CASE
    WHEN p_role = 'owner' THEN 3
    WHEN p_role = 'admin' THEN 2
    WHEN p_role = 'member' THEN 1
    ELSE 0
  END;
END;
$$;


ALTER FUNCTION "public"."get_role_weight"("p_role" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_communities"() RETURNS TABLE("id" "uuid", "name" "text", "creator_id" "uuid", "created_at" timestamp with time zone, "community_members" "jsonb")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.name,
        c.creator_id,
        c.created_at,
        jsonb_agg(
            jsonb_build_object('role', cm.role)
        ) as community_members
    FROM public.communities c
    JOIN public.community_members cm ON c.id = cm.community_id
    WHERE cm.user_id = auth.uid()
    GROUP BY c.id;
END;
$$;


ALTER FUNCTION "public"."get_user_communities"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_community"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  INSERT INTO public.community_members (community_id, user_id, role)
  VALUES (NEW.id, NEW.creator_id, 'admin');
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_community"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_community_member"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- Check if this is the first member of the community (the creator)
    IF NOT EXISTS (SELECT 1 FROM public.community_members WHERE community_id = NEW.community_id) THEN
        NEW.role := 'owner';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_community_member"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_community_admin"("p_community_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
    AND user_id = auth.uid()
    AND role IN ('owner', 'admin') -- Owners are also super-admins
  );
END;
$$;


ALTER FUNCTION "public"."is_community_admin"("p_community_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_member_of"("p_community_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.community_members
    WHERE community_id = p_community_id
    AND user_id = auth.uid()
  );
END;
$$;


ALTER FUNCTION "public"."is_member_of"("p_community_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_on_comment"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_task_title TEXT;
    v_community_id UUID;
BEGIN
    SELECT title, community_id INTO v_task_title, v_community_id FROM public.tasks WHERE id = NEW.task_id;
    
    -- Only notify if it's a community task
    IF v_community_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, related_id)
        SELECT 
            cm.user_id, 
            'New Comment', 
            NEW.user_name || ' commented on ' || v_task_title, 
            'community_mention', 
            NEW.task_id
        FROM public.community_members cm
        WHERE cm.community_id = v_community_id AND cm.user_id != NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_on_comment"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_task_assignee"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.assignee_id IS NOT NULL AND (TG_OP = 'INSERT' OR NEW.assignee_id IS DISTINCT FROM OLD.assignee_id) THEN
    IF NEW.assignee_id != auth.uid() THEN
      INSERT INTO public.notifications (user_id, title, body, type, related_id)
      VALUES (
        NEW.assignee_id, 
        'New Task Assignment', 
        'You were assigned to: ' || NEW.title, 
        'task_assignment', 
        NEW.id
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_task_assignee"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_can_edit_task"("t_user_id" "uuid", "t_community_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_my_weight INTEGER;
  v_creator_weight INTEGER;
BEGIN
  -- Personal tasks: Only owner can edit
  IF t_community_id IS NULL THEN
    RETURN auth.uid() = t_user_id;
  END IF;

  -- Community tasks: Fetch weights
  SELECT public.get_role_weight(role) INTO v_my_weight 
    FROM public.community_members WHERE community_id = t_community_id AND user_id = auth.uid();
  SELECT public.get_role_weight(role) INTO v_creator_weight 
    FROM public.community_members WHERE community_id = t_community_id AND user_id = t_user_id;

  RETURN COALESCE(v_my_weight, 0) >= COALESCE(v_creator_weight, 0);
END;
$$;


ALTER FUNCTION "public"."user_can_edit_task"("t_user_id" "uuid", "t_community_id" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"()
);


ALTER TABLE "public"."categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."communities" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "creator_id" "uuid" DEFAULT "auth"."uid"(),
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."communities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."community_members" (
    "community_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'member'::"text",
    CONSTRAINT "community_members_role_check" CHECK (("role" = ANY (ARRAY['owner'::"text", 'admin'::"text", 'member'::"text"])))
);


ALTER TABLE "public"."community_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."feedback" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "email" "text" NOT NULL,
    "message" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."feedback" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"(),
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "type" "text" NOT NULL,
    "related_id" "uuid",
    "is_read" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "notifications_type_check" CHECK (("type" = ANY (ARRAY['task_assignment'::"text", 'due_reminder'::"text", 'task_overdue'::"text", 'community_mention'::"text"])))
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."task_comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "task_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "user_name" "text" NOT NULL,
    "comment_text" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."task_comments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tasks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "status" "text" DEFAULT 'toDo'::"text",
    "priority" "text" DEFAULT 'medium'::"text",
    "is_completed" boolean DEFAULT false NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"(),
    "community_id" "uuid",
    "category_id" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "assignees" "text"[] DEFAULT '{}'::"text"[],
    "category_ids" "text"[] DEFAULT '{}'::"text"[],
    "order" integer DEFAULT 0,
    "subtasks" "jsonb" DEFAULT '[]'::"jsonb",
    "due_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "assignee_id" "uuid",
    CONSTRAINT "tasks_priority_check" CHECK (("priority" = ANY (ARRAY['low'::"text", 'medium'::"text", 'high'::"text"]))),
    CONSTRAINT "tasks_status_check" CHECK (("status" = ANY (ARRAY['toDo'::"text", 'inProgress'::"text", 'done'::"text"])))
);


ALTER TABLE "public"."tasks" OWNER TO "postgres";


ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."communities"
    ADD CONSTRAINT "communities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."community_members"
    ADD CONSTRAINT "community_members_pkey" PRIMARY KEY ("community_id", "user_id");



ALTER TABLE ONLY "public"."feedback"
    ADD CONSTRAINT "feedback_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_comments"
    ADD CONSTRAINT "task_comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_tasks_subtasks" ON "public"."tasks" USING "gin" ("subtasks");



CREATE OR REPLACE TRIGGER "on_community_created" AFTER INSERT ON "public"."communities" FOR EACH ROW EXECUTE FUNCTION "public"."handle_new_community"();



CREATE OR REPLACE TRIGGER "on_community_member_created" BEFORE INSERT ON "public"."community_members" FOR EACH ROW EXECUTE FUNCTION "public"."handle_new_community_member"();



CREATE OR REPLACE TRIGGER "tr_cleanup_empty_communities" AFTER DELETE ON "public"."community_members" FOR EACH ROW EXECUTE FUNCTION "public"."cleanup_empty_communities"();



CREATE OR REPLACE TRIGGER "tr_notify_assignee" AFTER INSERT OR UPDATE ON "public"."tasks" FOR EACH ROW EXECUTE FUNCTION "public"."notify_task_assignee"();



CREATE OR REPLACE TRIGGER "tr_notify_on_comment" AFTER INSERT ON "public"."task_comments" FOR EACH ROW EXECUTE FUNCTION "public"."notify_on_comment"();



CREATE OR REPLACE TRIGGER "tr_tasks_updated_at" BEFORE UPDATE ON "public"."tasks" FOR EACH ROW WHEN ((("old"."title" IS DISTINCT FROM "new"."title") OR ("old"."description" IS DISTINCT FROM "new"."description") OR ("old"."status" IS DISTINCT FROM "new"."status") OR ("old"."priority" IS DISTINCT FROM "new"."priority") OR ("old"."subtasks" IS DISTINCT FROM "new"."subtasks"))) EXECUTE FUNCTION "public"."set_updated_at"();



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."communities"
    ADD CONSTRAINT "communities_creator_id_fkey" FOREIGN KEY ("creator_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."community_members"
    ADD CONSTRAINT "community_members_community_id_fkey" FOREIGN KEY ("community_id") REFERENCES "public"."communities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."community_members"
    ADD CONSTRAINT "community_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_comments"
    ADD CONSTRAINT "task_comments_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_comments"
    ADD CONSTRAINT "task_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_assignee_id_fkey" FOREIGN KEY ("assignee_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_community_id_fkey" FOREIGN KEY ("community_id") REFERENCES "public"."communities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Access comments" ON "public"."task_comments" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."tasks" "t"
  WHERE (("t"."id" = "task_comments"."task_id") AND (("t"."user_id" = "auth"."uid"()) OR "public"."is_member_of"("t"."community_id")))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."tasks" "t"
  WHERE (("t"."id" = "task_comments"."task_id") AND (("t"."user_id" = "auth"."uid"()) OR "public"."is_member_of"("t"."community_id"))))));



CREATE POLICY "Access tasks" ON "public"."tasks" TO "authenticated" USING ((("auth"."uid"() = "user_id") OR ("community_id" IN ( SELECT "public"."get_my_communities"() AS "get_my_communities")))) WITH CHECK ((("auth"."uid"() = "user_id") OR ("community_id" IN ( SELECT "public"."get_my_communities"() AS "get_my_communities"))));



CREATE POLICY "Admins can manage roles" ON "public"."community_members" FOR UPDATE TO "authenticated" USING ("public"."is_community_admin"("community_id")) WITH CHECK ("public"."is_community_admin"("community_id"));



CREATE POLICY "Admins can remove members" ON "public"."community_members" FOR DELETE TO "authenticated" USING ("public"."is_community_admin"("community_id"));



CREATE POLICY "Authenticated users can create communities" ON "public"."communities" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Authenticated users view feedback" ON "public"."feedback" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Categories are public" ON "public"."categories" FOR SELECT USING (true);



CREATE POLICY "Edit restricted tasks" ON "public"."tasks" FOR UPDATE TO "authenticated" USING ("public"."user_can_edit_task"("user_id", "community_id")) WITH CHECK ("public"."user_can_edit_task"("user_id", "community_id"));



CREATE POLICY "Enable all for owners" ON "public"."tasks" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Manage personal categories" ON "public"."categories" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Members view joined communities" ON "public"."communities" FOR SELECT USING ("internal"."check_membership"("id"));



CREATE POLICY "Public anonymous insert" ON "public"."feedback" FOR INSERT TO "anon" WITH CHECK (true);



CREATE POLICY "Users can join communities" ON "public"."community_members" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can manage their own notifications" ON "public"."notifications" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users view own memberships" ON "public"."community_members" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "View communities" ON "public"."communities" FOR SELECT TO "authenticated" USING ((("creator_id" = "auth"."uid"()) OR ("id" IN ( SELECT "public"."get_my_communities"() AS "get_my_communities"))));



CREATE POLICY "View personal and team tasks" ON "public"."tasks" FOR SELECT USING ((("auth"."uid"() = "user_id") OR (("community_id" IS NOT NULL) AND "internal"."check_membership"("community_id"))));



CREATE POLICY "View team members" ON "public"."community_members" FOR SELECT TO "authenticated" USING ((("user_id" = "auth"."uid"()) OR ("community_id" IN ( SELECT "public"."get_my_communities"() AS "get_my_communities"))));



ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."communities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."community_members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."feedback" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."task_comments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tasks" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



REVOKE ALL ON FUNCTION "public"."handle_new_community"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "public"."rls_auto_enable"() FROM PUBLIC;



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."categories" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."communities" TO "anon";
GRANT ALL ON TABLE "public"."communities" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."communities" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."community_members" TO "anon";
GRANT ALL ON TABLE "public"."community_members" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."community_members" TO "service_role";



GRANT ALL ON TABLE "public"."feedback" TO "anon";
GRANT ALL ON TABLE "public"."feedback" TO "authenticated";
GRANT ALL ON TABLE "public"."feedback" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."task_comments" TO "anon";
GRANT ALL ON TABLE "public"."task_comments" TO "authenticated";
GRANT ALL ON TABLE "public"."task_comments" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tasks" TO "anon";
GRANT ALL ON TABLE "public"."tasks" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tasks" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "service_role";







