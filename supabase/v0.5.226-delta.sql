-- v0.5.226-delta.sql
-- Fix included_businesses default: schema had DEFAULT 1, Starter plan is 2
-- Run in: App Supabase → SQL Editor
-- URL: https://eekefsuaefgpqmjdyniy.supabase.co

-- 1. Change the column default to 2 (matches Starter plan pricing)
ALTER TABLE public.subscriptions
  ALTER COLUMN included_businesses SET DEFAULT 2;

-- 2. Bump any existing subscriptions still on the wrong default of 1
--    (1 was never a real plan tier — Starter always included 2 businesses)
UPDATE public.subscriptions
SET included_businesses = 2
WHERE included_businesses = 1;
