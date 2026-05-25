-- v0.5.226-coach-setup.sql
-- Set Cath's PRIMARY subscription to 'coach' type
-- Run in: App Supabase → SQL Editor
-- URL: https://eekefsuaefgpqmjdyniy.supabase.co
--
-- IMPORTANT: Run v0.5.228-diagnostic.sql first to find the correct subscription ID.
-- This should ONLY update Cath's own "Coach Account" subscription (the one with
-- Coach4U / Coach4U Development / ABMS businesses).
-- Do NOT run this on the SARUBA or IAS client subscriptions — they should stay 'business'.
--
-- Step 1: Identify the correct subscription ID using the diagnostic.
--         Run this SELECT to find it:
SELECT s.id, s.name, s.subscription_type, u.email
FROM public.subscriptions s
JOIN public.users u ON u.id = s.owner_user_id
WHERE u.email = 'cath@coach4u.com.au'
ORDER BY s.created_at;

-- Step 2: Copy the id of Cath's primary (coach) subscription from the result above,
--         paste it in place of 'PASTE-SUBSCRIPTION-ID-HERE', then run:
/*
UPDATE public.subscriptions
SET
  subscription_type   = 'coach',
  included_businesses = 99
WHERE id = 'PASTE-SUBSCRIPTION-ID-HERE';
*/

-- Alternative: If Cath only has ONE subscription (SARUBA/IAS not yet created),
-- the safe version below is OK — but verify with the SELECT first:
/*
UPDATE public.subscriptions
SET
  subscription_type   = 'coach',
  included_businesses = 99
WHERE owner_user_id = (
  SELECT id FROM public.users WHERE email = 'cath@coach4u.com.au' LIMIT 1
)
AND LOWER(name) NOT LIKE '%saruba%'
AND LOWER(name) NOT LIKE '%ias%';
*/
