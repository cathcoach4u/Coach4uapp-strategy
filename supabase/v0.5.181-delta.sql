-- ============================================================
-- v0.5.181 — Add five_year goal column to targets
-- ============================================================
-- Simplifies the Targets worksheet to one text box per timeframe.
-- New column for the 5-year goal that didn't exist before. The
-- existing three_year_date / three_year_revenue / three_year_profit
-- and one_year_date / one_year_revenue / one_year_profit columns
-- stay in the schema (preserves existing data) but the worksheet UI
-- no longer edits them.
-- ============================================================

ALTER TABLE public.targets
  ADD COLUMN IF NOT EXISTS five_year text;

-- Children inherit five_year too (same RLS family as the other targets columns)
-- — the existing "children read parent targets" SELECT policy already covers
-- the whole row, so no policy change needed.

NOTIFY pgrst, 'reload schema';
