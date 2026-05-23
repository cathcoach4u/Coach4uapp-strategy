-- ============================================================
-- v0.5.187 — External org chart URL on each organisation
-- ============================================================
-- The Organisational Chart card (formerly Leadership Team) gets a
-- "Org Chart URL" field so users can paste a link to an external
-- diagram (Lucidchart, Miro, Google Drawings, Figma, etc.) that
-- they maintain outside the app. The link also surfaces on the
-- one-page plan in the Leadership Team section.
--
-- No RLS change needed — the existing organisations policies cover
-- it (members read, admins+subscription owner write).
-- ============================================================

ALTER TABLE public.organisations
  ADD COLUMN IF NOT EXISTS org_chart_url text;

NOTIFY pgrst, 'reload schema';
