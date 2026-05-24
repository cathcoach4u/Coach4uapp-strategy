-- =============================================================
-- Your Business Coach — Supabase Schema (v0.5.79)
-- =============================================================
-- Per locked architecture (CLAUDE.md):
--   • Account-level subscriptions (1 buyer = 1 subscription, N orgs)
--   • Team-scoped data (every domain row belongs to an organisation)
--   • 2 roles: admin (read+write) / member (read-only + check-in submit)
--   • Global user pool — 1 person in 3 orgs = 1 seat
--   • Team check-in results visible to ALL active members of the org
--
-- Pricing model (v0.5.78):
--   • Base: $150/mo = 1 business + 3 users
--   • Each additional business: $75/mo
--   • Each additional user beyond 3: $60/mo
--
-- HOW TO APPLY
--   1. Open the Supabase SQL editor for the project
--      (https://eekefsuaefgpqmjdyniy.supabase.co).
--   2. Paste this entire file. Click Run.
--   3. Confirm no errors. If you see "already exists" errors, the
--      DROP block at the top should have cleared everything first.
--   4. Test: as a signed-in user, INSERT into `subscriptions` then
--      `organisations` then `team_members` (admin role) and confirm
--      RLS lets you SELECT them back.
-- =============================================================


-- =============================================================
-- 0. DROP old / incompatible tables (clean slate)
-- =============================================================

DROP TABLE IF EXISTS public.gwc_ratings CASCADE;
DROP TABLE IF EXISTS public.values_ratings CASCADE;
DROP TABLE IF EXISTS public.members CASCADE;
DROP TABLE IF EXISTS public.seats CASCADE;
DROP TABLE IF EXISTS public.meeting_todos CASCADE;
DROP TABLE IF EXISTS public.meeting_headlines CASCADE;
DROP TABLE IF EXISTS public.meetings CASCADE;
DROP TABLE IF EXISTS public.issues CASCADE;
DROP TABLE IF EXISTS public.scorecard_entries CASCADE;
DROP TABLE IF EXISTS public.scorecard_metrics CASCADE;
DROP TABLE IF EXISTS public.rocks CASCADE;
DROP TABLE IF EXISTS public.vto CASCADE;
DROP TABLE IF EXISTS public.user_modules CASCADE;
DROP TABLE IF EXISTS public.organisations CASCADE;
DROP TABLE IF EXISTS public.businesses CASCADE;

-- Also drop the NEW tables in case this script is re-run
DROP TABLE IF EXISTS public.team_checkins CASCADE;
DROP TABLE IF EXISTS public.quarterly_sessions CASCADE;
DROP TABLE IF EXISTS public.annual_sessions CASCADE;
DROP TABLE IF EXISTS public.leadership_team_members CASCADE;
DROP TABLE IF EXISTS public.marketing_strategy CASCADE;
DROP TABLE IF EXISTS public.targets CASCADE;
DROP TABLE IF EXISTS public.core_focus CASCADE;
DROP TABLE IF EXISTS public.core_values CASCADE;
DROP TABLE IF EXISTS public.team_members CASCADE;
DROP TABLE IF EXISTS public.subscriptions CASCADE;
DROP FUNCTION IF EXISTS public.user_org_ids(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.user_admin_org_ids(uuid) CASCADE;
-- KEEP public.users — it's the auth membership gate, used everywhere

-- Ensure public.users still has the expected shape
-- (already exists; safe to re-run)
CREATE TABLE IF NOT EXISTS public.users (
  id                uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email             text NOT NULL,
  membership_status text NOT NULL DEFAULT 'inactive',
  name              text
);
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can read own row" ON public.users;
CREATE POLICY "Users can read own row" ON public.users
  FOR SELECT USING (auth.uid() = id);


-- =============================================================
-- 1. ACCOUNT LEVEL — subscriptions, organisations, team_members
-- =============================================================

CREATE TABLE public.subscriptions (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id          uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name                   text,                              -- the account / parent company name (e.g. "SARUBA")
  status                 text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','past_due','canceled','trial')),
  seat_count             int  NOT NULL DEFAULT 3,        -- included users in the base plan
  included_businesses    int  NOT NULL DEFAULT 1,        -- usually 1
  stripe_customer_id     text,
  stripe_subscription_id text,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX subscriptions_owner_idx ON public.subscriptions(owner_user_id);

CREATE TABLE public.organisations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id uuid NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
  name            text NOT NULL,
  sort_order      int  NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX organisations_sub_sort_idx
  ON public.organisations(subscription_id, sort_order);
CREATE INDEX organisations_subscription_idx ON public.organisations(subscription_id);

CREATE TABLE public.team_members (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL REFERENCES public.organisations(id) ON DELETE CASCADE,
  user_id         uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  invited_email   text,                              -- set on invite, before user signs up
  role            text NOT NULL DEFAULT 'member'
                  CHECK (role IN ('admin','coach','member')),
  status          text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','active','removed')),
  display_name    text,
  invited_at      timestamptz NOT NULL DEFAULT now(),
  joined_at       timestamptz
);
-- One row per (org, user) once they've joined
CREATE UNIQUE INDEX team_members_org_user_uq
  ON public.team_members(organisation_id, user_id)
  WHERE user_id IS NOT NULL;
-- Pending invites are tracked by email
CREATE UNIQUE INDEX team_members_org_email_uq
  ON public.team_members(organisation_id, invited_email)
  WHERE invited_email IS NOT NULL AND status = 'pending';
CREATE INDEX team_members_user_idx ON public.team_members(user_id) WHERE user_id IS NOT NULL;


-- =============================================================
-- 2. RLS helper functions
-- =============================================================

-- All orgs the user has active membership in
CREATE OR REPLACE FUNCTION public.user_org_ids(uid uuid)
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT organisation_id FROM public.team_members
  WHERE user_id = uid AND status = 'active'
$$;

-- Orgs where the user is an active admin
CREATE OR REPLACE FUNCTION public.user_admin_org_ids(uid uuid)
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT organisation_id FROM public.team_members
  WHERE user_id = uid AND role IN ('admin','coach') AND status = 'active'
$$;


-- =============================================================
-- 3. STRATEGY domain — 1 row per org per worksheet
-- =============================================================

CREATE TABLE public.core_values (
  organisation_id uuid PRIMARY KEY REFERENCES public.organisations(id) ON DELETE CASCADE,
  value_1 text, value_2 text, value_3 text, value_4 text,
  value_5 text, value_6 text, value_7 text, value_8 text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.core_focus (
  organisation_id uuid PRIMARY KEY REFERENCES public.organisations(id) ON DELETE CASCADE,
  purpose         text,
  niche           text,
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.targets (
  organisation_id    uuid PRIMARY KEY REFERENCES public.organisations(id) ON DELETE CASCADE,
  ten_year           text,
  three_year_date    text,
  three_year_revenue text,
  three_year_profit  text,
  three_year_desc    text,
  one_year_date      text,
  one_year_revenue   text,
  one_year_profit    text,
  one_year_goals     text,
  updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.marketing_strategy (
  organisation_id uuid PRIMARY KEY REFERENCES public.organisations(id) ON DELETE CASCADE,
  target_market   text,
  uniques         text,
  proven_process  text,
  guarantee       text,
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.leadership_team_members (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id  uuid NOT NULL REFERENCES public.organisations(id) ON DELETE CASCADE,
  name             text NOT NULL DEFAULT '',
  role             text NOT NULL DEFAULT '',
  responsibilities text NOT NULL DEFAULT '',
  placeholder      boolean NOT NULL DEFAULT false,
  sort_order       int NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX leadership_team_org_idx
  ON public.leadership_team_members(organisation_id, sort_order);

-- v0.5.117: monthly financials feeding the one-page-plan
CREATE TABLE public.financial_periods (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id  uuid NOT NULL REFERENCES public.organisations(id) ON DELETE CASCADE,
  period           date NOT NULL,            -- first day of the month
  revenue          numeric,
  expenses         numeric,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organisation_id, period)
);
CREATE INDEX financial_periods_org_period_idx
  ON public.financial_periods(organisation_id, period);


-- =============================================================
-- 4. OPERATIONS domain
-- =============================================================

CREATE TABLE public.scorecard_metrics (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id  uuid NOT NULL REFERENCES public.organisations(id) ON DELETE CASCADE,
  name             text NOT NULL,
  owner            text,
  goal             numeric,
  measurement_type text NOT NULL DEFAULT 'count'
                   CHECK (measurement_type IN ('count','currency','percentage','score')),
  sort_order       int NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX scorecard_metrics_org_idx
  ON public.scorecard_metrics(organisation_id, sort_order);

CREATE TABLE public.scorecard_entries (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_id  uuid NOT NULL REFERENCES public.scorecard_metrics(id) ON DELETE CASCADE,
  week_date  date NOT NULL,
  value      numeric,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (metric_id, week_date)
);
CREATE INDEX scorecard_entries_metric_week_idx
  ON public.scorecard_entries(metric_id, week_date DESC);

CREATE TABLE public.rocks (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL REFERENCES public.organisations(id) ON DELETE CASCADE,
  description     text NOT NULL,
  owner           text,
  status          text NOT NULL DEFAULT 'on_track'
                  CHECK (status IN ('on_track','at_risk','off_track','done','not_started')),
  quarter         text NOT NULL,                       -- 'Q2 2026'
  company_rock    boolean NOT NULL DEFAULT false,
  sort_order      int NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX rocks_org_quarter_idx
  ON public.rocks(organisation_id, quarter, sort_order);

CREATE TABLE public.issues (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL REFERENCES public.organisations(id) ON DELETE CASCADE,
  description     text NOT NULL,
  owner           text,
  status          text NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open','resolved')),
  solution        text,
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX issues_org_status_idx
  ON public.issues(organisation_id, status, created_at DESC);

CREATE TABLE public.meetings (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL REFERENCES public.organisations(id) ON DELETE CASCADE,
  meeting_date    date NOT NULL,
  quarter         text,
  status          text NOT NULL DEFAULT 'scheduled'
                  CHECK (status IN ('scheduled','in_progress','completed')),
  rating          int CHECK (rating BETWEEN 1 AND 10),
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX meetings_org_date_idx
  ON public.meetings(organisation_id, meeting_date DESC);

CREATE TABLE public.meeting_headlines (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id  uuid NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
  type        text NOT NULL CHECK (type IN ('good_news','headline')),
  description text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX meeting_headlines_meeting_idx ON public.meeting_headlines(meeting_id);

CREATE TABLE public.meeting_todos (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id  uuid NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
  description text NOT NULL,
  owner       text,
  done        boolean NOT NULL DEFAULT false,
  due_date    date,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX meeting_todos_meeting_idx ON public.meeting_todos(meeting_id);


-- =============================================================
-- 5. PLANNING SESSIONS
-- =============================================================

CREATE TABLE public.annual_sessions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL REFERENCES public.organisations(id) ON DELETE CASCADE,
  session_date    date NOT NULL,
  year            text,
  status          text NOT NULL DEFAULT 'scheduled'
                  CHECK (status IN ('scheduled','in_progress','completed')),
  attendance      text NOT NULL DEFAULT '',
  areas_completed jsonb NOT NULL DEFAULT '{}'::jsonb,
  -- v0.5.131: richer session capture
  notes           text,
  external_links  jsonb NOT NULL DEFAULT '[]'::jsonb,  -- [{label, url}, ...]
  commitments     jsonb NOT NULL DEFAULT '[]'::jsonb,  -- [{name, commitment}, ...]
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX annual_sessions_org_date_idx
  ON public.annual_sessions(organisation_id, session_date DESC);

CREATE TABLE public.quarterly_sessions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL REFERENCES public.organisations(id) ON DELETE CASCADE,
  session_date    date NOT NULL,
  target_quarter  text NOT NULL,
  status          text NOT NULL DEFAULT 'scheduled'
                  CHECK (status IN ('scheduled','in_progress','completed')),
  attendance      text NOT NULL DEFAULT '',
  areas_completed jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX quarterly_sessions_org_date_idx
  ON public.quarterly_sessions(organisation_id, session_date DESC);


-- =============================================================
-- 6. TEAM CHECK-INS — submissions from members for a session
-- =============================================================
-- 17 EOS-style rated statements + name + optional role.
-- session_id is polymorphic (refs annual_sessions OR quarterly_sessions);
-- session_type discriminates. organisation_id stored for RLS speed.

CREATE TABLE public.team_checkins (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL REFERENCES public.organisations(id) ON DELETE CASCADE,
  session_id      uuid NOT NULL,
  session_type    text NOT NULL CHECK (session_type IN ('annual','quarterly','batch')),
  user_id         uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  name            text NOT NULL,
  role            text,
  scores          jsonb NOT NULL,                  -- array of 17 ints (1-5)
  comments        jsonb NOT NULL DEFAULT '[]'::jsonb,
  submitted_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX team_checkins_session_idx
  ON public.team_checkins(session_id, session_type);
CREATE INDEX team_checkins_org_idx ON public.team_checkins(organisation_id);


-- v0.5.132: standalone check-in batches (not tied to a planning session)
CREATE TABLE public.checkin_batches (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL REFERENCES public.organisations(id) ON DELETE CASCADE,
  name            text NOT NULL,
  run_date        date NOT NULL DEFAULT CURRENT_DATE,
  invitees        jsonb NOT NULL DEFAULT '[]'::jsonb,
  notes           text,
  status          text NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX checkin_batches_org_date_idx
  ON public.checkin_batches(organisation_id, run_date DESC);


-- =============================================================
-- 7. ENABLE RLS on every domain table
-- =============================================================

ALTER TABLE public.subscriptions            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organisations            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.core_values              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.core_focus               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.targets                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketing_strategy       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leadership_team_members  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_periods        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scorecard_metrics        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scorecard_entries        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rocks                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.issues                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meetings                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meeting_headlines        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meeting_todos            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.annual_sessions          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quarterly_sessions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_checkins            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checkin_batches          ENABLE ROW LEVEL SECURITY;


-- =============================================================
-- 8. RLS POLICIES
-- =============================================================

-- subscriptions: owner can read+update; user inserts their own on signup
CREATE POLICY "owner reads own subscription"   ON public.subscriptions
  FOR SELECT USING (owner_user_id = auth.uid());
CREATE POLICY "owner updates own subscription" ON public.subscriptions
  FOR UPDATE USING (owner_user_id = auth.uid());
CREATE POLICY "user inserts own subscription"  ON public.subscriptions
  FOR INSERT WITH CHECK (owner_user_id = auth.uid());

-- organisations: any team member reads; admins (or subscription owner) write
CREATE POLICY "members read their orgs" ON public.organisations
  FOR SELECT USING (id IN (SELECT public.user_org_ids(auth.uid())));
CREATE POLICY "admins write their orgs" ON public.organisations
  FOR ALL
  USING (id IN (SELECT public.user_admin_org_ids(auth.uid()))
         OR subscription_id IN (SELECT id FROM public.subscriptions WHERE owner_user_id = auth.uid()))
  WITH CHECK (id IN (SELECT public.user_admin_org_ids(auth.uid()))
              OR subscription_id IN (SELECT id FROM public.subscriptions WHERE owner_user_id = auth.uid()));

-- team_members: members read team in their orgs; admins write
CREATE POLICY "members read team in their orgs" ON public.team_members
  FOR SELECT USING (organisation_id IN (SELECT public.user_org_ids(auth.uid())));
CREATE POLICY "admins write team members" ON public.team_members
  FOR ALL
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())))
  WITH CHECK (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));
-- Special: a user with a pending invite must be able to SELECT/UPDATE their own row to accept it
CREATE POLICY "invited user accepts own invite" ON public.team_members
  FOR UPDATE
  USING (invited_email = (SELECT email FROM auth.users WHERE id = auth.uid()))
  WITH CHECK (user_id = auth.uid() AND status = 'active');

-- ============= Standard policy macro for org-scoped data tables =============
-- READ:  org-member can read
-- WRITE: admin can write

CREATE POLICY "members read core_values"  ON public.core_values
  FOR SELECT USING (organisation_id IN (SELECT public.user_org_ids(auth.uid())));
CREATE POLICY "admins write core_values"  ON public.core_values
  FOR ALL
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())))
  WITH CHECK (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));

CREATE POLICY "members read core_focus"  ON public.core_focus
  FOR SELECT USING (organisation_id IN (SELECT public.user_org_ids(auth.uid())));
CREATE POLICY "admins write core_focus"  ON public.core_focus
  FOR ALL
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())))
  WITH CHECK (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));

CREATE POLICY "members read targets"  ON public.targets
  FOR SELECT USING (organisation_id IN (SELECT public.user_org_ids(auth.uid())));
CREATE POLICY "admins write targets"  ON public.targets
  FOR ALL
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())))
  WITH CHECK (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));

CREATE POLICY "members read marketing_strategy"  ON public.marketing_strategy
  FOR SELECT USING (organisation_id IN (SELECT public.user_org_ids(auth.uid())));
CREATE POLICY "admins write marketing_strategy"  ON public.marketing_strategy
  FOR ALL
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())))
  WITH CHECK (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));

CREATE POLICY "members read leadership"  ON public.leadership_team_members
  FOR SELECT USING (organisation_id IN (SELECT public.user_org_ids(auth.uid())));
CREATE POLICY "admins write leadership"  ON public.leadership_team_members
  FOR ALL
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())))
  WITH CHECK (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));

CREATE POLICY "members read financial_periods"  ON public.financial_periods
  FOR SELECT USING (organisation_id IN (SELECT public.user_org_ids(auth.uid())));
CREATE POLICY "admins write financial_periods"  ON public.financial_periods
  FOR ALL
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())))
  WITH CHECK (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));

CREATE POLICY "members read scorecard_metrics"  ON public.scorecard_metrics
  FOR SELECT USING (organisation_id IN (SELECT public.user_org_ids(auth.uid())));
CREATE POLICY "admins write scorecard_metrics"  ON public.scorecard_metrics
  FOR ALL
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())))
  WITH CHECK (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));

-- scorecard_entries: scoped via metric's org_id
CREATE POLICY "members read scorecard_entries" ON public.scorecard_entries
  FOR SELECT USING (metric_id IN (
    SELECT id FROM public.scorecard_metrics
    WHERE organisation_id IN (SELECT public.user_org_ids(auth.uid()))
  ));
CREATE POLICY "admins write scorecard_entries" ON public.scorecard_entries
  FOR ALL
  USING (metric_id IN (
    SELECT id FROM public.scorecard_metrics
    WHERE organisation_id IN (SELECT public.user_admin_org_ids(auth.uid()))
  ))
  WITH CHECK (metric_id IN (
    SELECT id FROM public.scorecard_metrics
    WHERE organisation_id IN (SELECT public.user_admin_org_ids(auth.uid()))
  ));

CREATE POLICY "members read rocks"  ON public.rocks
  FOR SELECT USING (organisation_id IN (SELECT public.user_org_ids(auth.uid())));
CREATE POLICY "admins write rocks"  ON public.rocks
  FOR ALL
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())))
  WITH CHECK (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));

CREATE POLICY "members read issues"  ON public.issues
  FOR SELECT USING (organisation_id IN (SELECT public.user_org_ids(auth.uid())));
CREATE POLICY "admins write issues"  ON public.issues
  FOR ALL
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())))
  WITH CHECK (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));

CREATE POLICY "members read meetings"  ON public.meetings
  FOR SELECT USING (organisation_id IN (SELECT public.user_org_ids(auth.uid())));
CREATE POLICY "admins write meetings"  ON public.meetings
  FOR ALL
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())))
  WITH CHECK (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));

-- meeting_headlines: scoped via meeting's org_id
CREATE POLICY "members read meeting_headlines" ON public.meeting_headlines
  FOR SELECT USING (meeting_id IN (
    SELECT id FROM public.meetings
    WHERE organisation_id IN (SELECT public.user_org_ids(auth.uid()))
  ));
CREATE POLICY "admins write meeting_headlines" ON public.meeting_headlines
  FOR ALL
  USING (meeting_id IN (
    SELECT id FROM public.meetings
    WHERE organisation_id IN (SELECT public.user_admin_org_ids(auth.uid()))
  ))
  WITH CHECK (meeting_id IN (
    SELECT id FROM public.meetings
    WHERE organisation_id IN (SELECT public.user_admin_org_ids(auth.uid()))
  ));

-- meeting_todos: same as headlines
CREATE POLICY "members read meeting_todos" ON public.meeting_todos
  FOR SELECT USING (meeting_id IN (
    SELECT id FROM public.meetings
    WHERE organisation_id IN (SELECT public.user_org_ids(auth.uid()))
  ));
CREATE POLICY "admins write meeting_todos" ON public.meeting_todos
  FOR ALL
  USING (meeting_id IN (
    SELECT id FROM public.meetings
    WHERE organisation_id IN (SELECT public.user_admin_org_ids(auth.uid()))
  ))
  WITH CHECK (meeting_id IN (
    SELECT id FROM public.meetings
    WHERE organisation_id IN (SELECT public.user_admin_org_ids(auth.uid()))
  ));

CREATE POLICY "members read annual_sessions"  ON public.annual_sessions
  FOR SELECT USING (organisation_id IN (SELECT public.user_org_ids(auth.uid())));
CREATE POLICY "admins write annual_sessions"  ON public.annual_sessions
  FOR ALL
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())))
  WITH CHECK (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));

CREATE POLICY "members read quarterly_sessions"  ON public.quarterly_sessions
  FOR SELECT USING (organisation_id IN (SELECT public.user_org_ids(auth.uid())));
CREATE POLICY "admins write quarterly_sessions"  ON public.quarterly_sessions
  FOR ALL
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())))
  WITH CHECK (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));

-- team_checkins: SPECIAL — any active org member reads + inserts; only admins delete/update.
-- v0.5.132: batch-type team_checkins are admin/coach-only; annual/quarterly stay member-readable.
CREATE POLICY "scoped read team_checkins" ON public.team_checkins
  FOR SELECT USING (
    CASE
      WHEN session_type = 'batch'
        THEN organisation_id IN (SELECT public.user_admin_org_ids(auth.uid()))
      ELSE
        organisation_id IN (SELECT public.user_org_ids(auth.uid()))
    END
  );
CREATE POLICY "members insert own team_checkin" ON public.team_checkins
  FOR INSERT WITH CHECK (
    organisation_id IN (SELECT public.user_org_ids(auth.uid()))
    AND (user_id = auth.uid() OR user_id IS NULL)
  );
CREATE POLICY "admins update team_checkins" ON public.team_checkins
  FOR UPDATE
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())))
  WITH CHECK (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));
CREATE POLICY "admins delete team_checkins" ON public.team_checkins
  FOR DELETE
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));

-- v0.5.132: checkin_batches — members can read (so they see what they're invited to);
-- admins + coaches manage.
CREATE POLICY "members read checkin_batches" ON public.checkin_batches
  FOR SELECT USING (organisation_id IN (SELECT public.user_org_ids(auth.uid())));
CREATE POLICY "admins write checkin_batches" ON public.checkin_batches
  FOR ALL
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())))
  WITH CHECK (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));


-- =============================================================
-- 9. Helper view — current team members (one row per active user-in-org)
-- =============================================================
CREATE OR REPLACE VIEW public.v_active_team AS
SELECT
  tm.id              AS team_member_id,
  tm.organisation_id,
  o.name             AS organisation_name,
  tm.user_id,
  u.email,
  tm.role,
  tm.display_name,
  tm.joined_at
FROM public.team_members tm
JOIN public.organisations o ON o.id = tm.organisation_id
LEFT JOIN auth.users u ON u.id = tm.user_id
WHERE tm.status = 'active';


-- =============================================================
-- 10. BOOTSTRAP FUNCTIONS
-- =============================================================
-- Called by the app to create a new organisation. Handles BOTH:
--   • First-time setup (user has no subscription) — creates subscription + org + admin team_member
--   • Additional business (user already has a subscription) — adds org + admin team_member
-- SECURITY DEFINER lets it write tables the user's RLS would block during bootstrap.

-- Optional subscription_id (v0.5.111): if provided, targets that subscription;
-- if NULL, falls back to the caller's first subscription (or creates one).
-- Necessary for multi-tenant users who own more than one client account.
CREATE OR REPLACE FUNCTION public.bootstrap_organisation(
  business_name text,
  subscription_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid                  uuid := auth.uid();
  v_subscription_id    uuid := subscription_id;
  v_organisation_id    uuid;
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


-- =============================================================
-- 11. ACCOUNT NAME helpers (v0.5.83)
-- =============================================================
-- Companion to bootstrap_organisation that ALSO sets the account name on
-- first-time setup. Use this from setup.html for new users.

CREATE OR REPLACE FUNCTION public.bootstrap_account_and_business(
  account_name  text,
  business_name text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid                  uuid := auth.uid();
  v_subscription_id    uuid;
  v_organisation_id    uuid;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF business_name IS NULL OR length(trim(business_name)) = 0 THEN
    RAISE EXCEPTION 'Business name is required';
  END IF;

  SELECT id INTO v_subscription_id
  FROM public.subscriptions
  WHERE owner_user_id = uid
  LIMIT 1;

  IF v_subscription_id IS NULL THEN
    INSERT INTO public.subscriptions (owner_user_id, name)
    VALUES (uid, NULLIF(trim(coalesce(account_name, '')), ''))
    RETURNING id INTO v_subscription_id;
  ELSIF account_name IS NOT NULL AND length(trim(account_name)) > 0 THEN
    UPDATE public.subscriptions
    SET name = trim(account_name), updated_at = now()
    WHERE id = v_subscription_id;
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

GRANT EXECUTE ON FUNCTION public.bootstrap_account_and_business(text, text) TO authenticated;

-- Rename the calling user's account (subscription) at any time
CREATE OR REPLACE FUNCTION public.update_account_name(new_name text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  UPDATE public.subscriptions
  SET name = NULLIF(trim(coalesce(new_name, '')), ''),
      updated_at = now()
  WHERE owner_user_id = uid;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_account_name(text) TO authenticated;


-- =============================================================
-- 11b. CREATE CLIENT ACCOUNT (v0.5.111)
-- =============================================================
-- Multi-tenant: lets one user own MULTIPLE subscriptions, one per
-- client account. ALWAYS creates a new subscription (vs.
-- bootstrap_account_and_business which reuses).

DROP FUNCTION IF EXISTS public.create_client_account(text, text);

CREATE OR REPLACE FUNCTION public.create_client_account(
  account_name  text,
  business_name text
)
RETURNS TABLE (subscription_id uuid, organisation_id uuid)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid                  uuid := auth.uid();
  v_subscription_id    uuid;
  v_organisation_id    uuid;
  v_account_name       text := NULLIF(trim(coalesce(account_name, '')), '');
  v_business_name      text := NULLIF(trim(coalesce(business_name, '')), '');
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF v_account_name IS NULL THEN
    RAISE EXCEPTION 'Account name is required';
  END IF;
  IF v_business_name IS NULL THEN
    RAISE EXCEPTION 'Business name is required';
  END IF;

  INSERT INTO public.subscriptions (owner_user_id, name)
  VALUES (uid, v_account_name)
  RETURNING id INTO v_subscription_id;

  INSERT INTO public.organisations (subscription_id, name)
  VALUES (v_subscription_id, v_business_name)
  RETURNING id INTO v_organisation_id;

  INSERT INTO public.team_members (
    organisation_id, user_id, role, status, joined_at
  )
  VALUES (
    v_organisation_id, uid, 'admin', 'active', now()
  );

  subscription_id := v_subscription_id;
  organisation_id := v_organisation_id;
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_client_account(text, text) TO authenticated;


-- =============================================================
-- 12. TEAM MANAGEMENT + BUSINESS CRUD (v0.5.84)
-- =============================================================
-- These functions back the SARUBA account dashboard (my-businesses.html):
--   • invite_team_member(business_id, email, role, display_name)
--   • remove_team_member(member_id)
--   • rename_business(business_id, new_name)
--   • delete_business(business_id)
--   • link_pending_invites() trigger — wires invited_email → user_id on signup
-- All are SECURITY DEFINER. Caller must be an active admin of the org.

CREATE OR REPLACE FUNCTION public.invite_team_member(
  business_id  uuid,
  email        text,
  role         text DEFAULT 'member',
  display_name text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid              uuid := auth.uid();
  v_email          text := lower(trim(coalesce(email, '')));
  v_role           text := lower(trim(coalesce(role, 'member')));
  v_existing_user  uuid;
  v_existing_row   uuid;
  v_new_id         uuid;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF business_id IS NULL THEN
    RAISE EXCEPTION 'business_id is required';
  END IF;
  IF v_email = '' OR position('@' in v_email) = 0 THEN
    RAISE EXCEPTION 'A valid email is required';
  END IF;
  IF v_role NOT IN ('admin', 'coach', 'member') THEN
    RAISE EXCEPTION 'Role must be admin, coach, or member';
  END IF;

  -- Caller must be an active admin OR coach of this org
  IF NOT EXISTS (
    SELECT 1 FROM public.team_members
    WHERE team_members.organisation_id = business_id
      AND team_members.user_id = uid
      AND team_members.role IN ('admin', 'coach')
      AND team_members.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Only admins or coaches can invite team members';
  END IF;

  -- See if this email belongs to an existing auth.users row
  SELECT id INTO v_existing_user
  FROM auth.users
  WHERE lower(email) = v_email
  LIMIT 1;

  -- Already in this org? (active or pending) — return existing id, don't duplicate
  IF v_existing_user IS NOT NULL THEN
    SELECT id INTO v_existing_row
    FROM public.team_members
    WHERE organisation_id = business_id
      AND user_id = v_existing_user
      AND status <> 'removed'
    LIMIT 1;
    IF v_existing_row IS NOT NULL THEN
      RETURN v_existing_row;
    END IF;
  ELSE
    SELECT id INTO v_existing_row
    FROM public.team_members
    WHERE organisation_id = business_id
      AND lower(coalesce(invited_email, '')) = v_email
      AND status = 'pending'
    LIMIT 1;
    IF v_existing_row IS NOT NULL THEN
      RETURN v_existing_row;
    END IF;
  END IF;

  IF v_existing_user IS NOT NULL THEN
    INSERT INTO public.team_members (
      organisation_id, user_id, role, status, display_name, joined_at
    ) VALUES (
      business_id, v_existing_user, v_role, 'active',
      NULLIF(trim(coalesce(display_name, '')), ''), now()
    )
    RETURNING id INTO v_new_id;
  ELSE
    INSERT INTO public.team_members (
      organisation_id, invited_email, role, status, display_name
    ) VALUES (
      business_id, v_email, v_role, 'pending',
      NULLIF(trim(coalesce(display_name, '')), '')
    )
    RETURNING id INTO v_new_id;
  END IF;

  RETURN v_new_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.invite_team_member(uuid, text, text, text) TO authenticated;


CREATE OR REPLACE FUNCTION public.remove_team_member(member_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid          uuid := auth.uid();
  v_org_id     uuid;
  v_user_id    uuid;
  v_role       text;
  v_admin_cnt  int;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF member_id IS NULL THEN
    RAISE EXCEPTION 'member_id is required';
  END IF;

  SELECT organisation_id, user_id, role
    INTO v_org_id, v_user_id, v_role
  FROM public.team_members
  WHERE id = member_id;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'Team member not found';
  END IF;

  -- Caller must be an active admin of this org
  IF NOT EXISTS (
    SELECT 1 FROM public.team_members
    WHERE team_members.organisation_id = v_org_id
      AND team_members.user_id = uid
      AND team_members.role IN ('admin', 'coach')
      AND team_members.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Only admins or coaches can remove team members';
  END IF;

  -- Guard: don't allow removing the only remaining admin (coaches don't count)
  IF v_role = 'admin' THEN
    SELECT count(*) INTO v_admin_cnt
    FROM public.team_members
    WHERE team_members.organisation_id = v_org_id
      AND team_members.role = 'admin'
      AND team_members.status = 'active'
      AND team_members.id <> member_id;
    IF v_admin_cnt = 0 THEN
      RAISE EXCEPTION 'Cannot remove the only admin of this business. Promote another member first.';
    END IF;
  END IF;

  UPDATE public.team_members
  SET status = 'removed'
  WHERE id = member_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_team_member(uuid) TO authenticated;


CREATE OR REPLACE FUNCTION public.rename_business(business_id uuid, new_name text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid       uuid := auth.uid();
  v_clean   text := trim(coalesce(new_name, ''));
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF business_id IS NULL THEN
    RAISE EXCEPTION 'business_id is required';
  END IF;
  IF v_clean = '' THEN
    RAISE EXCEPTION 'Business name cannot be empty';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.team_members
    WHERE organisation_id = business_id
      AND user_id = uid
      AND role = 'admin'
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Only admins can rename this business';
  END IF;

  UPDATE public.organisations
  SET name = v_clean
  WHERE id = business_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rename_business(uuid, text) TO authenticated;


CREATE OR REPLACE FUNCTION public.delete_business(business_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid              uuid := auth.uid();
  v_subscription   uuid;
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

  DELETE FROM public.organisations WHERE id = business_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_business(uuid) TO authenticated;


-- =============================================================
-- 13. AUTO-LINK pending invites on signup
-- =============================================================
-- When a new auth.users row is INSERTed, claim any team_members rows that
-- were created with invited_email = NEW.email (status='pending', user_id NULL).

CREATE OR REPLACE FUNCTION public.link_pending_invites()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.team_members
  SET user_id = NEW.id, status = 'active', joined_at = now(), invited_email = NULL
  WHERE invited_email IS NOT NULL
    AND lower(invited_email) = lower(NEW.email)
    AND status = 'pending';
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS link_pending_invites_on_signup ON auth.users;
CREATE TRIGGER link_pending_invites_on_signup
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.link_pending_invites();


-- =============================================================
-- 14. POST-v0.5.132 ADDITIONS (catch-up section)
-- =============================================================
-- Everything below was originally shipped as per-version delta files
-- (supabase/v0.5.NNN-delta.sql). Captured here so a fresh install via
-- schema.sql alone produces the current production schema.

-- v0.5.140: organisations.sort_order is already declared above; nothing to do.

-- v0.5.145: parent / child business relationships (depth 1, nullable).
ALTER TABLE public.organisations
  ADD COLUMN IF NOT EXISTS parent_organisation_id uuid
    REFERENCES public.organisations(id) ON DELETE SET NULL;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'organisations_no_self_parent'
  ) THEN
    ALTER TABLE public.organisations
      ADD CONSTRAINT organisations_no_self_parent CHECK (parent_organisation_id <> id);
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS organisations_parent_idx
  ON public.organisations(parent_organisation_id);

-- v0.5.145 + v0.5.197: children inherit parent strategy + cadence (SELECT only).
DROP POLICY IF EXISTS "children read parent core_values" ON public.core_values;
CREATE POLICY "children read parent core_values" ON public.core_values
  FOR SELECT USING (
    organisation_id IN (
      SELECT parent_organisation_id FROM public.organisations
      WHERE id IN (SELECT public.user_org_ids(auth.uid()))
        AND parent_organisation_id IS NOT NULL
    )
  );
DROP POLICY IF EXISTS "children read parent core_focus" ON public.core_focus;
CREATE POLICY "children read parent core_focus" ON public.core_focus
  FOR SELECT USING (
    organisation_id IN (
      SELECT parent_organisation_id FROM public.organisations
      WHERE id IN (SELECT public.user_org_ids(auth.uid()))
        AND parent_organisation_id IS NOT NULL
    )
  );
DROP POLICY IF EXISTS "children read parent targets" ON public.targets;
CREATE POLICY "children read parent targets" ON public.targets
  FOR SELECT USING (
    organisation_id IN (
      SELECT parent_organisation_id FROM public.organisations
      WHERE id IN (SELECT public.user_org_ids(auth.uid()))
        AND parent_organisation_id IS NOT NULL
    )
  );

-- v0.5.181: targets.five_year column (the simplified Targets worksheet).
ALTER TABLE public.targets ADD COLUMN IF NOT EXISTS five_year text;

-- v0.5.183: issues.category with CHECK + index. Existing rows backfill to 'current'.
ALTER TABLE public.issues
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'current';
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'issues_category_check'
  ) THEN
    ALTER TABLE public.issues
      ADD CONSTRAINT issues_category_check
      CHECK (category IN ('yearly','current','future'));
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS issues_org_category_idx
  ON public.issues(organisation_id, category);

-- v0.5.187: external Org Chart URL on organisations.
ALTER TABLE public.organisations
  ADD COLUMN IF NOT EXISTS org_chart_url text;

-- v0.5.192 + v0.5.193 + v0.5.211: business_cadence (planning rhythm).
-- One row per organisation: annual planning date(s), per-quarter session dates,
-- weekly meeting day + time. Day-2 columns are optional second-day extensions.
CREATE TABLE IF NOT EXISTS public.business_cadence (
  organisation_id            uuid PRIMARY KEY REFERENCES public.organisations(id) ON DELETE CASCADE,
  annual_planning_date       date,
  annual_planning_date_2     date,
  last_annual_planning_date  date,
  q1_session_date            date,
  q1_session_date_2          date,
  q2_session_date            date,
  q2_session_date_2          date,
  q3_session_date            date,
  q3_session_date_2          date,
  q4_session_date            date,
  q4_session_date_2          date,
  weekly_meeting_day         text CHECK (
    weekly_meeting_day IN ('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')
  ),
  weekly_meeting_time        time,
  updated_at                 timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.business_cadence ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "members read cadence" ON public.business_cadence;
CREATE POLICY "members read cadence" ON public.business_cadence
  FOR SELECT USING (organisation_id IN (SELECT public.user_org_ids(auth.uid())));
DROP POLICY IF EXISTS "admins write cadence" ON public.business_cadence;
CREATE POLICY "admins write cadence" ON public.business_cadence
  FOR ALL
  USING (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())))
  WITH CHECK (organisation_id IN (SELECT public.user_admin_org_ids(auth.uid())));
-- v0.5.197: children read parent cadence so the Year Flow + plan-year inherit.
DROP POLICY IF EXISTS "children read parent cadence" ON public.business_cadence;
CREATE POLICY "children read parent cadence" ON public.business_cadence
  FOR SELECT USING (
    organisation_id IN (
      SELECT parent_organisation_id FROM public.organisations
      WHERE id IN (SELECT public.user_org_ids(auth.uid()))
        AND parent_organisation_id IS NOT NULL
    )
  );

-- v0.5.211: quarterly_sessions parity with annual_sessions (notes + links + commitments).
ALTER TABLE public.quarterly_sessions ADD COLUMN IF NOT EXISTS notes text;
ALTER TABLE public.quarterly_sessions ADD COLUMN IF NOT EXISTS external_links jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.quarterly_sessions ADD COLUMN IF NOT EXISTS commitments    jsonb NOT NULL DEFAULT '[]'::jsonb;

-- v0.5.216: members can INSERT issues (Add — yes, Delete/Update — no).
DROP POLICY IF EXISTS "members add issues" ON public.issues;
CREATE POLICY "members add issues" ON public.issues
  FOR INSERT
  WITH CHECK (
    organisation_id IN (SELECT public.user_org_ids(auth.uid()))
    AND category IN ('current','future')
  );


-- =============================================================
-- DONE
-- =============================================================
-- Next steps (in code, not SQL):
-- v0.5.85 — replace each tool's localStorage api() with supabase.from() calls
