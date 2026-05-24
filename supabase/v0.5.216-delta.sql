-- ============================================================
-- v0.5.216 — Members can add to Issues List + Future Issues List
-- ============================================================
-- User: "I would want team members to be able to add to an area in
-- future issues list. But not delete. And also keep adding to the
-- issues list but not delete."
--
-- Current state:
--   • Members can READ all issues (already in place)
--   • Admins + coaches can INSERT / UPDATE / DELETE any issue
--   • Members CAN'T write anything
--
-- New state:
--   • Members can INSERT issues with category IN ('current', 'future')
--   • Members STILL can't UPDATE or DELETE (only admins + coaches)
--   • Members CAN'T insert into 'yearly' category (the 12-month-issues
--     bucket — that's for annual planning sessions, not day-to-day)
--   • Admins + coaches retain full write on any category
--
-- Implementation:
--   • Keep the "admins write issues" FOR ALL policy unchanged.
--   • Add a new INSERT-only policy for members on current+future.
--   • Postgres combines policies with OR for the same operation, so:
--       - Admin/coach trying INSERT → admins-write policy passes
--       - Member trying INSERT current/future → new policy passes
--       - Member trying INSERT yearly → both policies fail → 403
--       - Member trying UPDATE/DELETE → only FOR ALL applies → 403
-- ============================================================

DROP POLICY IF EXISTS "members add issues" ON public.issues;
CREATE POLICY "members add issues" ON public.issues
  FOR INSERT
  WITH CHECK (
    organisation_id IN (SELECT public.user_org_ids(auth.uid()))
    AND category IN ('current', 'future')
  );

NOTIFY pgrst, 'reload schema';
