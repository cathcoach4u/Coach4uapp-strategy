-- ============================================================
-- v0.5.183 — Split issues into 3 categories (yearly / current / future)
-- ============================================================
-- The single Issues view becomes 3 cards on Operations:
--   • Yearly Issues       — long-horizon planning items
--   • Issues List         — this week / this quarter (the default)
--   • Future Issues List  — backlog of things to address later
--
-- All existing rows are categorised as 'current' (the default) so the
-- Issues List card on day-1 looks identical to today's Issues view.
-- ============================================================

ALTER TABLE public.issues
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'current';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'issues_category_check'
  ) THEN
    ALTER TABLE public.issues
      ADD CONSTRAINT issues_category_check
      CHECK (category IN ('yearly', 'current', 'future'));
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS issues_org_category_idx
  ON public.issues(organisation_id, category);

NOTIFY pgrst, 'reload schema';
