-- v0.5.244-delta.sql
-- Allow active team members to read the email + membership_status of co-members
-- in the same organisations. Without this, account-users.html cannot show
-- identifying info (email) for team members who have already signed up and had
-- their invited_email cleared by the link_pending_invites trigger.
--
-- Safe: a user can only see emails of people sharing at least one active
-- organisation membership with them. No cross-account leakage.

DROP POLICY IF EXISTS "users can see co-members" ON public.users;

CREATE POLICY "users can see co-members"
ON public.users FOR SELECT
USING (
  -- always allow reading your own row
  id = auth.uid()
  OR
  -- allow reading any user who is an active member of an org you are also active in
  id IN (
    SELECT DISTINCT tm2.user_id
    FROM   public.team_members tm1
    JOIN   public.team_members tm2
           ON tm1.organisation_id = tm2.organisation_id
    WHERE  tm1.user_id = auth.uid()
      AND  tm1.status  = 'active'
      AND  tm2.status  = 'active'
      AND  tm2.user_id IS NOT NULL
  )
);
