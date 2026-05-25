-- v0.5.232: Comprehensive IAS data import from May 2026 planning meeting — Part 2
-- Populates: core_focus, one_year_goals, leadership_team_members, and per-unit issues
-- for IASHQ, IAS General, IAS Life and IAS Outsourcing.
-- Safe to run once — leadership team inserts use WHERE NOT EXISTS guards.

DO $$
DECLARE
  v_iashq_id       uuid;
  v_gi_id          uuid;
  v_life_id        uuid;
  v_outsourcing_id uuid;
BEGIN
  SELECT id INTO v_iashq_id       FROM public.organisations WHERE LOWER(name) LIKE '%iashq%' OR LOWER(name) = 'ias hq'       LIMIT 1;
  SELECT id INTO v_gi_id          FROM public.organisations WHERE LOWER(name) LIKE '%ias general%'                            LIMIT 1;
  SELECT id INTO v_life_id        FROM public.organisations WHERE LOWER(name) LIKE '%ias life%'                               LIMIT 1;
  SELECT id INTO v_outsourcing_id FROM public.organisations WHERE LOWER(name) LIKE '%outsourcing%' OR LOWER(name) LIKE '%iaso%' LIMIT 1;

  IF v_iashq_id       IS NULL THEN RAISE EXCEPTION 'IASHQ not found — check organisation names'; END IF;
  IF v_gi_id          IS NULL THEN RAISE EXCEPTION 'IAS General not found'; END IF;
  IF v_life_id        IS NULL THEN RAISE EXCEPTION 'IAS Life not found'; END IF;
  IF v_outsourcing_id IS NULL THEN RAISE EXCEPTION 'IAS Outsourcing not found'; END IF;

  -- ═══════════════════════════════════════════════════════
  --  IASHQ — Holding company / operations leadership
  -- ═══════════════════════════════════════════════════════

  INSERT INTO public.core_focus (organisation_id, purpose, niche, updated_at) VALUES (
    v_iashq_id,
    'Provide operational leadership, coordination and accountability across all IAS business units — enabling each unit to focus on client delivery while HQ drives strategy, compliance and succession.',
    'Insurance and financial services group — holding company for IAS General Insurance, IAS Life/FP and IAS Outsourcing.',
    now()
  ) ON CONFLICT (organisation_id) DO UPDATE SET
    purpose    = EXCLUDED.purpose,
    niche      = EXCLUDED.niche,
    updated_at = now();

  UPDATE public.targets SET
    one_year_goals = E'FY2026–27:\n• Establish IAS HQ as the operational and strategic leadership centre\n• Finalise and implement wage allocation framework across all units:\n  Jo: 50% FP / 10% GI / 30% Ops / 10% IASO\n  Leah: 60% HQ / 20% IASO / 10% GI / 10% Life/FP\n  Teresa: 10% HQ / 90% GI\n• Complete compliance documentation standardisation across all units\n• Implement improved group financial reporting and cash flow visibility\n• Begin succession planning documentation for Jo and leadership team',
    updated_at     = now()
  WHERE organisation_id = v_iashq_id;

  -- IASHQ leadership team
  INSERT INTO public.leadership_team_members (organisation_id, name, role, responsibilities, sort_order)
  SELECT v_iashq_id, 'Jo', 'Director — transitioning to IAS HQ',
    E'Time allocation (planning discussion):\n30% Operations/HQ | 50% FP/Life (reducing) | 10% GI | 10% IASO\n\nStrategic oversight, succession planning and transition of day-to-day Life/FP involvement to IAS HQ leadership role over the 7-year plan period.', 1
  WHERE NOT EXISTS (SELECT 1 FROM public.leadership_team_members WHERE organisation_id = v_iashq_id AND LOWER(name) = 'jo');

  INSERT INTO public.leadership_team_members (organisation_id, name, role, responsibilities, sort_order)
  SELECT v_iashq_id, 'Leah', 'Operations Manager — IAS HQ',
    E'Time allocation: 60% HQ | 20% IASO | 10% GI | 10% Life/FP\n\nLeads day-to-day HQ operations, cost allocation, compliance oversight and cross-unit coordination.', 2
  WHERE NOT EXISTS (SELECT 1 FROM public.leadership_team_members WHERE organisation_id = v_iashq_id AND LOWER(name) = 'leah');

  INSERT INTO public.leadership_team_members (organisation_id, name, role, responsibilities, sort_order)
  SELECT v_iashq_id, 'Teresa', 'Director — General Insurance (HQ attendance)',
    E'Time allocation: 10% HQ | 90% GI\n\nPrimary responsibility is General Insurance. Attends IAS HQ-level strategic and planning meetings.', 3
  WHERE NOT EXISTS (SELECT 1 FROM public.leadership_team_members WHERE organisation_id = v_iashq_id AND LOWER(name) = 'teresa');

  -- ═══════════════════════════════════════════════════════
  --  IAS GENERAL INSURANCE (GI)
  -- ═══════════════════════════════════════════════════════

  INSERT INTO public.core_focus (organisation_id, purpose, niche, updated_at) VALUES (
    v_gi_id,
    'Deliver quality general insurance broking and advice to clients, with a focus on revenue growth, compliance and team capability.',
    'General insurance broking — targeting close to $1 million in annual revenue with strong compliance documentation and a growing support team.',
    now()
  ) ON CONFLICT (organisation_id) DO UPDATE SET
    purpose    = EXCLUDED.purpose,
    niche      = EXCLUDED.niche,
    updated_at = now();

  INSERT INTO public.targets (organisation_id, one_year_revenue, one_year_goals, updated_at) VALUES (
    v_gi_id,
    '~$1,000,000',
    E'FY2026–27:\n• Reach close to $1 million in revenue\n• Hire ICS Broker Support role (~$54k pa)\n• Onboard broker assistant (South Africa — planned)\n• Standardise compliance documentation across the GI team\n• Confirm IASO support allocation (~$15k pa, split 50/50 with Life/FP)\n• Continue ANZIIF Diploma progression for Lisa',
    now()
  ) ON CONFLICT (organisation_id) DO UPDATE SET
    one_year_revenue = EXCLUDED.one_year_revenue,
    one_year_goals   = EXCLUDED.one_year_goals,
    updated_at       = now();

  INSERT INTO public.leadership_team_members (organisation_id, name, role, responsibilities, sort_order)
  SELECT v_gi_id, 'Teresa', 'Director — General Insurance',
    E'Time allocation: 90% GI\n\nLeads all GI operations, client relationships, compliance and team management.', 1
  WHERE NOT EXISTS (SELECT 1 FROM public.leadership_team_members WHERE organisation_id = v_gi_id AND LOWER(name) = 'teresa');

  INSERT INTO public.leadership_team_members (organisation_id, name, role, responsibilities, sort_order)
  SELECT v_gi_id, 'Jo', 'Director (part-time strategic oversight)',
    E'Time allocation: 10% GI\n\nStrategic governance only. Not involved in day-to-day GI operations.', 2
  WHERE NOT EXISTS (SELECT 1 FROM public.leadership_team_members WHERE organisation_id = v_gi_id AND LOWER(name) = 'jo');

  INSERT INTO public.leadership_team_members (organisation_id, name, role, responsibilities, sort_order)
  SELECT v_gi_id, 'Leah', 'Operations support',
    E'Time allocation: 10% GI\n\nCross-unit operations, cost allocation and coordination support.', 3
  WHERE NOT EXISTS (SELECT 1 FROM public.leadership_team_members WHERE organisation_id = v_gi_id AND LOWER(name) = 'leah');

  INSERT INTO public.leadership_team_members (organisation_id, name, role, responsibilities, sort_order)
  SELECT v_gi_id, 'Lisa', 'Broker Support (development)',
    E'Continuing ANZIIF Diploma progression.\nFormalised training plan to be developed.', 4
  WHERE NOT EXISTS (SELECT 1 FROM public.leadership_team_members WHERE organisation_id = v_gi_id AND LOWER(name) = 'lisa');

  INSERT INTO public.issues (organisation_id, description, owner, status, category) VALUES
    (v_gi_id, 'ICS Broker Support role — priority hire at ~$54k pa. Required to support growth toward $1M revenue target.', 'Teresa', 'open', 'current'),
    (v_gi_id, 'Compliance documentation — standardisation required across GI team. Ongoing challenge.', 'Teresa', 'open', 'current'),
    (v_gi_id, 'Broker assistant hire (South Africa) — confirm timeline, job spec and onboarding approach.', 'Teresa', 'open', 'future'),
    (v_gi_id, 'IASO support allocation — $15k pa (split 50/50 with Life/FP). Confirm and include in FY budget.', 'Leah', 'open', 'future');

  -- ═══════════════════════════════════════════════════════
  --  IAS LIFE / FP
  -- ═══════════════════════════════════════════════════════

  INSERT INTO public.core_focus (organisation_id, purpose, niche, updated_at) VALUES (
    v_life_id,
    'Deliver life insurance and financial planning advice to clients, growing risk case volume and ongoing FP fee revenue.',
    'Life insurance and financial planning — increasing risk cases and growing FP fees. Working to reduce owner dependency and build team capability for succession.',
    now()
  ) ON CONFLICT (organisation_id) DO UPDATE SET
    purpose    = EXCLUDED.purpose,
    niche      = EXCLUDED.niche,
    updated_at = now();

  INSERT INTO public.targets (organisation_id, one_year_goals, updated_at) VALUES (
    v_life_id,
    E'FY2026–27:\n• Continue growing risk cases and FP fee revenue\n• Replace Sunny and stabilise the Life/FP team\n• Confirm IASO support allocation (~$15k pa, split 50/50 with GI)\n• Begin formalising Jo''s transition away from day-to-day Life/FP involvement\n• Develop training and development pathway for Fhevy',
    now()
  ) ON CONFLICT (organisation_id) DO UPDATE SET
    one_year_goals = EXCLUDED.one_year_goals,
    updated_at     = now();

  INSERT INTO public.leadership_team_members (organisation_id, name, role, responsibilities, sort_order)
  SELECT v_life_id, 'Jo', 'Director — Life / FP (transitioning)',
    E'Time allocation: 50% Life/FP (reducing over time)\n\nCurrently leads Life/FP client relationships and advice. Strategic goal is to reduce involvement progressively over the 7-year plan as succession plan develops.', 1
  WHERE NOT EXISTS (SELECT 1 FROM public.leadership_team_members WHERE organisation_id = v_life_id AND LOWER(name) = 'jo');

  INSERT INTO public.leadership_team_members (organisation_id, name, role, responsibilities, sort_order)
  SELECT v_life_id, 'Leah', 'Operations support',
    E'Time allocation: 10% Life/FP\n\nCross-unit support and coordination.', 2
  WHERE NOT EXISTS (SELECT 1 FROM public.leadership_team_members WHERE organisation_id = v_life_id AND LOWER(name) = 'leah');

  INSERT INTO public.leadership_team_members (organisation_id, name, role, responsibilities, sort_order)
  SELECT v_life_id, 'Fhevy', 'Support staff (development)',
    E'Ongoing development pathway to be formalised.\nTraining plan to be developed.', 3
  WHERE NOT EXISTS (SELECT 1 FROM public.leadership_team_members WHERE organisation_id = v_life_id AND LOWER(name) = 'fhevy');

  INSERT INTO public.issues (organisation_id, description, owner, status, category) VALUES
    (v_life_id, 'Sunny''s resignation — replacement needed urgently. Assess workload impact and begin recruitment.', 'Jo', 'open', 'current'),
    (v_life_id, 'Team stability — Life/FP capacity at risk following Sunny''s departure. Review team structure and cover arrangements.', 'Jo', 'open', 'current'),
    (v_life_id, 'IASO support allocation — $15k pa (split 50/50 with GI). Confirm and formalise arrangement in FY budget.', 'Leah', 'open', 'future'),
    (v_life_id, 'Jo succession plan in Life/FP — define timeline and steps for reducing Jo''s day-to-day FP client involvement.', 'Jo', 'open', 'future');

  -- ═══════════════════════════════════════════════════════
  --  IAS OUTSOURCING (IASO)
  -- ═══════════════════════════════════════════════════════

  INSERT INTO public.core_focus (organisation_id, purpose, niche, updated_at) VALUES (
    v_outsourcing_id,
    'Provide outsourced broking and admin support services to IAS business units (GI, Life/FP, HQ) and a growing external client base.',
    'Insurance admin and broking support outsourcing — a newer unit currently covering its expenses, with growth challenges as the client base expands.',
    now()
  ) ON CONFLICT (organisation_id) DO UPDATE SET
    purpose    = EXCLUDED.purpose,
    niche      = EXCLUDED.niche,
    updated_at = now();

  INSERT INTO public.targets (organisation_id, one_year_goals, updated_at) VALUES (
    v_outsourcing_id,
    E'FY2026–27:\n• Continue covering operating expenses while managing client base growth\n• Formalise shared IASO resource arrangement (~$30k pa, shared with IAS HQ)\n• Confirm and document internal support allocations: GI ($15k pa) and Life/FP ($15k pa)\n• Monitor capacity against growing client demand and plan resourcing ahead of need\n• Jo''s 10% IASO allocation confirmed for planning purposes',
    now()
  ) ON CONFLICT (organisation_id) DO UPDATE SET
    one_year_goals = EXCLUDED.one_year_goals,
    updated_at     = now();

  INSERT INTO public.leadership_team_members (organisation_id, name, role, responsibilities, sort_order)
  SELECT v_outsourcing_id, 'Leah', 'Operations Lead — IASO',
    E'Time allocation: 20% IASO\n\nOversees day-to-day IASO operations, resource allocation and client delivery.', 1
  WHERE NOT EXISTS (SELECT 1 FROM public.leadership_team_members WHERE organisation_id = v_outsourcing_id AND LOWER(name) = 'leah');

  INSERT INTO public.leadership_team_members (organisation_id, name, role, responsibilities, sort_order)
  SELECT v_outsourcing_id, 'Jo', 'Director (strategic oversight)',
    E'Time allocation: 10% IASO (confirmed for planning purposes)\n\nStrategic governance and direction for IASO.', 2
  WHERE NOT EXISTS (SELECT 1 FROM public.leadership_team_members WHERE organisation_id = v_outsourcing_id AND LOWER(name) = 'jo');

  INSERT INTO public.issues (organisation_id, description, owner, status, category) VALUES
    (v_outsourcing_id, 'Client base growth — IASO may face capacity challenges as external client numbers increase. Plan resourcing ahead of demand.', 'Leah', 'open', 'current'),
    (v_outsourcing_id, 'Shared IASO resource — ~$30k pa (shared with IAS HQ). Formalise cost-sharing arrangement and confirm in group budget.', 'Leah', 'open', 'future'),
    (v_outsourcing_id, 'Internal support allocations — GI ($15k pa) and Life/FP ($15k pa). Confirm IASO''s role and costs in servicing these units.', 'Leah', 'open', 'future');

  RAISE NOTICE 'v0.5.232 import complete. IASHQ=%, GI=%, Life=%, IASO=%', v_iashq_id, v_gi_id, v_life_id, v_outsourcing_id;
END $$;
