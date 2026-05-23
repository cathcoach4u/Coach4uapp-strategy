-- ============================================================
-- v0.5.152 — Invoicing / billing fields + RLS hotfix on team_members
-- ============================================================
-- Two changes:
--
-- (1) ADD COLUMN billing_email, billing_address, billing_tax_id to
--     subscriptions so the Account Setup tab can capture invoicing info.
--     RLS unchanged — the existing "owner updates own subscription"
--     policy already lets the account owner write any column.
--
-- (2) HOTFIX an RLS policy on team_members. The "invited user accepts
--     own invite" policy did:
--       USING (invited_email = (SELECT email FROM auth.users WHERE id = auth.uid()))
--     ...which fails with "permission denied for table users" because
--     the authenticated role doesn't have SELECT on auth.users in
--     current Supabase. Replace with auth.jwt() ->> 'email' which is
--     a JWT claim — no table read needed.
-- ============================================================

-- (1) Billing columns
ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS billing_email   text,
  ADD COLUMN IF NOT EXISTS billing_address text,
  ADD COLUMN IF NOT EXISTS billing_tax_id  text;

-- (2) RLS hotfix — invited-user policy without touching auth.users
DROP POLICY IF EXISTS "invited user accepts own invite" ON public.team_members;
CREATE POLICY "invited user accepts own invite" ON public.team_members
  FOR UPDATE
  USING (
    invited_email IS NOT NULL
    AND lower(invited_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  WITH CHECK (user_id = auth.uid() AND status = 'active');

NOTIFY pgrst, 'reload schema';
