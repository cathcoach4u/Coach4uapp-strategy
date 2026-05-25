-- v0.5.231: Import IAS planning meeting notes (May 2026)
-- Run once in Supabase SQL Editor.
-- Imports into IASHQ: 10-year + 7-year targets, current issues, future issues, Q2 2026 quarterly goals.

DO $$
DECLARE
  v_iashq_id uuid;
BEGIN
  -- Find IASHQ by name
  SELECT id INTO v_iashq_id
  FROM public.organisations
  WHERE LOWER(name) LIKE '%iashq%' OR LOWER(name) = 'ias hq'
  LIMIT 1;

  IF v_iashq_id IS NULL THEN
    RAISE EXCEPTION 'IASHQ organisation not found — check organisation names in your Supabase DB';
  END IF;

  -- 1. TARGETS: 10-year and 7-year visions (stored in ten_year + five_year columns)
  INSERT INTO public.targets (organisation_id, ten_year, five_year, updated_at)
  VALUES (
    v_iashq_id,
    E'By 30/06/2036 (Jo 63, Teresa 69, Leah 56):\n\nBuild a self-sustaining business with reduced owner dependency. Jo to work only a few days a week or retire if desired. Option to sell or significantly reduce day-to-day involvement.\n\nFocus on succession planning and sale readiness — with flexibility if goals change over time.',
    E'By 30/06/2033:\n\n• Achieve group turnover of $2.5 million\n• Pay off the D&C loan\n• Maintain 15% profit margin\n• Strong cash flow, job satisfaction and a healthy profitable business\n• Succession plan in place for the leadership team\n• Proper documentation for all processes and compliance',
    now()
  )
  ON CONFLICT (organisation_id) DO UPDATE SET
    ten_year  = EXCLUDED.ten_year,
    five_year = EXCLUDED.five_year,
    updated_at = now();

  -- 2. ISSUES: Operational issues identified in the meeting (current)
  INSERT INTO public.issues (organisation_id, description, owner, status, category) VALUES
    (v_iashq_id,
     'Cash flow management — need improved visibility and reporting dashboards across all business units',
     'Jo', 'open', 'current'),
    (v_iashq_id,
     'Compliance standardisation — documentation gaps across GI, Life/FP and Outsourcing need to be addressed',
     NULL, 'open', 'current'),
    (v_iashq_id,
     'Staffing — HQ and admin support roles needed; Sunny''s resignation in Life/FP requires a replacement plan',
     'Jo', 'open', 'current'),
    (v_iashq_id,
     'Cost splitting — current salary and overhead allocations do not accurately reflect actual time spent across business units',
     'Leah', 'open', 'current'),
    (v_iashq_id,
     'Wage allocation discrepancy — Jo''s Operations split: Xero shows 40% vs planning discussion agreed 30% (with 10% to IASO). Needs finalising.',
     'Jo', 'open', 'current'),
    (v_iashq_id,
     'Technology tools — challenges with Copilot, Claude and Xero (technical limitations, skills gaps, project management clarity needed)',
     NULL, 'open', 'current');

  -- 3. ISSUES: Unresolved items for Planning Day 19/05/2026 (future)
  INSERT INTO public.issues (organisation_id, description, owner, status, category) VALUES
    (v_iashq_id,
     'Budget finalisation — complete review including IT and staffing costs with accurate allocation by business unit',
     'Leah', 'open', 'future'),
    (v_iashq_id,
     'Formalised training plans — develop plans for Lisa (ANZIIF Diploma), Fhevy and broader support staff; update all job descriptions',
     NULL, 'open', 'future'),
    (v_iashq_id,
     'AI/automation direction — determine future investment, project scope and ownership for AI/automation initiatives',
     NULL, 'open', 'future'),
    (v_iashq_id,
     'Project management protocols — define and document PM and communication processes for technology initiatives',
     NULL, 'open', 'future');

  -- 4. ROCKS: Quarterly Goals for Q2 2026 — action points from the meeting
  INSERT INTO public.rocks (organisation_id, description, owner, status, quarter, company_rock) VALUES
    (v_iashq_id,
     'Finalise group budget including IT and staffing cost allocations by business unit',
     'Leah', 'not_started', 'Q2 2026', true),
    (v_iashq_id,
     'Develop standardised compliance and training documentation across GI, Life/FP and Outsourcing',
     NULL, 'not_started', 'Q2 2026', true),
    (v_iashq_id,
     'Refine accountability charts and time allocation tracking for Jo, Leah and Teresa',
     'Jo', 'not_started', 'Q2 2026', true),
    (v_iashq_id,
     'Implement improved cash flow visibility and reporting (enhanced dashboards or external support)',
     'Jo', 'not_started', 'Q2 2026', true),
    (v_iashq_id,
     'Define and document project management and communication protocols for technology initiatives',
     NULL, 'not_started', 'Q2 2026', true);

  RAISE NOTICE 'Import complete. IASHQ org_id: %. Imported 1 targets row (10-year + 7-year), 6 current issues, 4 future issues, 5 Q2 2026 quarterly goals.', v_iashq_id;
END $$;
