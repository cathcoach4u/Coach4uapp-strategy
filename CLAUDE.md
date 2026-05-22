# Claude Code Project Memory

> **Full version history lives in `CHANGELOG.md`.** This file is project memory: workflow, conventions, current state. Only the most recent change stays here as a pointer.

## Git Workflow
- Always push changes directly to `main` branch
- Commit with clear, descriptive messages
- Push after every commit — do not batch pushes
- **Bump version number with EVERY change** (patch: 0.5.x). **Five files MUST stay in sync:**
  1. `CLAUDE.md` → `## Current Version` line
  2. `VERSION` (just the number, e.g. `0.5.74`)
  3. `sw.js` → `CACHE_VERSION = 'coach4u-vX.Y.Z'`
  4. `business.html` → visible label at the bottom of the dashboard footer (`<p ...>vX.Y.Z</p>`)
  5. `index.html` → visible label at the bottom of the account dashboard footer (`<p ...>vX.Y.Z</p>`) — added v0.5.143 after the index footer was found stuck on v0.5.89
- Append a new entry to `CHANGELOG.md` for every bump. Keep the most recent 1–2 entries duplicated under `## Latest` in this file as a pointer.
- For large file changes: split into small focused files (each under ~8KB) to avoid push timeouts

## Project Overview
- **Your Business Coach** portal — PWA with Supabase authentication
- Hosted on GitHub Pages
- Uses email + password sign-in via Supabase
- **Repo visibility**: public (this is a GitHub Pages site). The Supabase anon key in this file is the `sb_publishable_*` (anon) variant, which is intentionally publishable — it's not a server-side secret. All security relies on Supabase RLS policies. **Never commit a `service_role` key.**

## Wording / Tone
- **No EOS jargon.** Removed in v0.5.116. Don't reintroduce: "Level 10" / "L10", "V/TO", "Vision/Traction Organizer", "Same Page Meeting", "IDS" / "Identify, Discuss, Solve" as a label, "Accountability Chart", "Right seat" / "right people", "GWC", "Quarterly Projects", "10-Year Target", "3-Year Picture", "Annual Meeting", "Headlines" (as a meeting agenda item), "Proven Process", "three uniques", verbatim "EOS", "Rocks" in user-facing copy. Use generic equivalents: "Weekly Team Meeting", "Org Chart", "Quarterly Goals", "10-Year Vision", "3-Year Outlook", "Annual Planning Session", "Customer & Team Highlights", "Discuss & Resolve", "Our Process", "What makes us different".
- The DB table `rocks` keeps its name (renaming would require a migration). UI surfaces it as "Quarterly Goals".

## Design System

**One design.** Aptos system stack, navy `#003366` primary, teal `#0D9488` accent — applied to every page in the project.

- Primary (navy): `#003366` | Primary dark: `#002244` (hover)
- Accent (teal): `#0D9488` | Accent dark: `#0F766E` (hover)
- Text: `#333333` | Muted: `#888888`
- Font: **Aptos system stack** — no Google Fonts
- Card border: `2px solid var(--accent)` or `1px solid var(--border)` depending on prominence
- Border-radius: `10px`
- Tip box (`.ws-hint`): `#f8fafc` bg, teal left border — used for "Explore X exercises in the Learning Vault →" prompts

Stylesheets:
- `css/style.css` — main design system v2.2 (loaded on every page)

## File Structure
```
index.html              — root portal: account dashboard with multi-tenant switcher
business.html           — business-level dashboard (one biz)
setup.html              — first-business wizard for brand-new users

# Hubs (business-level)
strategy.html           — Strategy hub (cards link to root worksheets) + View One-Page Plan
operations.html         — Operations hub + Run Weekly Meeting + View One-Page Operations
planning.html           — Planning hub (annual + quarterly session lists)
learning-vault.html     — reference / how-to area

# Strategy worksheets (Supabase-backed, scoped by organisation_id)
core-values.html, core-focus.html, targets.html,
marketing-strategy.html, leadership-team.html, financials.html

# Operations tools (Supabase-backed, scoped by organisation_id)
scorecard.html          — Weekly Numbers
goals.html              — Quarterly Goals (rocks table)
meeting.html            — past weekly meetings (list)
run-meeting.html        — single weekly meeting workspace
issues.html             — open + resolved issues

# Planning sessions (Supabase-backed)
annual-sessions.html, run-annual-session.html
quarterly-sessions.html, run-quarterly-session.html
team-checkin.html       — auth-gated team-facing check-in form (17 rated statements + name + optional role)

# Printable one-pagers (read-only)
one-page-plan.html         — landscape A4 strategy doc (per business)
one-page-operations.html   — landscape A4 ops doc: Quarterly Goals + Weekly Numbers + Open Issues (per business)

# Account-level cross-business pages
account-strategy.html, account-operations.html, account-planning.html  — account-level hubs
account-plans.html              — carousel of every business's one-page strategy doc
account-ops-plans.html          — carousel of every business's one-page operations doc
account-values.html, account-focus.html, account-targets.html,
account-marketing.html, account-leadership.html                — per-worksheet carousels
account-numbers.html, account-goals.html, account-meetings.html, account-issues.html
                                                              — per-operations-tool carousels
account-annual.html, account-quarterly.html, account-checkins.html
                                                              — planning carousels

# Auth + utility
login.html, forgot-password.html, reset-password.html
inactive.html           — shown when membership_status ≠ 'active'
offline.html, 404.html

learn/
└── values-discovery.html       — guided 3-step values exercise (localStorage)

css/
└── style.css           — Design 1 system v2.2

js/
├── auth.js             — sign in / out, membership gate
├── active-org.js       — tracks active business + active subscription in localStorage
├── active-session.js   — floating "Resume Planning Session" pill
└── supabase.js         — Supabase client + dashboard helpers

supabase/
├── schema.sql          — full source-of-truth schema
└── v0.5.NNN-delta.sql  — per-version migration files (run in order on first apply)
```

## Key Rules

### Pages and routing
- All HTML pages use Design 1 (`css/style.css`) — no exceptions.
- Strategy worksheets and Operations tools live at root and ARE the source-of-truth pages. `learn/` is reserved for reference / how-to content (guides, exercises like Values Discovery). `strategy.html` and `operations.html` cards must link to root URLs, not `learn/`.
- Bottom nav order is always: **Home / Planning / Strategy / Operations / Learn / Account** (v0.5.142+) — active item gets `.active` class. Account item links to `index.html`.
- Account-level pages use the white `.screen-toolbar` pattern (toolbar-back + toolbar-title); business-level pages use the navy `site-header` with `← Back · Your Business Coach · 🏢 [Business Name] pill`.

### Conventions every page must follow
- **Sign-out button** canonical ID: `id="signOutBtn"` (camelCase). Canonical class: `class="sign-out-btn"` (kebab-case). Both forms used together. JS lookups use `document.getElementById('signOutBtn')`.
- **Debounced text inputs** that auto-save (attendance, large textareas) use `setTimeout` debounce of **300ms** before writing. Checkbox toggles and button clicks save immediately.
- **Auto-resizing textareas** in worksheets use the `autoGrow(textarea)` helper (resize to `scrollHeight` on load + every keystroke).
- **No Google Fonts anywhere.** The Aptos system stack inherits from `css/style.css`.
- **Active organisation** is read via `window.activeOrg.get()` (exposes the current business id) and `window.activeOrg.getName()`. Set with `window.activeOrg.set(orgId, name)` when navigating into a business. Clears via `clear()`.
- **Active subscription** (multi-tenant): every account-level page that queries businesses MUST filter by the active subscription, otherwise it leaks data across client accounts. Pattern:
  ```js
  const subId = (window.activeOrg && window.activeOrg.getSubscription)
    ? window.activeOrg.getSubscription() : null;
  const memQuery = sb.from('team_members')
    .select('organisation_id, organisations!inner(id, name, subscription_id)')
    .eq('user_id', user.id).eq('status', 'active');
  if (subId) memQuery.eq('organisations.subscription_id', subId);
  const { data: mems } = await memQuery;
  ```
  The page must also load `<script src="js/active-org.js" defer></script>` for `window.activeOrg` to exist.

### Data layer (Supabase, organisation-scoped)
The localStorage-only stub is gone. Strategy worksheets, operations tools, planning sessions, and team check-ins all read/write Supabase, scoped by `organisation_id`. Tables (all in the `public` schema, all gated by RLS):

- **Strategy** — `core_values`, `core_focus`, `targets`, `marketing_strategy`, `leadership_team_members`, `financial_periods` (monthly revenue + expenses; 24-month window on the one-page plan)
- **Operations** — `scorecard_metrics`, `scorecard_entries`, `rocks`, `issues`, `meetings`, `meeting_headlines`, `meeting_todos`
- **Planning** — `annual_sessions`, `quarterly_sessions`, `team_checkins`
- **Multi-tenant** — `subscriptions`, `organisations`, `team_members`, `users`

RLS: any active team member can read; admins + coaches can write. `team_checkins` are readable by any active member of the org (aggregated results are transparent to the team) and INSERT-able by the submitting member.

LocalStorage is still used for:
- **Active org / subscription**: `coach4u_active_org_id`, `coach4u_active_org_name`, `coach4u_active_subscription_id`, `coach4u_active_subscription_name` (set by `js/active-org.js`)
- **Active planning session** (Resume pill): `coach4u_active_planning_session`
- **Operations demo stubs** (`coach4u_demo_meetings`, `coach4u_demo_rocks`, `coach4u_demo_scorecard`) — only `operations.html`'s "Run Weekly Meeting" button still reads `coach4u_demo_meetings`; the rest are vestigial. Slated for removal after the operations migration is fully verified.

## Multi-Tenant (v0.5.111+)
One user can own **multiple `subscriptions`** (one per client account). Active subscription tracked in localStorage as `coach4u_active_subscription_id`. UI:

- **Account switcher** at the top of `index.html` — `<select>` of every subscription the user owns + a `+ New client account` button (teal, top-right).
- **`+ New client account`** modal calls `create_client_account(account_name, business_name)` RPC → creates a new subscription + first business + admin team_member in one transaction, returns `(subscription_id, organisation_id)`. The new business becomes active and the user lands in `business.html`.
- **`+ New Business`** on the account dashboard calls `bootstrap_organisation(business_name, subscription_id)` — `subscription_id` is the currently-active sub, so the new biz lands in the right account.
- **Switching account** — the `<select>` change handler sets `setSubscription(...)`, clears the active org cache, and reloads. The membership query on the account dashboard scopes via `.eq('organisations.subscription_id', activeSub.id)` so each account's businesses are isolated.

Every `account-*.html` carousel page applies the same subscription scoping (v0.5.116). Without it the carousel would mix businesses across every account the user owns.

## Login Page Standard (Gold Standard v2.2)

`login.html` uses gold standard — no inline `<style>` blocks, no Google Fonts, `css/style.css` handles all login styling.

Required `<head>` structure:
```html
<link rel="manifest" href="manifest.json">
<meta name="theme-color" content="#003366">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Your Business Coach">
<link rel="stylesheet" href="css/style.css">
```

Post-login redirect: `index.html` (root portal). `login.html` honours a same-origin `?returnTo=` param (used by `team-checkin.html` to bounce the user back after sign-in).

## Supabase
Single project for auth + database. Every page uses the same client:
- URL: `https://eekefsuaefgpqmjdyniy.supabase.co`
- Anon key (publishable): `sb_publishable_pcXHwQVMpvEojb4K3afEMw_RMvgZM-Y`

The anon key is intentionally exposed — it's a `sb_publishable_*` key, designed for client-side use. Security is enforced via Supabase **Row Level Security (RLS)** policies on each table. **Never commit the `service_role` key** (server-side secret).

Always use unversioned import:
```js
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';
```

## App URLs
- **Production** (only): `https://cathcoach4u.github.io/yourbusinesscoach/`
- No staging or branch preview URLs. GitHub Pages deploys `main` directly on every push.

## Current Version
v0.5.144

## Latest
- **v0.5.144** — Added the Account nav item to `index.html` (marked `.active` since it IS the account dashboard) and to the three account-level hubs (`account-strategy.html`, `account-operations.html`, `account-planning.html`). User feedback after v0.5.142: "But if this is the case where is the account area located. Because it's not down bottom." Diagnosis: the v0.5.142 change skipped `index.html` and the account hubs on the (mistaken) theory that "a back-to-here button is redundant" — but that made the bottom nav inconsistent (5 items on account-level pages, 6 on business-level pages), which made the change invisible from the page the user was actually viewing. Fixed by adding the 6th item everywhere; on `index.html` it gets `.active` to indicate "you are here". Nav is now uniformly 6 items across every page.
- **v0.5.143** — Fixed the version label on the account dashboard. `index.html`'s footer was stuck on `v0.5.89` because the version-bump checklist only covered `business.html`'s footer — `index.html` was missed for ~54 versions. User report: "I only see v 0.5.89" on the account dashboard, even though business pages and the live `VERSION` file showed v0.5.142. Bumped index.html's footer to v0.5.143 and added `index.html` to the five-files version-bump checklist in CLAUDE.md so this doesn't drift again. The actual functionality (Account nav item added v0.5.142, etc.) was already live — only the visible label was misleading.
- **v0.5.142** — Added an **Account** item to the bottom nav, sitting after Learn (🏛️ icon → `index.html`). User feedback: "the flow needs to be easier to get back to the main accounts page. can we add this as a box next to learn?" Previously the only way back to the multi-business account dashboard was through the navy header's `← Back` (which goes to `business.html`, not `index.html`) or the breadcrumb chain. Now every business-level page (22 files including `business.html`, all 4 hubs, every operations tool, every strategy worksheet, planning list pages, sessions, learning vault) has a one-tap path to the account dashboard. The bottom-nav is now 6 items: Home / Planning / Strategy / Operations / Learn / Account. Account-level pages (`account-*.html`) and `index.html` itself are unchanged.
- **v0.5.141** — Header layout rework. User feedback: "move the pill for the drop down out of the main header and put it to the right side of the screen and I want it a square 'pill'. And Your business coach more at the top." Done — `js/active-org.js` now detaches `#activeBizName` from the navy header on init and moves it into a new sticky sub-toolbar (`.biz-switcher-bar`) right under the header, right-aligned. Pill border-radius dropped from 14px → 6px (square-ish). Removed the v0.5.124/130 hide-title-on-phones CSS rule since the pill no longer crowds the navy bar — "Your Business Coach" now shows on every viewport and is slightly bolder (font-weight 800, 1.05rem on phones).
- **v0.5.140** — Manual reordering for businesses. New `sort_order` column on `organisations` (default 0). On the account dashboard, each biz card gets a small ↑/↓ pair (admins only, hidden when there's just one biz). Click swaps sort_orders with the adjacent biz, persists both, re-renders. The v0.5.139 navy-header switcher dropdown picks up the new order too (cache busted automatically). **Requires SQL** — see `supabase/v0.5.140-delta.sql`.
- **v0.5.139** — Business-switcher dropdown in the navy header. User feedback: "if I'm in issues I need go to each issue for each business with a drop down." When the active subscription has 2+ businesses, the `🏢 [Biz Name]` pill on every business-level page is now a `<select>` listing every biz the user is admin/coach/member of in the active account. Picking a different biz calls `activeOrg.set(...)` and reloads the same page — so you stay on Issues / Goals / Scorecard / Meeting / etc. but viewing the other business's data. Lazy-loads Supabase only when needed; caches the business list in localStorage for 5 minutes. Account-scope session pages still show `🏛️ [Account]` (v0.5.135) — the override now marks the pill `data-overridden="1"` so the switcher doesn't replace it back.
- **v0.5.138** — "Make a goal →" button on the issues modal. User asked for a way to promote an issue into a quarterly goal "on the back of" the issue — common flow in IDS: discuss issue → decide it's a strategic priority → make it a goal. Button appears on existing issues (not on the Add-new modal, since the issue needs an ID to be promoted). Click confirms, then: (1) inserts a new `rocks` row for the current quarter with the issue's description + owner pre-filled, (2) marks the issue as `resolved` with the solution note "Promoted to Q[n] [YYYY] goal: '[description]'", (3) navigates to `goals.html` so the user can finish setting up the new goal (set SMART criteria, on/off-track status, etc.). Uses the active org's `currentQuarter()`.
- **v0.5.137** — Added a Financial Outlook strip to the Operations one-pager (`one-page-operations.html`) and the account-level operations carousel (`account-ops-plans.html`). Two compact columns at the bottom: **Last Year** (full-year totals) and **This Year** (YTD totals), each showing Revenue / Expenses / Profit. Reads from the same `financial_periods` table the Strategy one-pager uses; aggregates by calendar year (Jan–Dec). The carousel version buckets per business so each card shows that business's own annual totals. Empty business years show "—". Print rules added so the strip stays on the same landscape-A4 page as the rest of the doc.
- **v0.5.136** — Inside an account-scoped annual or quarterly session, the area-link buttons now point at the account-level carousel pages instead of the business-scoped worksheets. User report: "the links in the annual session ie targets needs to go to the IAS area, not the outsourcing." Diagnosis: links like `Open Targets →` were hardcoded to `targets.html`, which is biz-scoped — so it opened whatever business was last active (Outsourcing, in this case), not the account context. **Fix:** added an `ACCOUNT_LINK_MAP` in `run-annual-session.html` + `run-quarterly-session.html` that swaps `targets.html → account-targets.html`, `core-values.html → account-values.html`, `core-focus.html → account-focus.html`, `marketing-strategy.html → account-marketing.html`, `leadership-team.html → account-leadership.html`, `goals.html → account-goals.html` when the session row has `subscription_id` set (no `organisation_id`). Biz-scoped sessions are unchanged.
- **v0.5.135** — Fixed a UX bug on account-scoped planning. User reported: "iasHQ - click on planning - start a planning day and it's opening the general business." Diagnosis: the SQL is correct (sessions are inserted under the right subscription_id), but the navy header pill `🏢 [Biz Name]` was still showing whatever business was last active (Coach4U from SARUBA, in their case) — making an account-scoped session look like it belonged to that biz. **Fix:** on `annual-sessions.html?scope=account`, `quarterly-sessions.html?scope=account`, `team-checkins.html?scope=account`, and their workspaces (`run-annual-session.html`, `run-quarterly-session.html` when the loaded session has `subscription_id` set), the pill is now overridden to `🏛️ [Account Name]` so the user can see at a glance that they're in account-level mode. Also hid the "View One-Page Plan" / "Open Quarterly Goals" hint links on the account-scope list pages — they link to business-scoped destinations that don't apply at account level.
- **v0.5.134** — Better error toasts on the three "+ New" buttons (Annual / Quarterly / Team Check-in) so a swallowed insert error now surfaces actionable text. If the column `subscription_id` is missing → "SQL not applied — run supabase/v0.5.132-delta.sql". If RLS denies → "Permission denied — you need to be the account owner". If a CHECK constraint fails → "Schema mismatch — re-run v0.5.132-delta.sql". Otherwise the raw Postgres message. Helps the user self-diagnose instead of guessing why the button "isn't working".
- **v0.5.133** — Hygiene fix: `supabase/schema.sql` lines 59-60 now use `DROP FUNCTION IF EXISTS … CASCADE` instead of bare `DROP FUNCTION IF EXISTS`. When schema.sql is run on a populated DB (which shouldn't happen — schema.sql is for fresh installs; deltas are for incremental migrations), the bare DROP fails because the `financial_periods` policy (added v0.5.117) depends on `user_org_ids`. CASCADE makes the DROP succeed and cleans up dependent policies — schema.sql goes on to recreate them. No app-level change.
- **v0.5.132** — **Dual-mode planning + new Team Check-ins module.** Planning sessions (annual + quarterly) and a new check-in batches concept can now live at either business level (existing) or account level (new). User can pick when creating. The new `team-checkins.html` + `run-team-checkin.html` pair lets admins run pulse surveys outside any planning session — name + date + invitees + share link + aggregated results. Batch results are **admin-only** (RLS). Account-level batches let an admin analyse pulse data across every business in the account. Existing per-session check-ins (annual/quarterly) unchanged. Also added: **delete-meeting** button on `meeting.html` so an unintentional meeting can be removed. **Requires SQL** — see `supabase/v0.5.132-delta.sql`: new `checkin_batches` table, both `annual_sessions` and `quarterly_sessions` get a nullable `subscription_id` (and their `organisation_id` becomes nullable; a scope CHECK enforces exactly one set), `team_checkins.session_type` widened to include `'batch'`, two new helper functions `user_account_ids` and `user_admin_account_ids`, and RLS rewritten across the three session tables to handle both scopes.
- **v0.5.131** — Improved the Annual Planning Session workspace. User feedback: "the EOS way is too structured" — want richer, flexible capture. Added three new sections to `run-annual-session.html`: **(1) Session Resources** — a list of `{label, url}` external links so the user can paste their own Zoom recording, slides, Google Drive folder, photos URL etc. No files are uploaded; the app only stores text URLs. **(2) Session Notes** — a big free-form textarea for decisions, energy of the room, what surprised you, what you'd do differently next year. **(3) Personal Commitments** — a list of `{name, commitment}` for the "One Thing" each leader commits to for the year (carries into quarterly sessions). All three auto-save (500ms debounce) and mobile-friendly. **Requires SQL** — see `supabase/v0.5.131-delta.sql` which adds `notes text`, `external_links jsonb`, `commitments jsonb` columns to `annual_sessions` (no RLS changes — existing policies cover them). Keeps the existing 4-area checklist as a lightweight preflight; the new sections are where the substance lives.
- **v0.5.130** — Three things: **(1)** Dropped all dead Coach4U sample-data seeds from `business.html`'s `ensureSeeds()` (the strategy ones were already gone in v0.5.113; this version removes the demo operations + planning seeds — `coach4u_demo_meetings`, `coach4u_demo_rocks`, `coach4u_demo_scorecard`, `coach4u_demo_issues`, `coach4u_annual_sessions`, `coach4u_quarterly_sessions`). 130 lines of dead code gone; every page now reads from Supabase. The function stays as a no-op so the existing callsite in `init()` doesn't have to be edited. **(2)** Rewrote `operations.html`'s "Run Weekly Meeting" button to use Supabase (was the last reader of `coach4u_demo_meetings`) — finds or creates a `meetings` row for this Monday and navigates to `run-meeting.html?id=…`. **(3)** Mobile keyboard handling: new `js/mobile-keyboard.js` wired into all 61 pages — listens for input focus, waits ~350ms for the keyboard, and scrolls the focused field to the centre of the viewport so iOS doesn't hide it. Pair with `scroll-margin-bottom: 260px` on inputs in `css/style.css`, and `body.keyboard-open .ws-save-bar { transform: translateY(120%) }` to slide the save-bar out of the way while typing. **(4)** Restored the "Your Business Coach" title in the navy header on phones for account-level pages — the v0.5.124 fix was too aggressive and left `index.html` with an empty left side on first launch. New rule uses `:has(.biz-pill:not(:empty))` so the title only hides when there's a populated biz pill competing for space (business-level pages).
- **v0.5.129** — VB2 source arrived (`EOS-VB2-Implementer-Guide.pdf`, moved into `/EOS/`), so the two guides the audit couldn't fully verify against a source got the missing depth. **Marketing Strategy** rewritten from ~200 words to ~700: DGP framework (Demographic / Geographic / Psychographic) → "The List" as a filter; 3 Differentiators competitor-line-up test ("you're the only one that does all three" — Southwest 3LFs reference); Process and Guarantee as explicit YES/NO decisions; Rule of 7 callout. **Targets** 3-Year and 1-Year sections got the "shot over the bow then debate" framing, the specific bullet prompts (employees, clients, locations, products, role), the 5–15-bullet target with "err on leaving something on", and the full **see-it / want-it / believe-it** three-question test (not just "see it"). 1-Year Plan got the explicit reference to Issues List + Org Chart when answering "what are the most important things", one-at-a-time onto-the-board, and the full closing read-back. Also moved the uploaded `EOS-VB2-Implementer-Guide.pdf` from the repo root into `/EOS/` to match the rest.
- **v0.5.128** — Fixed a wording bug in the Annual Planning Session guide's Coach's tip. Reported by user: the tip in the Annual guide said "if you wait, it'll slip into a busy quarter, then slip again" — recycled phrasing from the Quarterly tip that doesn't fit the annual cadence (annuals slip across years, not quarters). Rewrote to: "If you wait, the date gets eaten by busy quarters and the year quietly disappears." Front-end one-line copy fix.
- **v0.5.127** — Removed the standalone Values Discovery interactive exercise. User feedback: "I don't think the run the values guide is needed. It's just not helpful compared to the comprehensive other document." Deleted `learn/values-discovery.html` entirely. Removed the "Run the Values Discovery exercise" link from `learning-vault.html`'s Core Values card and from the bottom CTA row of `learn/core-values.html`. The deepened Core Values guide (v0.5.125 — 800 words covering the 100-of-them prompt, two-pass Keep/Kill/Combine, Lencioni's three traps, the People Test + Five-Use Test) replaces it; running the exercise from the guide is the new flow.
- **v0.5.126** — Deepened the other 9 light Learning Vault guides to match the depth of v0.5.125's Core Values rewrite. Each now has a structured exercise section with timings, the actual prompts the facilitator runs, the keep/kill/combine and silent-write-then-share patterns, and the closing visualisation / read-back checks that the EOS implementer guides use. Sources: the EOS implementer guides under `/EOS/` (Focus Day, VB1, Quarterly Rocks, Scorecard, Level 10, Issues Solving Track, Quarterly Debrief), plus the Lencioni 5-Dysfunctions framework and Covey's Big Rocks metaphor (both non-EOS public references). No EOS trademark terminology in user-facing copy — the v0.5.116 wording rules still apply. The Marketing Strategy, Financials, and Team Check-in guides were left as-is (audit verdict: SOLID / no EOS source to compare against).
- **v0.5.125** — Rewrote `learn/core-values.html` with full EOS-implementation depth. User noted the guide was "a little light on" compared to the original EOS implementation experience. The new guide adds: the **"100 of them" prompt** (think of 3 people you'd want 100 of), the **2-hour exercise flow** (silent listing → characteristics on the board → two passes of Keep/Kill/Combine separated by a break), **Lencioni's three value traps** (Accidental / Aspirational / Permission-to-play, with a test for each), and **two tests for finished values** (the People Test — score 3–5 real team members 1–5 against each value; the Five-Use Test — would you actually use this to hire / fire / review / reward / recognise?). Grew from ~200 words to ~800. No EOS trademark terminology used (rules from v0.5.116 preserved) — the methodology comes from the EOS implementer guides in `/EOS/`, the Lencioni traps from a 2002 HBR article. Parity audit of the other 12 guides is running and will inform v0.5.126.
- **v0.5.124** — Decluttered the navy site-header on phones. At ≤ 640px viewports the bar was packing four competing elements (← back, "Your Business Coach" title, 🏢 biz pill, Sign Out) into ~390px and reading as busy. Hid the title text on phones — the brand presence is preserved everywhere else (PWA name on the home screen icon, page H1 below the header, back link to the parent section). Bar now reads `← Back · 🏢 [Biz Name] · Sign Out`. Slightly tightened padding (12 → 10px vertical) and gave the biz pill more room (max-width 110 → 160 at 480px, 90 → 120 at 400px). No change above 640px — tablet/desktop header is unchanged.
- **v0.5.123** — Fixed the broken PWA install. Three things were wrong: (1) `manifest.json` had a stale `/external-Coach4u-app/` `start_url` + `scope` + icon paths from a previous repo, so iOS launched the installed app at the old URL and couldn't load the icon (fell back to its auto-generated "C"). Rewrote with relative paths (`./`, `./icon-192.png`, `./icon-512.png`). (2) Only `business.html` and `setup.html` declared `<link rel="apple-touch-icon">` (and both pointed at `favicon.svg`, which iOS doesn't reliably honour as a home-screen icon). Added `<link rel="apple-touch-icon" sizes="180x180" href="apple-touch-icon.png">` to every page (57 files, including learn/). (3) Generated real PNG icons (180/192/512) showing **BC** — white B + teal C — on the navy gradient background, matching the brand. Also updated `favicon.svg` to match the new BC mark.
- **v0.5.122** — Smart back link on every Learning Vault guide. Before: the guide's header back link always went to the Vault index, even if the user had just clicked through from a worksheet (e.g. arrived at `learn/quarterly-goals.html` from `goals.html`'s tip box). After: each guide now checks `document.referrer` on load — if the visitor came from the matching worksheet/tool, the header back link swaps from `← Learning Vault` to `← Quarterly Goals` (or whichever section it was), so "back" actually goes back. If they came from the Vault index, the link stays `← Learning Vault`. The explicit `← Back to Learning Vault` link at the bottom of every guide stays put — the Vault is always one click away regardless.
- **v0.5.121** — Deep-linked the in-page Learning Vault tip box on every worksheet and operations tool to its specific guide. Before: clicking the teal "Explore X in the Learning Vault →" inside `goals.html` (or any other worksheet) dumped you on the generic Vault index, where you had to find the matching card. After: it goes straight to `learn/quarterly-goals.html` (the activity-specific guide), labelled "Read the Quarterly Goals guide →". Applied to all 10 activity pages (5 strategy worksheets + Financials + 4 operations tools). The bottom-nav "Learn" tab still goes to the Vault index — that's the entry point for browsing all activities.
- **v0.5.120** — Wrote actual content for every Learning Vault guide. v0.5.119 shipped the index but the "Read guide" buttons were placeholders; the user pushed back ("I don't see what value you have offered, the links don't go to the actual page"). This version creates **13 real guide pages** under `learn/<slug>.html` — one for each activity — each with What this is / Why it matters / How to do it well / Common pitfalls / Coach's tip. The Vault now has a live `Read the guide →` primary CTA on every card. The worksheet link drops to a secondary ghost button on each card. The Core Values card keeps the Values Discovery exercise as a third action.
- **v0.5.119** — Rebuilt the Learning Vault as a structured activity index mapped to the full Coach4U program. 13 cards across 3 sections: **Strategy** (6 — Core Values, Core Focus, Targets, Financials, Marketing Strategy, Leadership Team), **Operations** (4 — Quarterly Goals, Weekly Numbers, Weekly Team Meeting, Issues), **Planning** (3 — Quarterly Planning Session, Annual Planning Session, Team Check-in). Every card has an **Open worksheet/tool** primary CTA (live) and a **Read guide · Coming soon** ghost button reserving the slot for future written content. The existing `learn/values-discovery.html` exercise stays — surfaced as the secondary CTA on the Core Values card. No SQL, no schema.
- **v0.5.118** — Simplified the Financial Outlook on `one-page-plan.html` and the `account-plans.html` carousel. Previously the strip rendered a 12-row × 4-column mini-table per side (month × Rev × Exp × Profit + totals row); now each side shows just the **12-month totals** as three big lines: Revenue, Expenses, Profit. Less visual noise on the printed one-pager. The `financials.html` worksheet is unchanged — that's still where the per-month figures live.
- **v0.5.117** — **Monthly financials on the one-page plan.** New `financials.html` worksheet (linked from Strategy) lets the admin/coach enter monthly revenue + expenses for the **last 12 months (actuals)** and **next 12 months (forecast)** — 24 month rows total, profit auto-calculates per row + totals. Auto-saves to a new `financial_periods` Supabase table (`(organisation_id, period)` unique, nullable revenue + expenses). RLS: members read, admins+coaches write — same pattern as the rest of the strategy tables. The **bottom strip of `one-page-plan.html`** now renders a two-column financial outlook (Last 12 / Next 12 side by side, month × Rev × Exp × Profit, with totals row). **`account-plans.html`** carousel renders the same block per business so cross-business reviews include the financials. Multi-tenant aware — every read is `eq('organisation_id', orgId)`; the carousel scopes to the active subscription as of v0.5.115. **Requires SQL** — see `supabase/v0.5.117-delta.sql`.
- **v0.5.116** — Two big sweeps. **(1) Multi-tenant scoping** applied to the 12 remaining account-level carousel pages (`account-numbers`, `account-goals`, `account-meetings`, `account-issues`, `account-values`, `account-focus`, `account-targets`, `account-marketing`, `account-leadership`, `account-annual`, `account-quarterly`, `account-checkins`). Each now loads `js/active-org.js` and filters the `team_members` query by `organisations.subscription_id = activeSub.id`, matching the fix already applied to `account-plans.html` and `account-ops-plans.html`. **(2) EOS de-jargoning** — removed every verbatim EOS term from user-facing copy: "Level 10 Meetings" → "Weekly Team Meetings"; meeting agenda "Customer & Employee Headlines" → "Customer & Team Highlights"; "Issues — Identify, Discuss, Solve" → "Issues — Discuss & Resolve"; "Our three uniques" → "What makes us different"; "Our Proven Process" → "Our Process"; "3-Year Picture" → "3-Year Outlook" across worksheets and one-pagers; "quarterly Rocks" → "quarterly priorities". Rewrote all 17 team-checkin questions (replicated in `team-checkin.html` / `run-annual-session.html` / `run-quarterly-session.html`) to drop "Accountability Chart", "right seat / right people", "Quarterly Projects", "Annual Meetings", "10-Year Target", "3-Year Target" — order and meaning preserved so historical 1-5 scores still map to the same conceptual statements.
- **v0.5.115** — Account-level companion to v0.5.114. New **`account-ops-plans.html`** — carousel of every business's one-page operations doc, linked from `account-operations.html`. Same scoping fix backported to `account-plans.html` (strategy carousel).
- **v0.5.114** — New **`one-page-operations.html`**, parallel to `one-page-plan.html`. Landscape A4, three columns: Quarterly Goals · Weekly Numbers · Open Issues. Linked from `operations.html`.

## Current Status
- **Account dashboard** (`index.html`) — post-login landing; multi-tenant switcher + account header + stats + businesses list + users list (all Supabase-backed).
- **Business dashboard** (`business.html`) — single-business workspace; reads 1-Year Goal + Core Values panels from Supabase (`targets` + `core_values`), scoped to active organisation. Empty-state placeholders when no rows.
- **Hubs** — `strategy.html`, `operations.html`, `planning.html`, `learning-vault.html` — uniform Design 1 layout. Each links to a printable one-pager (`one-page-plan.html` for strategy, `one-page-operations.html` for ops; planning has no one-pager yet).
- **Strategy worksheets** — Supabase-backed, scoped by active org. Feed both `one-page-plan.html` and `account-plans.html`.
- **Operations tools** — Supabase-backed (rocks, scorecard_metrics + entries, issues, meetings + headlines + todos). Feed `one-page-operations.html` and `account-ops-plans.html`.
- **Planning sessions** — Supabase-backed (`annual_sessions`, `quarterly_sessions`). Workspaces use attendance checklist + team check-in share link. Aggregated check-in results visible to the whole team.
- **Team Check-in** — `team-checkin.html` is **auth-gated** (login required; honours `?returnTo=` param). 17 rated statements + name + optional role. Submissions write to `team_checkins` keyed by session_id + session_type. EOS-flavoured wording removed in v0.5.116.
- **Resume pill** — floating "Resume Planning Session" pill on every page when a session is in progress (`coach4u_active_planning_session`).
- **Mobile**: Responsive at 390px and 768px breakpoints.
- **Login**: Gold standard v2.2.
- **Accountability Chart & Team Alignment**: MOVED to `yourteamcoach`.

## Architecture (Supabase + Multi-Tenant)

The app is fully on Supabase. Team-scoped, role-based, multi-tenant.

### Team model
- A **buyer owns a `subscription`** with N seats and is the first Admin of every business inside it. One buyer may own multiple subscriptions (one per client account).
- Each team member has their own auth login but data is **team-scoped, not user-scoped** — one shared dataset per organisation.
- **3 roles**:
  - **Admin** — full edit access; invites/removes other members; renames/deletes the business itself.
  - **Coach** — admin-equivalent for data + team operations (full edit, invite/remove), but **exempt from per-seat billing**. Cannot rename or delete the business. Use case: the coach lives inside the client's account without consuming one of the client's seats.
  - **Member** — reads team data; submits check-ins; cannot edit team data.

### Schema overview (see `supabase/schema.sql` for the source of truth)
```
subscriptions   (id, owner_user_id, name, seat_count=3, included_businesses=1, status, stripe_*)
organisations   (id, subscription_id, name)
team_members    (id, organisation_id, user_id, invited_email, role, status, display_name, joined_at)
                — role: 'admin' | 'coach' | 'member'  |  status: 'pending' | 'active' | 'removed'
users           (id, email, membership_status)   — mirror of auth.users for gating

# strategy + operations + planning data
core_values, core_focus, targets, marketing_strategy, leadership_team_members
scorecard_metrics, scorecard_entries, rocks, issues
meetings, meeting_headlines, meeting_todos
annual_sessions, quarterly_sessions, team_checkins
                — all scoped by organisation_id
```

### RLS pattern
- **READ** (most tables): active team member of the org.
- **WRITE** (most tables): admins + coaches of the org (helper `user_admin_org_ids()` returns both roles).
- **`team_checkins`**: read by any active member; INSERT by the submitting member only.

## Pricing Model

Locked-in for launch:

| Item | Price |
|---|---|
| **Base license** — 1 business + 3 users included | **$150/month** |
| **Each additional business** | **$75/month** |
| **Each additional user** beyond the included 3 | **$60/month** |

### Key principles
- **Users are global per account**, not per business. One person who's a member of 3 businesses counts as 1 seat. Matches Notion / Slack / Linear.
- **Subscriptions are account-level** (one subscription per buyer), not per-organisation. The buyer's account can hold N businesses + M users.
- **Each business is fully isolated** by data — own One-Page Plan, scorecard, sessions, issues — but shares the global user pool.
- **Coaches** are admin-equivalent for data but billing-exempt (so the coach inside a client's account doesn't consume one of the client's seats).

### Worked examples

| Client | Configuration | Monthly |
|---|---|---|
| Solo founder | 1 business, 1 user | **$150** (3 user seats included, only 1 used) |
| Small team | 1 business, 5 users | $150 + (2 × $60) = **$270** |
| Holding co | 3 businesses, 3 users | $150 + $75 + $75 = **$300** |
| Same with more leaders | 3 businesses, 5 users | $300 + (2 × $60) = **$420** |
| Larger holding | 5 businesses, 12 users | $150 + (4 × $75) + (9 × $60) = **$990** |

Billing logic on subscription change:
- Add a business → `+$75/month`
- Add a user beyond the included 3 → `+$60/month`
- Remove a business → prorated refund / next cycle
- The buyer's account = the entity Stripe (or chosen billing provider) bills

## Add a New Member (SQL)

```sql
INSERT INTO users (id, email, membership_status)
SELECT id, email, 'active'
FROM auth.users
WHERE LOWER(email) = LOWER('email@here.com');
```
