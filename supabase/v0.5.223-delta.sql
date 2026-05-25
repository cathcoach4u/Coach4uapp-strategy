-- v0.5.223-delta.sql
-- Enforce business plan limit inside bootstrap_organisation RPC
-- Run in: App Supabase → SQL Editor
-- URL: https://eekefsuaefgpqmjdyniy.supabase.co
--
-- Adds a plan-limit check so clients cannot create more businesses
-- than their subscription allows (included_businesses column).
-- The UI already blocks the button; this is the hard database guard.

CREATE OR REPLACE FUNCTION public.bootstrap_organisation(
  business_name text,
  subscription_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid               uuid := auth.uid();
  v_subscription_id uuid := subscription_id;
  v_organisation_id uuid;
  v_limit           integer;
  v_count           integer;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF business_name IS NULL OR length(trim(business_name)) = 0 THEN
    RAISE EXCEPTION 'Business name is required';
  END IF;

  IF v_subscription_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.subscriptions
      WHERE id = v_subscription_id AND owner_user_id = uid
    ) THEN
      RAISE EXCEPTION 'Subscription not found or not owned by you';
    END IF;

    -- Enforce plan limit
    SELECT COALESCE(included_businesses, 2) INTO v_limit
    FROM public.subscriptions
    WHERE id = v_subscription_id;

    SELECT COUNT(*) INTO v_count
    FROM public.organisations
    WHERE organisations.subscription_id = v_subscription_id;

    IF v_count >= v_limit THEN
      RAISE EXCEPTION
        'Plan limit reached — you have % of % businesses allowed. Contact your coach to upgrade.',
        v_count, v_limit;
    END IF;
  ELSE
    SELECT id INTO v_subscription_id
    FROM public.subscriptions
    WHERE owner_user_id = uid
    ORDER BY created_at ASC
    LIMIT 1;
    IF v_subscription_id IS NULL THEN
      INSERT INTO public.subscriptions (owner_user_id)
      VALUES (uid)
      RETURNING id INTO v_subscription_id;
    END IF;
  END IF;

  INSERT INTO public.organisations (subscription_id, name)
  VALUES (v_subscription_id, trim(business_name))
  RETURNING id INTO v_organisation_id;

  INSERT INTO public.team_members (
    organisation_id, user_id, role, status, joined_at
  ) VALUES (
    v_organisation_id, uid, 'admin', 'active', now()
  );

  RETURN v_organisation_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.bootstrap_organisation(text, uuid) TO authenticated;
