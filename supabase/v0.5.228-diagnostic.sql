-- v0.5.228-diagnostic.sql
-- Diagnostic: Find the current state of subscriptions and organisations
-- Run in: App Supabase → SQL Editor
-- URL: https://eekefsuaefgpqmjdyniy.supabase.co
--
-- PURPOSE: Find out why SARUBA and IAS are not appearing in Cath's account switcher.
--
-- The account switcher shows all subscriptions where owner_user_id = Cath's user ID.
-- SARUBA and IAS should be owned by Cath — she manages both, they have no separate login.
-- Run the queries below in order. Share the results to diagnose the problem.

-- ── 1. Confirm Cath's user ID ────────────────────────────────────────────────
SELECT id, email, membership_status
FROM public.users
WHERE LOWER(email) LIKE '%cath%' OR LOWER(email) LIKE '%coach4u%'
ORDER BY email;

-- ── 2. All subscriptions and their owners ────────────────────────────────────
-- Expected: 3 rows all owned by cath@coach4u.com.au:
--   (1) Coach4U / coach account  (subscription_type = 'coach')
--   (2) SARUBA                   (subscription_type = 'business' or similar)
--   (3) IAS                      (subscription_type = 'business' or similar)
-- If SARUBA/IAS are missing or show a different owner_email, see the fix below.
SELECT
  s.id,
  s.name                    AS subscription_name,
  s.subscription_type,
  s.status,
  s.included_businesses,
  s.created_at,
  u.email                   AS owner_email
FROM public.subscriptions s
LEFT JOIN public.users u ON u.id = s.owner_user_id
ORDER BY s.created_at;

-- ── 3. All organisations grouped by subscription ─────────────────────────────
-- Expected for IAS subscription: IASHQ (parent) + IAS General + IAS Life + IAS Outsourcing
-- Expected for SARUBA subscription: SARUBA businesses
SELECT
  o.id                          AS org_id,
  o.name                        AS org_name,
  o.parent_organisation_id,
  s.id                          AS sub_id,
  s.name                        AS sub_name,
  u.email                       AS owner_email
FROM public.organisations o
JOIN public.subscriptions s ON s.id = o.subscription_id
LEFT JOIN public.users u ON u.id = s.owner_user_id
ORDER BY s.created_at, o.sort_order;

-- ── 4. FIX: If SARUBA/IAS subscriptions exist but are owned by the wrong user ─
--
-- If query 2 shows SARUBA/IAS rows with a DIFFERENT owner_email (not cath@coach4u.com.au),
-- run this UPDATE to fix ownership. SARUBA/IAS have no separate logins — Cath owns them.
--
-- ONLY run this if the diagnostic confirms the wrong owner_user_id.
/*
UPDATE public.subscriptions
SET owner_user_id = (
  SELECT id FROM public.users WHERE email = 'cath@coach4u.com.au' LIMIT 1
)
WHERE (LOWER(name) LIKE '%saruba%' OR LOWER(name) LIKE '%ias%')
  AND owner_user_id != (
    SELECT id FROM public.users WHERE email = 'cath@coach4u.com.au' LIMIT 1
  );
*/

-- ── 5. FIX: If SARUBA/IAS subscriptions do NOT exist at all ──────────────────
--
-- If query 2 shows only 1 subscription (Cath's coach account), the client subscriptions
-- were deleted. Recreate them using the "New client account" button in index.html
-- (the create_client_account RPC creates subscription + first business + team member).
--
-- Or, if you prefer SQL directly (adjust names/IDs to match what previously existed):
/*
-- Step 1: Create the SARUBA subscription
INSERT INTO public.subscriptions (owner_user_id, name, subscription_type, status, included_businesses)
VALUES (
  (SELECT id FROM public.users WHERE email = 'cath@coach4u.com.au' LIMIT 1),
  'SARUBA',
  'business',
  'active',
  2
);

-- Step 2: Create the IAS subscription (then add orgs via bootstrap_organisation RPC)
INSERT INTO public.subscriptions (owner_user_id, name, subscription_type, status, included_businesses)
VALUES (
  (SELECT id FROM public.users WHERE email = 'cath@coach4u.com.au' LIMIT 1),
  'IAS',
  'business',
  'active',
  4
);
*/
