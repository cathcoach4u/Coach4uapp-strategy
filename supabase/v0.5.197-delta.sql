-- ============================================================
-- v0.5.197 — Children inherit parent's planning cadence
-- ============================================================
-- Mirrors the v0.5.145 inheritance pattern used for core_values /
-- core_focus / targets: an additive SELECT policy that lets a member
-- of a child organisation read its parent's business_cadence row.
--
-- A user can SELECT a business_cadence row if its organisation_id is
-- the parent_organisation_id of any org they're an active member of.
--
-- UI flow:
--   • Child with no own row + parent has one  →  inherited (read-only)
--   • Child clicks "Override locally"          →  snapshot parent's
--                                                  row into the child's
--                                                  own row, then edit.
--   • Child clicks "Revert to parent"          →  delete own row,
--                                                  fall back to parent.
--
-- No new tables, no new columns. The existing INSERT/UPDATE/DELETE
-- policies still require admin+coach role on the row's org, so the
-- new SELECT policy is purely additive and read-only.
-- ============================================================

DROP POLICY IF EXISTS "children read parent cadence" ON public.business_cadence;
CREATE POLICY "children read parent cadence" ON public.business_cadence
  FOR SELECT
  USING (
    organisation_id IN (
      SELECT parent_organisation_id
      FROM public.organisations
      WHERE id IN (SELECT public.user_org_ids(auth.uid()))
        AND parent_organisation_id IS NOT NULL
    )
  );

NOTIFY pgrst, 'reload schema';
