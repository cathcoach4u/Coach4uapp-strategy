-- v0.5.227-delta.sql
-- Link coach account to client subscriptions
-- Run in: App Supabase → SQL Editor
-- URL: https://eekefsuaefgpqmjdyniy.supabase.co
--
-- (1) Adds RLS policy so any team member can read the subscription their
--     organisation belongs to — needed for the coach account switcher.
-- (2) Adds Cath as a 'coach' team member to SARUBA's and IAS's organisations.

-- 1. New subscriptions RLS policy: team members can read their org's subscription
--    (currently only the owner can read — coaches couldn't load client account names)
DROP POLICY IF EXISTS "team members read their org subscription" ON public.subscriptions;
CREATE POLICY "team members read their org subscription" ON public.subscriptions
  FOR SELECT USING (
    id IN (
      SELECT DISTINCT o.subscription_id
      FROM public.organisations o
      WHERE o.id IN (SELECT public.user_org_ids(auth.uid()))
    )
  );

-- 2. Add Cath as coach to SARUBA's and IAS's organisations
--    Matches on subscription name (case-insensitive LIKE).
--    Run the diagnostic SELECT below first to confirm the subscription names:
--
--    SELECT s.id, s.name, u.email FROM subscriptions s
--    JOIN users u ON u.id = s.owner_user_id
--    ORDER BY s.created_at;
--
DO $$
DECLARE
  v_cath_id uuid;
  v_inserted int := 0;
BEGIN
  SELECT id INTO v_cath_id FROM public.users
  WHERE email = 'cath@coach4u.com.au' LIMIT 1;

  IF v_cath_id IS NULL THEN
    RAISE EXCEPTION 'Coach user not found — check email address';
  END IF;

  INSERT INTO public.team_members (organisation_id, user_id, role, status, joined_at)
  SELECT o.id, v_cath_id, 'coach', 'active', now()
  FROM public.organisations o
  JOIN public.subscriptions s ON s.id = o.subscription_id
  WHERE (LOWER(s.name) LIKE '%saruba%' OR LOWER(s.name) LIKE '%ias%')
    AND s.owner_user_id != v_cath_id
    AND NOT EXISTS (
      SELECT 1 FROM public.team_members tm
      WHERE tm.organisation_id = o.id AND tm.user_id = v_cath_id
    );

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  RAISE NOTICE 'Inserted % coach team_member row(s) for Cath', v_inserted;
END $$;
