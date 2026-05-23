-- ============================================================
-- v0.5.192 — Planning Cadence: per-business rhythm settings
-- ============================================================
-- A single row per organisation that captures WHEN the team runs
-- their planning rhythm:
--   • annual_planning_date  — the next annual planning session date.
--                              Also acts as the plan-year anchor
--                              (drives the date label on the one-page plan).
--   • q1..q4_session_date   — the 4 quarterly session dates.
--                              Nullable: leave any blank if not used.
--   • weekly_meeting_day    — day-of-week the weekly team meeting runs.
--   • weekly_meeting_time   — time-of-day the weekly team meeting runs.
--
-- Read by any active member of the org; written by admins + coaches
-- (same pattern as the rest of the org-scoped tables).
-- ============================================================

CREATE TABLE IF NOT EXISTS public.business_cadence (
  organisation_id      uuid PRIMARY KEY
                       REFERENCES public.organisations(id) ON DELETE CASCADE,
  annual_planning_date date,
  q1_session_date      date,
  q2_session_date      date,
  q3_session_date      date,
  q4_session_date      date,
  weekly_meeting_day   text CHECK (weekly_meeting_day IS NULL
                                   OR weekly_meeting_day IN
                                      ('monday','tuesday','wednesday',
                                       'thursday','friday','saturday','sunday')),
  weekly_meeting_time  time,
  updated_at           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.business_cadence ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "members read cadence" ON public.business_cadence;
CREATE POLICY "members read cadence" ON public.business_cadence
  FOR SELECT
  USING (organisation_id IN (SELECT public.user_org_ids(auth.uid())));

DROP POLICY IF EXISTS "admins write cadence" ON public.business_cadence;
CREATE POLICY "admins write cadence" ON public.business_cadence
  FOR ALL
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())))
  WITH CHECK (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));

NOTIFY pgrst, 'reload schema';
