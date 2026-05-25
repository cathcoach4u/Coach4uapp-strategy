-- v0.5.226-coach-setup.sql
-- Set Cath's subscription to 'coach' type
-- Run in: App Supabase → SQL Editor
-- URL: https://eekefsuaefgpqmjdyniy.supabase.co
--
-- This moves Cath's card from Business Subscriptions → Coaches section
-- in admin.html, and removes the business-count limit (coaches are exempt).

UPDATE public.subscriptions
SET
  subscription_type   = 'coach',
  included_businesses = 99          -- effectively unlimited for a coach account
WHERE owner_user_id = (
  SELECT id FROM public.users
  WHERE email = 'cath@coach4u.com.au'
  LIMIT 1
);
