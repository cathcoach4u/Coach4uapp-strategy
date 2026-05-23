-- ============================================================
-- v0.5.193 — Cadence: last-annual + 2nd day per session
-- ============================================================
-- Two adjustments to the v0.5.192 business_cadence table:
--
--   • Add `last_annual_planning_date` — when the most recent annual
--     planning session was held. This now anchors the current plan
--     year on the One-Page Plan (falling back to annual_planning_date,
--     then to the calendar year, if not set).
--
--   • Add a 2nd-day date for every session in case the team runs
--     it across two days. Optional — if blank, the session is a
--     single-day session.
--
-- All new columns are nullable. The existing RLS policies on
-- business_cadence (from v0.5.192) cover the new columns automatically.
-- ============================================================

ALTER TABLE public.business_cadence
  ADD COLUMN IF NOT EXISTS last_annual_planning_date date,
  ADD COLUMN IF NOT EXISTS annual_planning_date_2     date,
  ADD COLUMN IF NOT EXISTS q1_session_date_2          date,
  ADD COLUMN IF NOT EXISTS q2_session_date_2          date,
  ADD COLUMN IF NOT EXISTS q3_session_date_2          date,
  ADD COLUMN IF NOT EXISTS q4_session_date_2          date;

NOTIFY pgrst, 'reload schema';
