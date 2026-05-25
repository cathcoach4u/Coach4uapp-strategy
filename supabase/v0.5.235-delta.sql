-- v0.5.235 — Migrate IASHQ quarterly goals from calendar quarter to fiscal quarter.
-- The 5 rocks seeded in v0.5.231-delta.sql were inserted with quarter = 'Q2 2026'
-- (calendar year). IAS has a July fiscal year start, so May 2026 falls in Q4 2025/26
-- and the upcoming quarter is Q1 2026/27. This migration corrects those rocks so they
-- appear in the right quarter in the goals.html and operations one-page views.
--
-- Safe to re-run: uses WHERE clause scoped to the specific wrong value + IASHQ org.
-- IASHQ org id: look up via SELECT id FROM organisations WHERE name ILIKE '%iashq%';

UPDATE public.rocks
SET quarter = 'Q1 2026/27'
WHERE quarter = 'Q2 2026'
  AND organisation_id = (
    SELECT id FROM public.organisations WHERE name ILIKE '%iashq%' LIMIT 1
  );
