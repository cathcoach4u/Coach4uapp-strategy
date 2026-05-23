-- ============================================================
-- v0.5.211 — Quarterly sessions: parity with annual sessions
-- ============================================================
-- Annual sessions got `notes`, `external_links`, and `commitments`
-- columns in v0.5.131 so the workspace could capture decisions,
-- recording links, and per-leader commitments. Quarterly sessions
-- still only had `attendance` + `areas_completed` — sparse compared
-- to the annual workspace and a downgrade in fidelity for the
-- quarterly review.
--
-- This migration adds the same 3 nullable columns to
-- `quarterly_sessions` so the UI can render the matching blocks:
--   • notes           — free-form session notes / cascading messages
--   • external_links  — JSON array of {label, url} pairs
--   • commitments     — JSON array of {name, commitment} pairs
--
-- All nullable / default to '[]' so existing rows keep working.
-- No RLS change — the existing quarterly_sessions policies cover
-- the new columns automatically.
-- ============================================================

ALTER TABLE public.quarterly_sessions
  ADD COLUMN IF NOT EXISTS notes          text,
  ADD COLUMN IF NOT EXISTS external_links jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS commitments    jsonb NOT NULL DEFAULT '[]'::jsonb;

NOTIFY pgrst, 'reload schema';
