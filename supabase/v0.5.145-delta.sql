-- ============================================================
-- v0.5.145 — Parent / child business relationships
-- ============================================================
-- A business can have ONE parent (nullable). A parent can have many children.
-- Flat tree only — depth 1. (The UI prevents picking a business that itself
-- has a parent, so the chain never goes deeper than parent→child.)
--
-- Children inherit selected strategy data from their parent unless they have
-- their own row in the relevant table.  Phase 1 wires this up for core_values;
-- the RLS policies for core_focus + targets are added here too so phases 2 + 3
-- don't need another migration.
--
-- Apply order (idempotent):
--   1. ALTER organisations + add the column + self-parent CHECK + index
--   2. Add the three "children read parent <table>" SELECT policies (additive)
--   3. NOTIFY pgrst to bust the PostgREST schema cache so the new column shows up immediately
-- ============================================================

ALTER TABLE public.organisations
  ADD COLUMN IF NOT EXISTS parent_organisation_id uuid
    REFERENCES public.organisations(id) ON DELETE SET NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'organisations_no_self_parent'
  ) THEN
    ALTER TABLE public.organisations
      ADD CONSTRAINT organisations_no_self_parent CHECK (id <> parent_organisation_id);
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS organisations_parent_idx
  ON public.organisations(parent_organisation_id);

-- ──────────────────────────────────────────────────────────────
-- RLS — children can READ their parent's strategy data
-- Additive policies; existing "members read X" policies still cover own-org reads.
-- WRITE policies are unchanged — a child still can't write the parent's tables.
-- ──────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "children read parent core_values" ON public.core_values;
CREATE POLICY "children read parent core_values" ON public.core_values
  FOR SELECT USING (
    organisation_id IN (
      SELECT parent_organisation_id FROM public.organisations
      WHERE id IN (SELECT public.user_org_ids(auth.uid()))
        AND parent_organisation_id IS NOT NULL
    )
  );

DROP POLICY IF EXISTS "children read parent core_focus" ON public.core_focus;
CREATE POLICY "children read parent core_focus" ON public.core_focus
  FOR SELECT USING (
    organisation_id IN (
      SELECT parent_organisation_id FROM public.organisations
      WHERE id IN (SELECT public.user_org_ids(auth.uid()))
        AND parent_organisation_id IS NOT NULL
    )
  );

DROP POLICY IF EXISTS "children read parent targets" ON public.targets;
CREATE POLICY "children read parent targets" ON public.targets
  FOR SELECT USING (
    organisation_id IN (
      SELECT parent_organisation_id FROM public.organisations
      WHERE id IN (SELECT public.user_org_ids(auth.uid()))
        AND parent_organisation_id IS NOT NULL
    )
  );

NOTIFY pgrst, 'reload schema';
