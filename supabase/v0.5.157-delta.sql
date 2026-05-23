-- ============================================================
-- v0.5.157 — Guard delete_business against deleting parents with children
-- ============================================================
-- A parent business with at least one child (i.e., other org rows pointing
-- to it via parent_organisation_id) cannot be deleted. The owner must
-- unlink or delete the children first.
--
-- Replaces the existing delete_business RPC. Everything else stays the same:
--   - admin role required
--   - subscription ownership required
--   - cascades children data via the existing ON DELETE CASCADE on org_id FKs
-- ============================================================

CREATE OR REPLACE FUNCTION public.delete_business(business_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid             uuid := auth.uid();
  v_subscription  uuid;
  v_child_count   int;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF business_id IS NULL THEN
    RAISE EXCEPTION 'business_id is required';
  END IF;

  -- Caller must be admin of this org
  IF NOT EXISTS (
    SELECT 1 FROM public.team_members
    WHERE organisation_id = business_id
      AND user_id = uid
      AND role = 'admin'
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Only admins can delete this business';
  END IF;

  -- Caller must also own the subscription that owns this org
  SELECT subscription_id INTO v_subscription
  FROM public.organisations
  WHERE id = business_id;

  IF v_subscription IS NULL THEN
    RAISE EXCEPTION 'Business not found';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.subscriptions
    WHERE id = v_subscription
      AND owner_user_id = uid
  ) THEN
    RAISE EXCEPTION 'Only the account owner can delete a business';
  END IF;

  -- v0.5.157 — refuse if this business is still a parent of others
  SELECT COUNT(*) INTO v_child_count
  FROM public.organisations
  WHERE parent_organisation_id = business_id;

  IF v_child_count > 0 THEN
    RAISE EXCEPTION 'Cannot delete this business while it is the parent of % child business(es). Unlink or delete the children first.', v_child_count;
  END IF;

  DELETE FROM public.organisations WHERE id = business_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_business(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
