# Changelog

All notable changes to the project. The two most recent entries live in `CLAUDE.md`; everything else is here.

---

## v0.5.227
- **Coach account switcher — links to existing client subscriptions.** `index.html` `loadAll()` now runs a second query: fetches all `team_members` rows where `user_id = current` and `role = 'coach'`, extracts unique `subscription_id` values from the joined organisations, filters out already-owned subscriptions, and fetches those subscription rows. The result is appended to `allSubs` with `_isClient: true`. `renderSwitcher()` prefixes those entries with "Client: " in the dropdown. RLS previously blocked reading other users' subscriptions — SQL migration `v0.5.227-delta.sql` adds `"team members read their org subscription"` policy so any active team member can SELECT the subscription their org belongs to. Same migration inserts Cath as a `'coach'` team_member (status=active) in every organisation whose subscription name matches `%saruba%` or `%ias%` (and is not owned by Cath), with a `NOT EXISTS` guard to prevent duplicates. **Requires SQL**: run `supabase/v0.5.227-delta.sql` in the Supabase SQL Editor.

## v0.5.226
- **Coach account support in account-setup.html.** `loadSub` now fetches `subscription_type`. `renderPlanCard()` checks if `subscription_type === 'coach'` and renders a "Coach Account" card — shows Role: Coach in teal, lists own businesses, hides the billing limit entirely, and shows a note pointing to the account switcher for client access. Non-coach accounts are unchanged. SQL migration `supabase/v0.5.226-coach-setup.sql` updates Cath's subscription to `subscription_type = 'coach'` and `included_businesses = 99` — must be run in Supabase SQL Editor. Once run, her card moves from Business Subscriptions → Coaches section in admin.html.

## v0.5.225
- **account-setup.html: Subscription summary card + Save-button-only saving.** Two changes. **(1) Auto-save removed** — the 3-second debounce that silently saved form changes has been removed. The Save button (always visible, greyed out until dirty, teal when there are changes) is the sole save trigger. A `beforeunload` fallback still attempts a save if the user navigates away with unsaved changes. **(2) Subscription summary card** added between the billing form and the Data Export card. Shows: plan Status (Trial / Active / Past due / Cancelled, colour-coded), Businesses used vs allowed (colour-coded green/amber/red against `included_businesses`), and a full parent/child business tree — parent businesses shown with 🏢 icon, children indented with ↳. Renders from a live `organisations` query scoped to `sub.id`. If at the plan limit, shows "To add more businesses, contact your coach." `loadSub` select expanded to include `status` and `included_businesses`. **No SQL.**

## v0.5.222
- **Trial-release hardening pass: fixed PWA caching, deleted legacy hubs, added data export, group financials rollup, better empty states, swipe-to-delete on todos.**

### (1) Service worker paths — actually correct now
`sw.js` was anchored on `/external-Coach4u-app/` (a path that doesn't exist on this repo). PWA install + offline fallback were silently broken:
- `cache.addAll(STATIC_ASSETS)` failed because every entry 404'd → no static cache, no offline support
- The HTML offline fallback `caches.match('/external-Coach4u-app/offline.html')` never resolved → users got the browser's default offline page

**Fix**: rewrote `sw.js` with relative paths (`./`, `./offline.html`, `./css/style.css`, `./js/active-session.js`, etc.). Resolved against the SW's location at install time, so it works on GitHub Pages (`/yourbusinesscoach/`) and any local subpath.

Also dropped the legacy `/api/` cache branch — no app code hits that path; all DB calls go to Supabase directly. CACHE_VERSION bumped to `coach4u-v0.5.222` so every previous cache is invalidated on next page load.

### (2) Legacy account hubs deleted
`account-strategy.html` / `account-operations.html` / `account-planning.html` have been dead since v0.5.146 when the account-level bottom nav was simplified. The only references were `if (back) { back.setAttribute('href', 'account-planning.html'); ... }` guards on `annual-sessions.html` / `quarterly-sessions.html` / `team-checkins.html` — but `.header-back` was removed from those pages in v0.5.191, so `back` was always null and the assignment was a silent no-op.

Files deleted; the dead `if (back)` lines stripped from the three session list pages.

### (3) Data export
New **📥 Data Export** card on `account-setup.html`. One row per business in the active subscription with a `⬇ Export JSON` button.

**Contents** (per business, RLS-gated):
- Strategy: `core_values`, `core_focus`, `targets`, `marketing_strategy`, `leadership_team_members`, `financial_periods`
- Operations: `scorecard_metrics` + `scorecard_entries` (joined), `rocks`, `issues`, `meetings` + `meeting_headlines` + `meeting_todos` (joined)
- Planning: `business_cadence`, `annual_sessions`, `quarterly_sessions`, `team_checkins`
- Multi-tenant: `organisations` row, `team_members` (role + status + display_name + invite metadata)

**Format**:
```json
{
  "exported_at": "2026-05-24T10:42:13.000Z",
  "app_version": "0.5.222",
  "schema": "coach4u-business-snapshot/v1",
  "business_id": "...",
  "business_name": "...",
  "data": { /* tables keyed by name */ }
}
```
Filename: `coach4u-<safe-biz-name>-YYYY-MM-DD.json`. Schema versioned so future migrations can detect snapshots from older releases. No server-side code — fully client-side using the user's existing Supabase session.

### (4) Group Financials rollup on account-plans
`account-plans.html` now renders a **💰 Group Financials** banner above the carousel summing every business's `financial_periods` into one Last-12 / Next-12 view. Only appears when there are 2+ businesses AND any of them have financial data (otherwise it'd just show "—" everywhere, adding noise). Hidden in print mode — each per-business card already prints its own financials, no point printing the rollup twice.

### (5) Empty-state copy upgrades
Three of the most-hit pages used to say "Nothing here" with no next-step prompt. Now each empty state links to the matching Learn vault guide:
- `goals.html` — "Pick 3–7 priorities — the things that, if completed, move the business forward this quarter. → Read the Quarterly Goals guide"
- `scorecard.html` — "Pick 5–10 numbers that tell you each week whether the business is on track. → Read the Weekly Numbers guide"
- `meeting.html` — "Same day, same time, same agenda every week. → Read the guide"

Other empty states (todos, issues, sessions) already had reasonable copy.

### (6) Swipe-to-delete on To-Dos
New `js/swipe-delete.js` helper — touch-only, opt-in via `.swipeable` class.

**Behaviour**:
- Touchstart → record position
- Touchmove → if mostly horizontal AND going left, translate the row's content; reveal a red "Delete" backdrop behind
- Touchend at < 50% of row width → snap back to 0; > 50% → animate fully off-screen + trigger the existing `.todo-del` click handler (same Supabase delete + optimistic UI path)
- Vertical scroll wins if dy > dx in the first 12px → swipe is cancelled, page scrolls normally

Desktop (no touch events) is unchanged — the existing × delete button still works. Auto-attaches via MutationObserver so re-rendered rows pick it up without manual rewiring.

**Applied to** `todos.html` (added `.swipeable` class + script tag). Layout adjusted so the swipeable rows put their flex layout on the inner `.swipe-content` wrapper.

**Not applied to** `issues.html` (the cards have a click-to-edit handler that would conflict with a horizontal touch gesture) or scorecard cells (popovers + numeric inputs make this risky). Both can opt in later once the gesture conflict is resolved.

### Files
- `sw.js` (rewritten)
- `account-strategy.html` / `account-operations.html` / `account-planning.html` (deleted)
- `annual-sessions.html` / `quarterly-sessions.html` / `team-checkins.html` (dead lines removed)
- `account-setup.html` (data export card + JS)
- `account-plans.html` (group financials rollup)
- `goals.html` / `scorecard.html` / `meeting.html` (empty-state copy)
- `js/swipe-delete.js` (new)
- `todos.html` (script tag + `.swipeable` class)

### No SQL.

---

## v0.5.221
- **Bugfix: "Meeting in progress" pill kept reappearing after the user marked the meeting completed.** User: "Meeting in progress pill is still appearing even though I have completed it. Fix bug."

### Repro
1. Open `run-meeting.html?id=X`. Pill is in localStorage.
2. Flip status dropdown to **Completed**. Pill disappears (we're on the matching meeting page; the guard at `js/active-meeting.js:139` hides it).
3. Tap a bottom-nav tab to navigate away.
4. Pill is back on the next page. ❌

### Root cause
`js/active-meeting.js` called `autoSetFromMeetingPage()` from inside `render()`. The status-dropdown handler in `run-meeting.html:314-317` calls `window.activeMeeting.clear()` when status flips to completed. `clear()` runs `clearKey()` (removes the localStorage entry) **then `render()`**. But `render()` immediately re-seeded the pill via `autoSetFromMeetingPage()` because we were still on `run-meeting.html?id=X`:

```js
function autoSetFromMeetingPage() {
  // ...
  if (existing && existing.id === id) return;  // already set — skip
  // ...
  write({ id, label: '', org_id: orgId || null, started_at: new Date().toISOString() });
}
```

Right after `clear()`, `existing === null` — so the guard at the top passed, and the write reseeded localStorage with the same meeting id. The on-matching-meeting guard at line 139 prevents the pill from rendering on `run-meeting.html` itself, so the bug was silent until the user navigated to another page.

### Fix
Moved `autoSetFromMeetingPage()` out of `render()` and into `init()`. It now fires exactly once per page load (preserving v0.5.213's deep-link defence: if you open `run-meeting.html?id=X` cold, the pill still gets seeded). It does **not** fire on subsequent `render()` calls (storage events, programmatic clear, etc.), so `clear()` is now final on this page.

### Why not other fixes
- **Don't call `render()` from `clear()`** — would break cross-tab updates (storage event listener needs render to fire).
- **Have `autoSet` query the DB for status before seeding** — adds an async round-trip on every page load. Heavy, and we already have run-meeting.html's own loadDetail handling that case correctly.
- **Move the auto-set call into `init()`** — minimal, preserves existing behaviour, no async needed. ✓

### Files
- `js/active-meeting.js` (only)

### No SQL.

---

## v0.5.220
- **Audit cleanup pass: schema sync, Learn vault reorder, floating-pill coverage, .claude/ scaffolding.**

### (1) Schema source-of-truth sync
`supabase/schema.sql` was anchored at ~v0.5.132 and missed every schema change since:
- `business_cadence` table + RLS (v0.5.192/193/197/211)
- `issues.category` column + CHECK + index (v0.5.183)
- `organisations.parent_organisation_id` + self-parent CHECK + index (v0.5.145)
- `organisations.org_chart_url` (v0.5.187)
- `targets.five_year` (v0.5.181)
- `quarterly_sessions.notes/external_links/commitments` (v0.5.211)
- `children read parent` SELECT policies on `core_values`, `core_focus`, `targets`, `business_cadence` (v0.5.145/197)
- `"members add issues"` INSERT policy (v0.5.216)

Added a new **§14 POST-v0.5.132 ADDITIONS** block at the bottom of `schema.sql` that catches everything up. All `ALTER` / `CREATE TABLE` / `CREATE POLICY` use `IF NOT EXISTS` + `DROP POLICY IF EXISTS` + `DO $$ ... pg_constraint` guards so it's idempotent on a populated DB.

### (2) Learn vault audit
**Strategy section reordered** to match the Strategy hub (Financials → Core Values → Core Focus → Marketing Strategy → Organisational Chart → Targets → 12 Month Goal). Renamed the "Leadership Team" card to **Organisational Chart** to match the hub copy. Targets card description simplified ("10-year, 5-year and 3-year goals — the longer horizons that anchor the year") since the 12-month is now its own card.

**Operations section added a 5th card — ✅ To-Do List** linking to `todos.html`. Section count bumped 4 → 5 activities. (v0.5.204 added the standalone todos page but never surfaced in Learn.)

### (3) Guide content sync
- `learn/weekly-team-meeting.html` Common Pitfalls bullet 3 still said "the rating is how you find out the meeting is broken" — but the rating was removed in v0.5.207. Rewrote to "the quick what-worked / what-to-change round is how you find out the meeting is broken".
- Three guides still used the pre-v0.5.184 term **"1-Year Plan"** instead of **"12-Month Goal"**: `learn/targets.html`, `learn/quarterly-goals.html`, `learn/annual-planning-session.html`. `replace_all` brought them in line.

### (4) Floating-pill script coverage
Added `<script src="js/active-session.js">` + `<script src="js/active-meeting.js">` defers to the 4 account-* carousel pages that were missing them:
- `account-annual.html`
- `account-quarterly.html`
- `account-checkins.html`
- `account-meetings.html`

So the floating green meeting-in-progress pill + Resume planning session pill now follow the user across every business-level **and** account-level page (was 30 pages → now 34).

### (5) CLAUDE.md file structure
The File Structure section now lists:
- `cadence.html` (added in v0.5.192)
- `twelve-month-goal.html` (added in v0.5.184)
- `todos.html` (added in v0.5.204)
- `js/active-meeting.js` (added in v0.5.207)
- `js/mobile-keyboard.js` (added in v0.5.130)

Also flagged the `?category=current|future|yearly` query-string on `issues.html`.

### (6) .claude/ scaffolding
Two additions so Claude doesn't re-derive procedure every session:

- **`.claude/skills/version-bump/SKILL.md`** — codifies the 7-file dance (VERSION → sw.js → 4 footers → CLAUDE.md → CHANGELOG.md). Pulls all the "where does the version number live" knowledge into one invokable skill. The two version-drift bugs (v0.5.143 + v0.5.158) happened because the checklist was prose in CLAUDE.md and got missed; a skill turns it into a callable procedure.
- **`.claude/hooks/session-start.sh`** (executable) — prints the current version + last 2 CHANGELOG entries when a new Claude session starts. Wired via `.claude/settings.local.json`'s `hooks.SessionStart` config. Means a session that comes back after compaction has immediate "where is production?" context.

### SQL
If your DB pre-dates v0.5.197, run `schema.sql` (the additions are idempotent). If you've been applying delta files in order, no change needed — production matches.


---

## v0.5.219
- **Meeting timer button is now Pause/Resume only — status changes via the dropdown.** User: "Can there be a pause meeting rather than end meeting. As there is a completed option" → "Yes put in the simpler version."

### Before
Timer button toggled between "▶ Start Meeting" and "⏹ End Meeting" — both writes changed `meetings.status` in the DB (start → in_progress, end → completed). The status dropdown right above the button did the same thing, so the two affordances were redundant + confusing.

### After
Timer button is now purely a visible-ticker control. **Tap = freeze the ticker. Tap again = resume.** No DB writes. Status is changed only through the dropdown:

- **Load with status = `in_progress`**: button shows **⏸ Pause** with the ticker running. Elapsed time anchored on `m.created_at` (so returning via the pill / refreshing / direct URL shows real elapsed since the meeting was created — not zero).
- **Tap Pause**: ticker stops via `clearInterval`. Button becomes **▶ Resume**.
- **Tap Resume**: `tick()` snaps to real elapsed (recomputed from `created_at`), interval restarts. Button becomes **⏸ Pause**.
- **Load with status = `completed`**: entire timer bar is hidden via `display:none` — the meeting is done, no ticker needed.
- **Dropdown flips to Completed**: timer bar hides + interval clears (in addition to clearing the floating pill, which was already wired in v0.5.207).
- **Dropdown flips back from Completed → In Progress**: timer bar re-shows; full re-render to restore the running state cleanly.

### Pause state — kept simple
The paused flag is in-memory only. If the user reloads mid-pause, the displayed time snaps back to "real elapsed since created_at" — not "elapsed when you paused". This is the **simpler version** the user picked (the user accepted this tradeoff in chat). A future version could persist a `paused_at` column on `meetings` to subtract break time from the displayed elapsed if desired.

### Cleanup
- Removed all `_timerStart` tracking from the click handler (replaced with the `_paused` flag).
- Removed all `supabase.from('meetings').update({status:...})` writes from the timer button.
- Default HTML button text changed from "▶ Start Meeting" to "⏸ Pause" — JS overwrites this on load regardless, but it reads better if JS is slow.
- Added `id="timer-bar"` to the timer container so it can be hidden/shown when status flips.

### No SQL.

---

## v0.5.218
- **Three asks bundled.** User: "Annual sessions still have the option for scheduled. Remove this. Just want in progress or completed. (Check quarterly). Also I notice that when I go back to the meeting with the pill does this then stop the active meeting. I have to start the meeting again." + "Heading doesn't look great on phone" (Role Permissions matrix on iPhone showing the header row as "ADMINCOACHMEMBE" — labels colliding).

### (1) Annual + quarterly sessions: drop the "Scheduled" status
Same change v0.5.209 made for meetings, now applied to sessions:
- `run-annual-session.html` + `run-quarterly-session.html` — status dropdown now renders only **In Progress** + **Completed**.
- Selected logic: `status !== 'completed'` shows as In Progress (any historical 'scheduled' row also displays as In Progress).
- `annual-sessions.html` + `quarterly-sessions.html` — new session inserts default to `status: 'in_progress'` (was 'scheduled').
- DB CHECK constraint on `*_sessions.status` untouched — 'scheduled' is still a valid stored value for historical data.

### (2) Meeting timer syncs on return via the pill
**Bug**: tap the floating green pill → land on `run-meeting.html` → timer button shows "▶ Start Meeting" → user thinks they have to begin over.

**Root cause**: the timer state (`_timerStart`, `_timerInterval`) is in module-level JS that resets on every page load. The DB knew the meeting was `in_progress` but the UI showed the initial-state button.

**Fix** in `renderDetail`, before the timer button click handler is wired:
```js
if (m.status === 'in_progress' && m.created_at) {
  _timerStart = new Date(m.created_at).getTime();
  timerEl.classList.remove('hidden');
  timerBtn.textContent = '⏹ End Meeting';
  timerBtn.classList.add('running');
  const tick = () => { /* compute mm:ss from created_at */ };
  tick();
  _timerInterval = setInterval(tick, 1000);
}
```

So returning to an in-progress meeting via pill / refresh / direct URL now shows the elapsed time (anchored on `created_at`) + the End button immediately. No fake "Start" prompt.

### (3) Role Permissions matrix — mobile heading fix
The screenshot showed the header row crammed as "ADMINCOACHMEMBE" because role columns were 46px wide and labels at 0.62rem letter-spacing 0.5px don't fit.

- Role columns bumped 46 → **58px**, gap 4 → 2px (more room for labels).
- Header font 0.62 → **0.6rem**, letter-spacing 0.5 → **0.2px** (tighter fit).
- New `@media (max-width: 380px)` breakpoint for ultra-narrow phones: 52px columns, 0.55rem header, 0.1px spacing.

### No SQL.

---

## v0.5.217
- **Role Permissions reference table + members can't edit issues.** User: "Add a and b" (a = role permissions in admin area; b = hide edit option for members) + "Remove option for edit."

### (a) Role Permissions table — `account-users.html`
New **🔐 Role Permissions** section appended below the Members list. 4-column grid (Permission / Admin / Coach / Member) with ✓ / — marks per cell, grouped into 5 categories:

| Category | Rows |
|---|---|
| Read | See all data; See team check-in results |
| Edit data | Add issues (current/future); Edit/delete any issue; Add 12 Month Issues; Edit strategy worksheets; Edit operations; Run planning sessions; Submit own check-in |
| Team management | Invite / Remove members; Change another member's role |
| Business | Rename business; Delete business |
| Billing | Edit account name/billing (owner only); Counts against 3 included seats |

Footer note: "Security is enforced at the database layer (Supabase Row Level Security), not just in the UI." So a Member can't bypass restrictions even with raw API access.

Responsive — narrower columns at ≤ 480px so the matrix fits on iPhone.

### (b) Members can no longer Edit issues — `issues.html`
- New `loadUserRole(userId)` queries `team_members.role` for the active org during init. Sets module-level `_canEdit = (role === 'admin' || role === 'coach')`.
- `renderCards` checks `_canEdit` before attaching the click-to-edit handler. Member sees the card list with default cursor; tapping does nothing.
- The category dropdown in the Add modal hides the **12 Month Issues — long-horizon** option for non-editors (Members can only INSERT current/future per v0.5.216 RLS — hiding the option in the UI prevents confusion).
- Add Issue button + new-issue modal still work for Members on current/future categories. Admins/coaches see no change.

### No SQL.
v0.5.216 already added the INSERT policy on `issues`. v0.5.217 is purely UI: the reference table + role-gating on the Edit affordance.

---

## v0.5.216
- **Members can add to Issues List + Future Issues List.** User: "I would want team members to be able to add to an area in future issues list. But not delete. And also keep adding to the issues list but not delete."

### Before
Only admins + coaches could write to `issues` (the `"admins write issues"` FOR ALL policy). Members were read-only — they couldn't surface a new issue without asking an admin to type it in.

### After
New additive INSERT-only policy on `public.issues`:
```sql
CREATE POLICY "members add issues" ON public.issues
  FOR INSERT
  WITH CHECK (
    organisation_id IN (SELECT public.user_org_ids(auth.uid()))
    AND category IN ('current', 'future')
  );
```

Postgres combines policies with OR for the same operation, giving us this matrix:

| Role | Action | Result |
|---|---|---|
| Admin / Coach | INSERT any category | ✅ via `"admins write issues"` |
| Admin / Coach | UPDATE / DELETE any | ✅ via `"admins write issues"` |
| Member | INSERT category=current | ✅ via `"members add issues"` |
| Member | INSERT category=future | ✅ via `"members add issues"` |
| Member | INSERT category=yearly | ❌ both policies fail → 403 |
| Member | UPDATE existing issue | ❌ only FOR ALL applies → 403 |
| Member | DELETE existing issue | ❌ only FOR ALL applies → 403 |

### Why `yearly` stays admin/coach-only
12 Month Issues are long-horizon items surfaced at the annual planning session — not day-to-day adds that anyone should drop in. Admins/coaches add them deliberately during planning.

### UI behaviour
`issues.html` still renders the **Add Issue** button + edit modal to everyone. Members can hit Add freely (works). If a member taps an existing issue and tries to Save edits, they'll see an RLS-denied error toast — clear feedback rather than silently hiding the affordance (which would require role-querying every row render). A future refinement could hide the edit modal for non-admins; left as-is for now.

### Requires SQL
`supabase/v0.5.216-delta.sql`

---

## v0.5.215
- **Auto-complete meetings left in_progress past their meeting day.** User: "What happens if they just leave the meeting open? Does it automatically close?" → "Yes" (to option 2 of the two I offered: auto-complete by date).

### Diagnosis
A meeting opened (or created via Run Weekly Meeting) defaults to `status: 'in_progress'`. If the user never taps End / Completed, the row stays `in_progress` forever:
- Floating green pill keeps showing across every business-level page indefinitely
- Home button stays as "Resume This Week's Meeting"
- Quarter rollups don't reflect meetings being closed
- Next Monday's tap on Run creates a new meeting alongside the still-open old one

### Fix — `business.html` `renderDashboard`
Right after `meetings = meetingsRes.data`, scan for stale rows:
```js
const stale = meetings.filter(m => m.status === 'in_progress' && m.meeting_date < todayIso);
if (stale.length) {
  const ids = stale.map(m => m.id);
  stale.forEach(m => { m.status = 'completed'; });          // patch local
  supabase.from('meetings').update({ status: 'completed' })  // write DB (fire-and-forget)
    .in('id', ids)
    .then(({ error }) => { if (error) console.warn('…'); });
  // Clear pill if it was pointing at a stale meeting
  …
}
```

### Behaviour
- **Today's meeting**: untouched (`meeting_date >= today` excluded).
- **Future meetings**: untouched (rare — but scheduled-ahead meetings stay scheduled until their day).
- **Yesterday's `in_progress`**: flipped to `completed` next time the user lands on the home dashboard.
- **Floating pill cleanup**: if the localStorage pill was pointing at a stale meeting, `window.activeMeeting.clear()` is called so the pill disappears.
- **Idempotent**: once flipped, the row is `completed` so subsequent dashboard loads skip it.

### Tradeoff
If someone runs a meeting past midnight (rare for weekly), the next dashboard load after midnight will mark it completed. They can still see the meeting via Operations → Weekly Meetings and even reopen the workspace — the data isn't lost, just the status reflects it's no longer the "active" meeting of the day.

### No SQL.

---

## v0.5.214
- **Removed the Child Businesses panel from the parent dashboard.** User: "Child business on dashboard just taking up real estate. Remove."

### Change — `business.html`
- The `<div class="dash-panel">` inside `parentMode` containing **🏢 Child Businesses** + `#childCards` is gone.
- The 22 lines of JS in `renderParentMode` that built the child cards (`children.map(...) → cardsEl.innerHTML` + the click handlers calling `window.activeOrg.set` + reload) are also gone.

### Net effect
For parent businesses (e.g. IASHQ), the dashboard now appends only **💰 Group Financials** below the standard layout. Standard layout above is unchanged: Quick Actions → Year Flow → 1-Year Goal → Core Values → Quarterly Goals → Open Issues → Open To-Dos.

### Children are still reachable
- **Biz switcher dropdown** in the navy header (the green pill, populated by `active-org.js`) — every business in the active subscription is listed.
- **Account tab** in the bottom-nav → `index.html` — full list of businesses with Open buttons + management actions.

### Cleanup deferred
The `.child-card`, `.child-card-head`, `.child-card-arrow`, `.child-card-name`, `.child-card-open`, `.child-card-mini` CSS rules are left in place — small, harmless, and would only need to come back if the panel is restored.

### No SQL.

---

## v0.5.213
- **Two scorecard.html bugs reported from the meeting → figures flow.** User: "I click on the weekly meeting and then click on numbers. It doesn't show the persistent green button still. And also when I'm in this page from meeting and I click on home it doesn't work."

### (1) Floating pill still missing on scorecard.html
The v0.5.211 z-index bump to 2100 didn't fix the user's report, which means the pill wasn't being hidden — it was never being rendered. Root cause: the pill is set in `run-meeting.html`'s `loadDetail()` async flow, which depends on:
1. The page's main module script firing
2. The async session fetch completing
3. localStorage write completing

If any of those is delayed (slow network, async timing, sticky service-worker cache), localStorage won't have the meeting data yet when scorecard.html's `active-meeting.js` reads it.

Two layers of defence:
- **`business.html` `openOrCreateWeeklyMeeting`** — pre-sets the pill via `window.activeMeeting.set(meetingId, '', activeId)` BEFORE navigating to `run-meeting.html?id=…`. So the pill is in localStorage the moment the user taps Run Weekly Meeting; subsequent navigation to any Edit destination (scorecard, goals, issues, todos) sees the pill data ready.
- **`js/active-meeting.js` `autoSetFromMeetingPage()`** — when active-meeting.js runs and detects we're on `run-meeting.html?id=…` with no matching localStorage entry, it seeds one from URL params + `coach4u_active_org_id`. So any path into the meeting workspace (link from meeting.html list, deep link, refresh) sets the pill automatically.

### (2) Home button doesn't work on scorecard.html
Root cause: `.cell-popover` was at z-index **500**, the bottom-nav at z-index **100**. When a popover was open or just rendered, taps on the bottom-nav hit the popover overlay first — the document click handler closes the popover but the tap is consumed, so navigation doesn't happen. The user has to tap again.

**Fix**: dropped `.cell-popover` z-index from `500` → `90` (below the bottom-nav's `100`). Bottom-nav taps now always reach the anchor first.

### No SQL.

---

## v0.5.212
- **Annual session AREAS — fixed stale links + labels for current schema.** User: "Have you looked at the annual and quarterly areas for double dates and all areas are linked."

### Double-dates audit ✓ no change needed
- Workspace duplicate dates were dropped in v0.5.210 (`session-detail-title` removed from both annual + quarterly; `ws-title` page header is the single source of truth).
- List pages (`annual-sessions.html`, `quarterly-sessions.html`) render `session-item-date` once per row — already fine.

### Area-links audit — `run-annual-session.html`
Found 3 issues in the `AREAS` array, all from accumulated schema drift:
| Area | Before | After |
|---|---|---|
| 1 | "Review Last Year" — no link | Link → `one-page-plan.html` (the doc you actually review) |
| 3 | "Update 10-Year + 3-Year Outlook" | "Update 10-Year, 5-Year + 3-Year Targets" (5-Year added to Targets in v0.5.181) |
| 4 | "Set 1-Year Plan + Q1 Goals" → links: `targets.html` + `goals.html` | "Set 12-Month Goal + Q1 Goals" → links: `twelve-month-goal.html` + `goals.html` (12-Month moved off Targets in v0.5.184) |

### Account-link map
`ACCOUNT_LINK_MAP` extended with the two new biz-scoped paths so account-scoped sessions resolve correctly:
```js
'twelve-month-goal.html': 'account-targets.html',
'one-page-plan.html':     'account-plans.html',
```

### Quarterly session AREAS ✓ no change needed
"Review Last Quarter / Lessons + Adjustments / Set Next Quarter's Goals" — only references `goals.html` which is correct.

### No SQL.

---

## v0.5.211
- **Quarterly session parity with annual + floating meeting pill z-index bump.** User: "Yes" — addressing both items queued in v0.5.210.

### (1) Quarterly session workspace — feature parity with annual

#### Schema — `supabase/v0.5.211-delta.sql`
3 nullable columns added to `quarterly_sessions`:
```sql
ALTER TABLE public.quarterly_sessions
  ADD COLUMN IF NOT EXISTS notes          text,
  ADD COLUMN IF NOT EXISTS external_links jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS commitments    jsonb NOT NULL DEFAULT '[]'::jsonb;
```
Same shape as the columns on `annual_sessions` (added v0.5.131). Existing rows keep working — nullable + default fallbacks. No RLS change — existing `quarterly_sessions` policies cover the new columns.

#### UI — `run-quarterly-session.html`
3 new blocks added between Areas to Cover and Team Check-in:
- **🔗 Session Resources** — list of `{label, url}` rows; "Add link" button at the bottom; auto-saves to `external_links`.
- **📝 Session Notes** — free-form textarea writing to `notes`, 500ms debounce autosave.
- **🎯 Personal Commitments** — list of `{name, commitment}` rows; one-thing-each-leader-is-taking-on for the quarter; auto-saves to `commitments`.

All borrow the same CSS classes (`.row-list`, `.row-input`, `.row-add`, `.link-row`, `.commit-row`, `.notes-input`) and JS pattern (renderLinks / persistLinks / scheduleLinksSave + same for commits) from the annual session — just copy-pasted with the empty-state copy tweaked for quarterly cadence ("one thing each leader is taking on for the *quarter*" instead of "year").

### (2) Floating meeting pill z-index bump

`js/active-meeting.js`:
- `.active-meeting-pill { z-index: 210 }` → `z-index: 2100`

The pill was being rendered correctly on every edit destination page (scorecard, goals, issues, todos) but on pages that open a modal — issues add/edit (`.modal-overlay { z-index: 1000 }`), goals edit modal, scorecard cell-popover, toast notifications (`z-index: 2000`) — the pill (z-index 210) was sitting below the overlay and looked "missing".

Bumping to 2100 keeps the pill above all of those. Likely fix for the user's "pill doesn't come up when I click figures" report.

### Run SQL
- `supabase/v0.5.211-delta.sql`

---

## v0.5.210
- **Session workspace cleanups + Learn vault audit pass.** User: "Annual sessions has backlinks. I'm assuming quarterly does as well. It's showing 2 dates. Check quarterly. And also it's not showing the headings and work under each section." Plus a small audit sweep on the Learn vault and Operations hub for terminology drift.

### Annual + quarterly session workspaces
Same fixes I applied to `run-meeting.html` in v0.5.207 / v0.5.209:
- **Back link removed** from both `run-annual-session.html` (`← Annual Sessions`) and `run-quarterly-session.html` (`← Quarterly Sessions`). Planning tab in the bottom-nav covers the destination.
- **Duplicate date dropped** from both — the inner `session-detail-title` next to the status dropdown is gone; the page header `ws-title` is now the single source of truth, and the status dropdown sits alone right-aligned above the timer bar.

Net effect: more sections fit above the fold on iPhone. Attendance + Areas to Cover are visible without scrolling; (annual) Resources / Notes / Commitments / Team Check-in follow below.

### Operations hub — terminology consistency
- "Quarter Goals" card renamed to **"Quarterly Goals"** to match the home dashboard panel, the one-page-operations column heading, and the Learn vault card. Continues the v0.5.184 standardisation pattern (used "12 Month" everywhere, now using "Quarterly" everywhere).

### Learn vault
- Strategy section count: `"6 activities"` → `"7 activities"`.
- New **🎯 12 Month Goal** card added to the Strategy section after Leadership Team. Reuses the Targets guide; "Open worksheet" goes to `twelve-month-goal.html` (the dedicated editor). Closes the gap from v0.5.204 when 12 Month Goal moved to Strategy but wasn't surfaced in the vault.
- `learn/weekly-team-meeting.html` — step 7 description: *"Each person rates the meeting 1–10 with one sentence why"* → *"Quick round: what worked today, what should we do differently next week"* (rating input was removed from the app in v0.5.207).
- Coach's tip at the bottom: dropped the "rates below 8" framing; rewrote to refer to running long / no decisions / repeated issues as the leading indicators that the meeting is fraying.

### Out of scope — queued for next version
- **Quarterly session workspace expansion.** `run-quarterly-session.html` only has 3 blocks (Attendance, Areas to Cover, Team Check-in) compared to annual's 6 (+ Resources, Notes, Commitments). Bringing them to parity requires a SQL migration adding `notes text` + `external_links jsonb` + `commitments jsonb` columns to `quarterly_sessions`. Will confirm with user before doing.
- **Floating "Meeting in progress" pill bug.** User reported it doesn't appear when clicking figures from inside a meeting. The Explore audit confirmed `active-meeting.js` loads on scorecard / goals / issues / todos and the z-index/positioning is correct. Most likely cause is a modal overlay on the destination page (z-index 1000+) covering the pill (z-index 210). Not changed pending the user confirming the exact scenario.

### No SQL.

---

## v0.5.209
- **Dropped "Scheduled" status + removed back link from meeting workspace.** Two user asks:
  1. *"I think the meeting should be in progress or completed. No scheduled"*
  2. *"I don't think this back link is needed"* (screenshot of run-meeting.html showing `← Past Meetings` in the navy header, with the title `Your ...` truncated due to cramped header).

### (1) Status — In Progress or Completed only
- `run-meeting.html` — status dropdown now only renders **In Progress** + **Completed** options. The Scheduled option is gone.
- Selected-state logic: `status !== 'completed'` shows as In Progress (any historical `'scheduled'` row also displays as In Progress).
- The DB CHECK constraint on `meetings.status` still allows `scheduled` (historical data preserved); the option just isn't surfaced in the UI.

### (2) New meetings default to in_progress
Four insert sites changed from `status: 'scheduled'` → `status: 'in_progress'`:
- `business.html` — `openOrCreateWeeklyMeeting` (Run Weekly Meeting button on home).
- `todos.html` — `findOrCreateThisWeekMeeting` (when adding a todo creates this week's meeting).
- `meeting.html` — new-meeting modal save handler.

Side effect: the floating green "Meeting in progress" pill (v0.5.207) now appears immediately on Run Weekly Meeting tap, since the meeting is already in_progress. Previously the pill appeared but represented a scheduled meeting which felt mismatched.

### (3) Back link removed from run-meeting.html
- `<a href="meeting.html" class="header-back">← Past Meetings</a>` deleted from the navy header.
- To reach the meetings list now: Operations → Weekly Meetings (one tap via bottom-nav + activity card).
- Matches the v0.5.189 / v0.5.191 audit principle — back link is redundant when bottom-nav covers the destination, and frees header space on iPhone where the page title was being ellipsised.

### No SQL.
- `meetings.status` column + CHECK constraint untouched. `'scheduled'` is still a valid stored value; older rows render correctly.

---

## v0.5.208
- **Annual + quarterly session audit (matches the v0.5.207 weekly-meeting fix).** User: "Now go to annual and quarterly sessions and do the same audit and check if it is structured to see the persistence pill and each section can be seen."

### Persistence pill — auto-sync on session load
Both `run-annual-session.html` and `run-quarterly-session.html` already wire `window.activeSession.set/clear` correctly on the status dropdown change and the timer start/end. But neither was syncing the pill on initial page load — so if the user opened (or refreshed) an in-progress session, the floating pill stayed in its prior localStorage state (could be stale or missing entirely if localStorage was cleared).

**Fix**: in each file's `loadDetail(id)`, right after the page header is set, sync the pill from the session's current status:
- `s.status === 'in_progress'` → `window.activeSession.set('annual'|'quarterly', s.id, label)`
- `s.status === 'completed'`   → `window.activeSession.clear()`
- `s.status === 'scheduled'`   → no-op (session not actively running)

Matches the v0.5.207 pattern used in `run-meeting.html`. The pill now follows the source-of-truth (the row in `annual_sessions` / `quarterly_sessions`) rather than relying on prior writes.

### Section visibility — already fine, no change needed
Both session workspaces are vertical-stacked block layouts, not the accordion the weekly meeting uses. Every block already shows its content inline:
- **Annual**: Attendance · Areas to Cover · Session Resources · Session Notes · Personal Commitments · Team Check-in.
- **Quarterly**: Attendance · Areas to Cover · Session Resources · Personal Commitments · Team Check-in.

No "click to expand → see items" → "click Edit" pattern needed since there's nothing hidden behind a toggle. Sections are visible from the moment the page loads.

### Out of scope
- `run-team-checkin.html` doesn't use the planning-session pill (it's a survey batch run page, not a workshop session) — left alone.
- Delete-clears-pill cleanup (added to `meeting.html` in v0.5.207) wasn't added for sessions because `annual-sessions.html` / `quarterly-sessions.html` don't have delete buttons — the only path that removes a session is the workspace itself, which already clears the pill on `'completed'`.

### No SQL.

---

## v0.5.207
Four user asks bundled (all about the weekly meeting UX):
1. *"Can it be that there is green light flashing that can be click on when a meeting is running."*
2. *"I don't think the Todo list I'm weekly meeting is structured to show the items and then the edit button. Can't see the to do well on phone."*
3. *"When a new meeting has started it is showing 2 dates. Clean this."*
4. *"Remove the rating for meeting and just have the last point conclude."*

### (1) Floating "Meeting in progress" pill — new `js/active-meeting.js`
Companion to the existing `active-session.js` (planning sessions pill). When `run-meeting.html` loads a meeting whose status isn't `'completed'`, it calls `window.activeMeeting.set(id, label, orgId)` → writes to `localStorage.coach4u_active_meeting`.

The script renders a fixed bottom-centre **bright green pill** ("● 🗓️ Meeting in progress — Mon 30 May →") on every business-level page (added via sed to all 30 pages that already load `active-session.js`). Pill animates with a `box-shadow` pulse + inner-dot ripple. Tap → `run-meeting.html?id=…`.

Hide rules:
- Doesn't render on the meeting's own workspace page (you're already there).
- Hides when the active org doesn't match the meeting's org (so switching businesses doesn't show a misleading pill).

Auto-clears when:
- Status dropdown changes to `'completed'`.
- Timer-end button stops the meeting.
- Meeting is deleted from `meeting.html` (the delete handler also clears the pill if it was pointing at that meeting).

### (2) Section 5 (To-Do List) now uses the view + Edit pattern
Matches sections 2/3/6 from v0.5.206. Items shown as a clean checklist (descriptions, owner, checkbox still tap-able to mark done — the key during-meeting action). The **"Edit Full List ›"** link at top-right goes to `todos.html` (the cross-meeting page from v0.5.204) where users add / delete / change due-dates. Inline add row + delete buttons removed from the meeting view — they're now on `todos.html` only. Strike-through on completed todos updates in place (no re-render).

### Mobile add-row fix (Section 4 — Customer & Team Highlights)
The `.item-add-row` flex container now wraps with `flex-wrap: wrap`. On phones (< 520px) the input takes the full row width and the type-select + Add button drop to a second row. Previously the type-select got truncated to "— Ow" on iPhone (visible in the user's screenshot). Above 520px the original single-row layout returns.

### (3) Duplicate date cleaned
`run-meeting.html` was rendering the meeting date twice — once in the `ws-title` page header and again in `meeting-detail-title` at the top of the agenda card. Dropped the inner duplicate; the status dropdown now sits alone (right-aligned) above the timer bar. Page header at the top is now the single source of truth for the meeting date.

### (4) Rating removed from Section 7
- Section title: `"Conclude & Rate"` → `"Conclude"`.
- `renderConclude()` no longer emits the 1–10 rating buttons; only the Notes / Cascading Messages textarea + Save Notes button remain.
- `wireConclude()` no longer wires the rating button handlers (only the notes save).
- The `meetings.rating` column **stays in the schema** — historical ratings preserved; new meetings just leave it null.

### No SQL.

---

## v0.5.206
- **Weekly meeting agenda sections now show the items inline with an Edit ›  link.** User: "Can the weekly meetings be structured so it shows the items and then has an edit button similar to the dashboard. ... if I click on quarterly goal I see the goals and if I need to edit them I click on edit. And this is the same do all of the sections in weekly meeting."

### Before
Sections 2 (Numbers Review), 3 (Priorities Review), and 6 (Issues) showed a one-line paragraph and a link to the dedicated edit page — *"Review quarterly goals. Open Goals →"*. Tap the section → see nothing useful → navigate to a different page → come back. Lots of friction during the meeting.

### After
Each of those three sections now shows the actual operational data inline (read-only), with a small **Edit ›** link in the top-right corner of the content area that navigates to the dedicated edit page when something needs changing.

- **Section 2 — Numbers Review**: compact scorecard table identical to the one-page-operations view. Metric name + owner + goal + last 6 weeks of values with hit/miss colouring. Edit link → `scorecard.html`.
- **Section 3 — Priorities Review**: list of this quarter's rocks with description, owner, and status pill (On Track / At Risk / Off Track / Done / Not Started). Edit link → `goals.html`.
- **Section 6 — Issues — Discuss & Resolve**: numbered list of `category='current'` open issues with description + owner. Edit link → `issues.html?category=current`.

### Sections kept as-is
Sections 4 (Customer & Team Highlights), 5 (To-Do List), and 7 (Conclude & Rate) kept their existing inline-editable UI. Their content lives only inside the meeting (per-meeting headlines + todos in `meeting_headlines` / `meeting_todos`, per-meeting rating + notes on the `meetings` row), so there's no separate edit page to link to. They were already showing the actual items.

### Data
- `loadDetail` Promise.all grows from **3 → 6 queries**: now also fetches `scorecard_metrics`, `rocks` (this quarter), `issues` (current+open). All scoped by `orgId` (set in init from `window.activeOrg.get()`).
- Second round-trip for `scorecard_entries` over the 6-week window — only runs if metrics exist.
- All new state lives on top-level `_scMetrics`, `_scEntries`, `_scWeeks`, `_rocks`, `_issues` arrays.

### CSS
- `.agenda-edit-row` / `.agenda-edit-link` — the small teal "Edit ›" link at the top-right of each section.
- `.agenda-view-list` / `.agenda-view-row` — read-only list of items inside a section.
- `.agenda-pill` + `.pill-green/amber/red/grey` — rock status pills (matches dashboard styling).
- `.agenda-sc-wrap` / `.agenda-sc-table` — scorecard mini-table (horizontally scrollable on phones).

### Helpers added
- `currentQuarter()` — same shape as on the other pages.
- `fmtWeek(iso)` — short "5 Jun" format for column headers.
- `fmtVal(v, type)` — formats currency / percentage / plain numbers.
- `editRow(href, label)` — generates the "Edit X ›" link block.

### No SQL.

---

## v0.5.205
- **Dynamic Run Weekly Meeting button label so the user can see the meeting was persisted.** User: "The weekly meetings I still think it seems to not be working with meetings that when pressing starts it's not persisting and meeting available."

### Diagnosis
Meetings ARE persisting — `wireRunMeetingButton` inserts via the admin+coach write policy on `meetings`, which works for the org owner. But after v0.5.202 dropped the Next Meeting stat tile and v0.5.204 renamed "This Week" → "Open To-Dos", the home dashboard had NO visible signal that a meeting existed for this week. Tapping "Run Weekly Meeting" a second time silently opened the same meeting (the click handler does find-or-create), but the unchanged button label made it feel like nothing was saved.

### Fix
In `renderDashboard`, after computing `thisWeekMeeting`, the `#runWeeklyMeetingBtn` label is now set dynamically:
- **`🗓️ Resume This Week's Meeting`** — a non-completed meeting exists for this Monday (visible feedback the meeting was persisted).
- **`🗓️ Run Weekly Meeting`** — no meeting for this Monday yet, OR this week's meeting was already completed (so the user starts fresh next time).

Same click handler (`openOrCreateWeeklyMeeting`); just clearer labelling.

### Side benefits
- A completed meeting for this week reverts to the "Run" label so the user can start a follow-up if needed.
- Meetings *scheduled for future weeks* don't affect this button (it only checks `thisWeekMeeting` — the row where `meeting_date === thisMonday`).

### No data change
`meetings` table + RLS untouched. Reachability check: from Operations → Weekly Meetings → `meeting.html`, all persisted meetings are still listed normally with delete + open buttons. The fix is purely about visible feedback on the home dashboard.

### No SQL.

---

## v0.5.204
- **Standalone To-Do List + cross-meeting todo aggregation + 12 Month Goal moved to Strategy.** User: "This week's to do isn't showing anywhere. Should this be a box and sql in operations?" → "Yes" + "I think 12 month goal should go from operations to strategic area (at the bottom)."

### Diagnosis
The home "This Week" panel only queried todos from ONE focused meeting (`thisWeekMeeting || upcoming || meetings[0]`). If there was no meeting yet for this week, or the focused meeting had no open todos, the panel showed the empty placeholder — even though open todos from prior meetings still needed action. No SQL change needed — `meeting_todos` already has everything (description, owner, done, due_date, meeting_id). Just needed to surface it differently.

### (1) New page — `todos.html`
- Cross-meeting query: `select(... meetings!inner(meeting_date, organisation_id)).eq('meetings.organisation_id', orgId)` — joins through meetings to filter by org while RLS still enforces membership.
- Each row: 20px round checkbox (toggle done, optimistic update + rollback on error), description, owner, due-date label (`Due today` / `Due tomorrow` / `Due 5 Jun` / red `Due 30 May` if overdue), `From wk of …` tag showing which meeting it came from.
- Inline add row at the top: description input + owner select (populated from `team_members`) + Add button. On submit: finds or creates this week's meeting (same `findOrCreateThisWeekMeeting` pattern as the home Run Weekly Meeting button), then inserts the todo into it.
- Filter toggle "Show completed" reveals done items; default view is open only.
- Delete button per row.
- Standard chrome: site-header, biz-pill, bottom-nav (Operations active).

### (2) Home dashboard — "This Week" → "📋 Open To-Dos"
- JS query swap: `from('meeting_todos').eq('meeting_id', focusMeeting.id)` → `from('meeting_todos').select('..., meetings!inner(organisation_id)').eq('meetings.organisation_id', orgId)`. Limit 5, sorted by `due_date` (nulls last) → `created_at`.
- Panel title renamed `This Week` → `📋 Open To-Dos`.
- Panel link `View Meeting ›` → `View All ›` pointing to `todos.html`.
- Removed the `openOrCreateWeeklyMeeting` click handler from this link — Run Weekly Meeting button at the top owns that flow; having create-or-open on a "View To-Dos" link was confusing.
- Empty state: "No open to-dos." (was "No todos for this week yet.")

### (3) Operations hub — added To-Do List, removed 12 Month Goal
- New **✅ To-Do List** card → `todos.html`.
- **🎯 12 Month Goal** card removed (moved to Strategy per the user's note).
- New order: Quarter Goals → 90 Day Numbers → Issues List → Future Issues List → Weekly Meetings → To-Do List.

### (4) Strategy hub — added 12 Month Goal at the bottom
- New **🎯 12 Month Goal** card after Targets → links to the existing `twelve-month-goal.html` (no UI change to the editor itself).
- New order: Financials → Core Values → Marketing Strategy → Organisational Chart → Targets → 12 Month Goal.

### No SQL.
`meeting_todos` was already the right shape. Only the UI changed.

---

## v0.5.203
- **Renamed weekly-meeting section 1: "Segue — Good News" → "Good News".** User: "Change 'Segue — Good News'. To just share a good news item."

### Change
- `run-meeting.html` — agenda section 1 title:
  ```js
  agendaSection(1, 'Segue — Good News', '5 min', renderSegue())
  → agendaSection(1, 'Good News', '5 min', renderSegue())
  ```
- `run-meeting.html` — renderSegue() description simplified:
  - Before: *"Start with 1 minute each: share a piece of good news — personal or professional."*
  - After: *"Share a good news item to start the meeting — personal or professional."*
- `learn/weekly-team-meeting.html` — the guide's section 1 entry updated to match:
  - Before: *"Segue — 5 min. Each person: one personal good news, one business good news. Sets the tone…"*
  - After: *"Good News — 5 min. Each person shares one piece of good news — personal or professional. Sets the tone…"*

### Why
"Segue" is EOS-specific jargon; the user wanted simpler framing. Continues the v0.5.116 de-jargoning work that removed other EOS terms ("Level 10", "Headlines" as a section name, "IDS", etc.).

### No data changes
Section 1 has no stored state — it's purely an instructional paragraph at the top of each meeting. The headlines list (which DOES persist) lives in agenda section 4 "Customer & Team Highlights" via the `meeting_headlines` table; that section is unchanged.

### No SQL.

---

## v0.5.202
- **Dropped stat tiles + added Open Issues panel + renamed This Quarter → Quarterly Goals.** User: "Open issues, goals on track, none next meeting not needed on the dashboards home pages. ... wouldn't it just be easier to have the areas visible ie where is says open issues. Can't we just list the issues list. And review quarterly goals. Can it just show the goals."

### Removed
- The entire `<div class="stat-row">` block (3 stat tiles: Open Issues count, Goals On Track count, Next Meeting date).
- CSS rules: `.stat-row`, `.stat-tile`, `.stat-num`, `.stat-num.accent/amber/red`, `.stat-label`.
- JS: `statOpenIssues`, `statGoalsOnTrack`, `statNextMeeting`, `statNextMeetingTile` setters + the `wireMeetingLink(sn)` call.
- The count-only `issuesCountRes` query is replaced by a full-row `issuesRes` query (same fields issues.html fetches).

### Added — Open Issues panel
Sits between Quarterly Goals and This Week. Lists the actual `category='current'` open issues for the active org with description + owner.
- Empty state: *"No open issues. Nice work."*
- Edit link → `issues.html?category=current` for full management.
- New `.issue-row` CSS borrows the `.rock-row` look so the panel feels consistent with the Quarterly Goals panel right above it.

### Renamed
- **This Quarter** → **🏆 Quarterly Goals**. The panel already showed the rock list + progress bar — only the heading changed (and the link copy: "View Goals ›" → "Edit ›" to match the other Edit links).

### Net effect
The home dashboard reads as a flow with no clicks needed to see open work:
1. Quick Actions (Run Weekly Meeting + 2 View buttons)
2. Year Flow
3. 1-Year Goal
4. Core Values
5. **Quarterly Goals** (renamed — progress bar + goals list with status pills)
6. **Open Issues** (new — actual issues with owner)
7. This Week (todos)

For parent businesses, **Group Financials** + **Child Businesses** still append below (v0.5.200).

### Meeting links still work
The Run Weekly Meeting button (top) + View Meeting link in This Week both still wire through `openOrCreateWeeklyMeeting` from v0.5.201 — tap → find this week's meeting if it exists, else create one, then navigate. The Next Meeting stat tile is gone, but the View Meeting link covers the same use case.

### No SQL.

---

## v0.5.201
- **Fixed the "View Meeting" link in This Week + Next Meeting stat tile.** User: "The weekly meeting start button and link to go back to meeting isn't working" → clarified that the Run Weekly Meeting button works, but the View Meeting link doesn't (on both parent + child dashboards).

### Root cause
The `View Meeting ›` link in the This Week panel and the Next Meeting stat tile in the stat row only navigated to a specific meeting (`run-meeting.html?id=…`) WHEN a meeting already existed for the current week. With no meeting yet, both fell back to their default `href="meeting.html"` (the past-meetings list page) — which felt like "broken" because the user expected to land in *this week's* meeting workspace, not a list of past ones.

The Run Weekly Meeting button worked correctly because `wireRunMeetingButton` always created-or-opened the meeting via a click handler.

### Fix
- Extracted the create-or-open logic into a shared `openOrCreateWeeklyMeeting(activeId)` helper.
- `wireRunMeetingButton(btnId, activeId)` now wraps it (no behaviour change).
- New `wireMeetingLink(el)` helper inside `renderDashboard` attaches the same click handler to:
  - `#thisWeekViewLink` (the View Meeting › link in the This Week panel head)
  - `#statNextMeetingTile` (the Next Meeting stat tile)
- Default `href` on both elements stays as `meeting.html` so middle-click / right-click → "Open in new tab" still navigates to a sensible fallback; normal taps run `e.preventDefault()` + `openOrCreateWeeklyMeeting`.

### Net effect
All three home-dashboard meeting entry points now behave identically:
- **Run Weekly Meeting button** (top of dashboard)
- **View Meeting › link** (This Week panel head)
- **Next Meeting stat tile** (stat row)

Tap any of the three → find this week's meeting if it exists, else create one, then navigate to `run-meeting.html?id=…`. Same code path, same result.

### No SQL.

---

## v0.5.200
- **Unified home dashboard for parent + child businesses.** User: "The home pages should be the same for parent and child. ... Right now the child ones are different" → "Yes do that".

### Before
A business with children rendered an entirely separate `parentMode` div (Quick Actions, Year Flow, Group Strategy, Group Financials, This Quarter's Priorities, Child Businesses) and `standardMode` was hidden with `display: none`. Net effect: the parent biz's own operational panels (1-Year Goal, This Week, This Quarter, Core Values) were invisible on its own dashboard — even though the parent biz does have weekly meetings, quarterly goals, etc.

### After
- `standardMode` **always renders** for every business — same Stat tiles, Year Flow, 1-Year Goal, Core Values, This Week, This Quarter panels regardless of whether the biz has children.
- If the active biz has children, `parentMode` is **appended below** standardMode with only the rollup-only sections.

### `parentMode` — what stayed, what went
- **Kept (only because they're rollup across parent + children, no equivalent in standardMode):**
  - Group Financials (1-Year Revenue Target summed + Last 12mo Profit across parent + children)
  - Child Businesses (tappable cards to switch active biz)
- **Removed (because standardMode already shows the same data for the active biz):**
  - Quick Actions row (Run Weekly Meeting + View One-Page Plan + View One-Page Operations) — already in standardMode at the top.
  - Year Flow panel — already in standardMode.
  - Group Strategy panel — redundant with 1-Year Goal panel.
  - This Quarter's Priorities panel — redundant with This Quarter panel.

### JS
- `init()` — always calls `renderDashboard(activeId)`. Conditionally calls `renderParentMode(activeId, children)` *afterward* when children exist (no longer in an else branch).
- `renderParentMode` — shrunk from **7 parallel queries to 2** (`financial_periods` + `targets` for rollup totals). The strategy/quarter/cadence/issues/meetings queries are gone because those panels are gone.
- `wireRunMeetingButton('runWeeklyMeetingBtnParent', ...)` call removed (the button it wired is gone).
- The `renderYearFlow` call inside `renderParentMode` is also gone — standardMode's `renderDashboard` already renders Year Flow for the active org (with parent-cadence inheritance from v0.5.197 if the child has no own row).

### Net effect on IASHQ
Same operational dashboard you'd see on IAS General / IAS Life / IAS Outsourcing — Stat tiles → Year Flow → 1-Year Goal → Core Values → This Week → This Quarter — plus two extra panels appended at the bottom: **Group Financials** and **Child Businesses**.

### No data loss
Every removed panel's underlying data is untouched in the DB:
- Group Strategy was reading `targets` — still queried by `standardMode`'s 1-Year Goal panel.
- This Quarter's Priorities was reading `rocks` — still queried by `standardMode`'s This Quarter panel.
- Year Flow was reading `business_cadence` — still queried (and still in the standardMode Year Flow panel).
- No DOM ids referenced by removed JS are accessed elsewhere; the `if (!el) return` guards in the few remaining helpers protect against stale lookups.

### No SQL.

---

## v0.5.199
- **Dropped the 12 Month Issues card from the Operations hub.** User: "I noticed there is a 12 month issues and an issues list. This doesn't look right." Picked the "Drop 12 Month Issues" option — long-horizon items belong in the annual planning session, not on the day-to-day Operations hub.

### Change — `operations.html`
- Removed the activity-card pointing at `issues.html?category=yearly`.
- New card order: 12 Month Goal → Quarter Goals → 90 Day Numbers → Issues List → Future Issues List → Weekly Meetings (6 cards, was 7).
- Updated the comment block at the top of the activity grid.

### No SQL, no data loss
- The `issues.category` column still accepts `'yearly'`, `'current'`, `'future'`.
- Existing issues tagged `yearly` are still in the database.
- The Category dropdown inside the issues add/edit modal still has the "12 Month Issues — long-horizon" option, so anyone can still classify a new issue as yearly or re-classify an existing one.
- Direct URL `issues.html?category=yearly` still works — page header + filter logic still render correctly. Annual planning sessions can surface yearly issues; they just don't have a top-level hub shortcut.

---

## v0.5.198
- **Operations one-pager: 4-column flow + new 12 Month Goals column.** User: "Operations one page — Start with 12 month goals, Then issues, Then quarterly goals, Then weekly numbers."

### `one-page-operations.html`
- Rebuilt to 4 columns in the requested order:
  1. **12 Month Goals** — reads `targets.one_year_goals`, renders as a teal-numbered bullet list (matches the strategy one-pager).
  2. **Open Issues** — `category='current'` issues (existing logic).
  3. **Quarterly Goals** — `rocks` for the current quarter (existing logic).
  4. **Weekly Numbers** — scorecard table over the last 6 weeks (existing logic).
- Grid: `1fr 1.55fr 1fr` (3 columns) → `1fr 1fr 1fr 1.4fr` (4 columns). Weekly Numbers gets the wider track because the table is multi-column.
- Column heading meta for **12 Month Goals** shows the plan year computed from `business_cadence` (`Apr 2026 – Mar 2027`), with the same parent-cadence fallback chain used elsewhere.
- Inheritance: if this business has no `targets.one_year_goals` row of its own, the 12 Month Goals column falls back to the parent business's row (mirrors the v0.5.197 cadence inheritance pattern). Renders empty placeholder if neither exists.
- `Promise.all` grows from 4 → 5 queries (`targets` added).
- New `.num-list` CSS rules copied from the strategy one-pager; mobile `@media` block bumps the font-size for thumb reading.

### `account-ops-plans.html` (cross-business ops carousel)
- Same 4-column reorder + new 12 Month Goals column.
- `Promise.all` grows from 3 → 5 queries (`targets` + `business_cadence` added).
- Per-org targets + cadence stored on the `byOrg` Map.
- Inheritance loop after data assembly: children without their own `targets` row pick up the parent's (parent is typically in the same `orgIds` batch since the user is usually a member of both). Same for the plan-year anchor.
- New `renderTwelveMonthBlock` helper + `planYearLabel` helper.

### Out of scope — flagged for clarification
The user also said: *"I noticed there is a 12 month issues and an issues list. This doesn't look right."* Both cards live on the Operations hub today (`issues.html?category=yearly` and `issues.html?category=current`). Not changing anything until the user confirms whether they want the categories merged, the cards renamed, or one removed.

---

## v0.5.197
- **Planning Cadence inheritance — children inherit parent's dates by default.** User: "Will these dates appear on parent and child versions?" + "Yes" (to adding inheritance).

Mirrors the v0.5.145 inheritance pattern (Core Values / Core Focus / Targets). For most holding companies the planning rhythm is shared across the whole group — you do annual planning together, quarterly sessions together. This change lets the parent set the cadence once and every child reads the same dates by default.

### Schema — `supabase/v0.5.197-delta.sql`
One additive SELECT policy on `business_cadence`:
```sql
CREATE POLICY "children read parent cadence" ON public.business_cadence
  FOR SELECT
  USING (
    organisation_id IN (
      SELECT parent_organisation_id
      FROM public.organisations
      WHERE id IN (SELECT public.user_org_ids(auth.uid()))
        AND parent_organisation_id IS NOT NULL
    )
  );
```
A user can SELECT a cadence row if its `organisation_id` is the `parent_organisation_id` of any org they're a member of. INSERT/UPDATE/DELETE still require admin+coach on the row's org — the new policy is read-only and purely additive.

### `cadence.html` — inheritance UI
- Detects this org's `parent_organisation_id` and loads own + parent cadence in parallel.
- Picks a mode:
  - `own` — has own row, no parent.
  - `inherited` — no own row but parent has one. Inputs disabled, populated with parent's dates.
  - `override` — own row AND parent has one. Inputs enabled, populated with own dates.
  - `empty` — no own, no inherit-able parent.
- New banner element at the top of the form:
  - **Inherited mode**: teal `📥 Inherited from <Parent>. These dates flow down from the parent. [Override locally]`.
  - **Override mode**: amber `✏️ Overridden locally from <Parent>. This business has its own dates. [Revert to parent]`.
- **Override locally** button → snapshots the parent's row into a new own row, switches to override mode.
- **Revert to parent** button → confirm prompt → deletes the own row → switches back to inherited mode (data is re-populated from the parent's row).
- `saveRow` + `scheduleSave` are no-ops when `mode === 'inherited'` (defence in depth — inputs are already disabled).
- On first save in `empty` mode, the row is created and the form transitions to `own` (or `override` if a parent has its own row too).
- `ws-input:disabled` styling: greyed-out background, `cursor: not-allowed`, muted text colour.

### `business.html` — Year Flow falls back to parent
`loadAndRenderYearFlow(orgId, targetId)` now:
1. Tries to load this org's own cadence row.
2. If empty, looks up `organisations.parent_organisation_id` for this org and tries the parent's cadence.
3. Renders whichever it finds.

Child dashboards now transparently show the parent's Year Flow timeline without any UI change — same dates, no banner (inheritance is silent on the dashboard, the cadence page is where it's explicit).

### `one-page-plan.html` — plan-year anchor falls back to parent
The cadence query in the doc header runs the same fallback: own → parent → calendar year. So a child biz's one-pager shows the parent's plan year (e.g. `Apr 2026 – Mar 2027`) without needing its own cadence row.

### Out of scope
- `account-plans.html` (cross-business strategy carousel) wasn't updated. Each business's plan-year label there still keys off its own cadence row only. Easy follow-up if needed — add `parent_organisation_id` to the orgs select and check the byOrg map for the parent's cadence before falling back to the calendar year.

### How to use
1. Run the v0.5.197 SQL.
2. On IASHQ, set the Planning Cadence dates (annual + Q1/Q2/Q3 + weekly).
3. Switch to a child biz (IAS General, IAS Life, IAS Outsourcing). The Year Flow on the home dashboard now shows IASHQ's dates. The Cadence page shows a teal "Inherited from IASHQ" banner with the inputs disabled.
4. To set different dates for a child, open the Cadence page on that child and tap **Override locally** — a fresh copy of the parent's dates becomes editable, and the banner turns amber. Tap **Revert to parent** to undo.

---

## v0.5.196
- **Year Flow panel now appears on the parent dashboard too.** User: "This is not appearing on this version."

### Diagnosis
The v0.5.195 implementation put the `📅 Year Flow` panel + render call inside `#standardMode` only. The user is on IASHQ, which is a parent biz — when a business has children, `business.html` switches to `#parentMode` and hides `#standardMode` via `display: none`. The Year Flow panel was inside the hidden subtree → never visible.

### Fix
- Added the same `<div class="dash-panel">` block to `#parentMode` (right after the quick-actions row, before Group Strategy) with a distinct id `yearFlowParent`.
- Refactored `renderYearFlow(cadence, targetId)` to accept a target element id (defaults to `yearFlow` for backwards compat).
- Extracted the cadence fetch into a shared `loadAndRenderYearFlow(orgId, targetId)` helper so both code paths can use it without duplication.
- `renderDashboard()` (own-business mode) calls `loadAndRenderYearFlow(orgId, 'yearFlow')`.
- `renderParentMode()` (parent mode) calls `loadAndRenderYearFlow(parentOrgId, 'yearFlowParent')` — using the parent biz's own cadence row, because the holding company has its own annual + quarterly + weekly rhythm distinct from its children.

### Cache note
The service worker also bumps to `coach4u-v0.5.196`, so the new business.html is cached fresh on next load. If the panel still doesn't appear, hard-refresh on iOS Safari (pull down at the top of the page) so the new sw.js is fetched.

---

## v0.5.195
- **Year Flow panel on the home dashboard.** User: "Add the dates on dashboard so it looks like a flow for the year."

### What it shows
A vertical timeline of the planning cadence for the year — up to 5 events sorted by date:
1. **🎯 Annual Planning** (from `last_annual_planning_date`)
2. **1** Q1 Session
3. **2** Q2 Session
4. **3** Q3 Session
5. **🎯 Annual Planning** (from `annual_planning_date` — the next one)

Each row has:
- A dot (numbered 1/2/3 for quarters, 🎯 for annual).
- Label + formatted date (`5 Jul 2026`).
- Status pill: `✓ Done` for past, `Next up` (highlighted teal with halo) for the next future event, `Upcoming` for later ones.

Below the timeline, a teal-bordered line rolls up the weekly cadence: `📆 Weekly meeting: Mondays at 9:00am`.

### Where it sits
Right after the Stat tiles (Open Issues / Goals On Track / Next Meeting) and before the 1-Year Goal panel — so the user sees the macro rhythm before drilling into the year's headline goal.

### Empty states
- No cadence row (or `business_cadence` table doesn't exist yet): *"Set your planning cadence to see your year flow → Set it up"* (teal link to `cadence.html`).
- Row exists but no dates filled in: *"No planning dates set yet → Set up your cadence"*.

### Edit link
The panel head has an **Edit ›** link that goes to `cadence.html`.

### Implementation
- New CSS rules (`.flow-row`, `.flow-dot`, `.flow-info`, `.flow-label`, `.flow-date`, `.flow-status`, `.flow-empty`, `.flow-weekly`) added to the inline `<style>` in `business.html`.
- New `<div class="dash-panel">` inserted into `#standardMode` between the stat-row and the 1-Year Goal panel.
- New `renderYearFlow(cadence)` function: sorts events by date, classifies each as `past` / `next` / `upcoming` against today's ISO date, renders the rows + weekly line.
- `renderDashboard()` now does a follow-up Supabase query against `business_cadence` (caught defensively) and calls `renderYearFlow` with the result.

### Out of scope
- Parent-mode (`renderParentMode`) — holding-company dashboard wasn't touched in this version. Easy follow-up if needed (drop in the same panel + render call).

---

## v0.5.194
- **Dropped Q4 from the Planning Cadence form.** User: "Remove q4 date. The flow is Annual planning then q1, 2, 3."

The annual planning session acts as the year-end / year-start anchor — Q4 was double-counting that. The flow per year is now:

1. **Annual Planning** (replaces Q4 + kicks off the new year)
2. **Q1** session
3. **Q2** session
4. **Q3** session

### Change — `cadence.html`
- Q4 session block (Day 1 + Day 2 inputs) removed from the Quarterly Sessions card.
- Card description updated to: *"Q1, Q2 and Q3 sessions — the annual planning session above replaces Q4 as the year's end + start. Day 2 is optional, for sessions that run across two days."*
- `FIELDS` array shrinks from 13 → 11 (drops `q4_session_date` and `q4_session_date_2`). The form no longer touches those columns.

### No SQL
- The `q4_session_date` and `q4_session_date_2` columns from v0.5.192 / v0.5.193 stay in the `business_cadence` schema. Existing data (if any) is preserved; the form just no longer reads or writes them.
- If you ever want to re-introduce Q4 later, no migration needed — just re-add the inputs.

### Unaffected
- Plan-year anchor logic on `one-page-plan.html` and `account-plans.html` is keyed by `last_annual_planning_date` first, `annual_planning_date` second — Q4 was never part of that path, so no change.

---

## v0.5.193
- **Planning Cadence extensions: last-annual date + 2nd-day per session.** User: "Add in planning cadence — Last annual planning date. And add 2 dates for every session in case they want to do more than one."

### Schema — `supabase/v0.5.193-delta.sql`
6 nullable `date` columns added to `business_cadence`:
```sql
ALTER TABLE public.business_cadence
  ADD COLUMN IF NOT EXISTS last_annual_planning_date date,
  ADD COLUMN IF NOT EXISTS annual_planning_date_2     date,
  ADD COLUMN IF NOT EXISTS q1_session_date_2          date,
  ADD COLUMN IF NOT EXISTS q2_session_date_2          date,
  ADD COLUMN IF NOT EXISTS q3_session_date_2          date,
  ADD COLUMN IF NOT EXISTS q4_session_date_2          date;
```
No RLS change — the v0.5.192 policies cover the new columns automatically.

### `cadence.html` — form layout
- **Annual Planning card** now stacks:
  - `Last annual planning date` (when the last one happened — the new plan-year anchor)
  - `Next annual planning` → `Day 1` + `Day 2 (optional)` in a 2-column grid
- **Quarterly Sessions card** — each quarter is now its own labeled block with `Day 1` + `Day 2 (optional)` side-by-side:
  ```
  Q1 session
    [Day 1]    [Day 2 (optional)]
  Q2 session
    [Day 1]    [Day 2 (optional)]
  …
  ```
- The plan-year summary line at the bottom of the Annual card now prefers `last_annual_planning_date` if set; otherwise uses `annual_planning_date` with the suffix `"(anchored from next session)"` so the user knows which date is driving the label.
- `FIELDS` array bumped from 7 entries to 13 to include all new columns. Same upsert pattern; auto-save still 350ms debounce.

### Plan-year anchor — One-Page Plan + carousel
- `one-page-plan.html` — the `business_cadence` query now selects both `last_annual_planning_date` and `annual_planning_date`; the doc-header year label picks `last_annual_planning_date` first (because that's when the current plan year actually started), then falls back to `annual_planning_date`, then to the current calendar year.
- `account-plans.html` — same precedence applied per business in the carousel. The `cadence` object on each org now holds both dates and `planYearLabel(...)` picks the right anchor.

### Why
A business does annual planning on (say) Apr 1, 2026 — that's when the current plan year *started*. The "next" annual planning date (Apr 1, 2027) is the *end* of the plan year, not the start. Using `last_annual_planning_date` as the anchor produces a more honest "Plan year: Apr 2026 – Mar 2027" label on the One-Page Plan.

---

## v0.5.192
- **Planning Cadence — per-business rhythm record + plan-year anchor on the one-page plan.** User: "One page plan dates are 10 years. This isn't correct. It's only ever one year some might start at different times so where does the date get listed" + "In planning I want to be able to allocate dates for annual planning date then the quarterly sessions. Then a day to list the weekly day and time."

### Schema — `supabase/v0.5.192-delta.sql`
New `business_cadence` table — one row per organisation:
```sql
CREATE TABLE public.business_cadence (
  organisation_id      uuid PRIMARY KEY REFERENCES public.organisations(id) ON DELETE CASCADE,
  annual_planning_date date,
  q1_session_date      date,
  q2_session_date      date,
  q3_session_date      date,
  q4_session_date      date,
  weekly_meeting_day   text CHECK (weekly_meeting_day IS NULL OR weekly_meeting_day IN
                                   ('monday','tuesday','wednesday','thursday','friday','saturday','sunday')),
  weekly_meeting_time  time,
  updated_at           timestamptz NOT NULL DEFAULT now()
);
```
RLS: members read, admins+coaches write (via existing `user_org_ids` / `user_admin_org_ids` helpers — same pattern as every other org-scoped table).

### New page: `cadence.html`
- Three cards:
  1. **Annual Planning** — single date input. The date anchors the plan year (drives the One-Page Plan's date label).
  2. **Quarterly Sessions** — 4 date inputs (Q1–Q4) in a 2-column grid. Any can be blank.
  3. **Weekly Team Meeting** — day-of-week dropdown + time input.
- Auto-saves on change with 350ms debounce.
- Inline summaries:
  - Annual: *"Plan year: Apr 2026 – Mar 2027"* (a 12-month window from the annual date).
  - Weekly: *"Weekly meeting: Mondays at 9:00am"*.
- Defensive: if the `business_cadence` table doesn't exist yet, the save status shows *"Schema not migrated yet — run supabase/v0.5.192-delta.sql"*.

### Entry point
- New **📅 Planning Cadence** card added to the top of `planning.html`'s activity grid (above Annual / Quarterly / Team Check-ins).

### One-Page Plan now uses the cadence
- `one-page-plan.html` — the doc-header right-side year label changed from `${currentYear} – ${currentYear + 10}` (which read as if the whole plan was 10 years) to a 12-month window driven by `business_cadence.annual_planning_date`. If a cadence is set: `Apr 2026 – Mar 2027`. If not: just the current calendar year (`2026`). The cadence is fetched in parallel after init renders, so the label updates as soon as it loads — no visible flash.
- `account-plans.html` — same upgrade for the cross-business carousel. The Promise.all goes from 6 → 7 queries (adds `business_cadence` for all orgs at once), and each business card's plan-year label is computed from that business's own cadence. Defensive: if the cadence query errors (migration not applied), each org falls back to the calendar year.

### Why this matters
Different businesses run their planning year on different calendars (fiscal year Jul–Jun, calendar Jan–Dec, custom). The cadence record makes this explicit and lets every other page (one-pagers, carousels, and future reminders/dashboards) pull from a single source of truth instead of guessing from the current date.

---

## v0.5.191
- **Full audit + cleanup of header back links.** User: "Those backlinks are not needed? Do full audit for back links."

The v0.5.189 principle (back link is redundant when the bottom-nav already covers the destination) applied across the whole app.

### Audit
`grep -l 'class="header-back"' *.html` found 21 pages with a back link. Each was categorised by destination → bottom-nav coverage.

### Removed (14 pages)
Back link goes to a hub the bottom-nav already covers:
- **Strategy hub** (Strategy tab in bottom-nav): `core-focus.html`, `core-values.html`, `financials.html`, `leadership-team.html`, `marketing-strategy.html`, `targets.html` — all linked back to `strategy.html`.
- **Operations hub** (Operations tab): `goals.html`, `issues.html`, `scorecard.html`, `meeting.html`, `twelve-month-goal.html` — all linked back to `operations.html`.
- **Planning hub** (Planning tab): `annual-sessions.html`, `quarterly-sessions.html`, `team-checkins.html` — all linked back to `planning.html`.

Performed via `sed -i '/class="header-back"/d'` (the class is uniquely on the anchor, so the single-line strip is safe).

### Kept (4 workspaces)
Back link goes to an intermediate list page that the bottom-nav doesn't reach directly:
- `run-meeting.html` → `meeting.html` (specific meeting workspace → meetings list).
- `run-annual-session.html` → `annual-sessions.html`.
- `run-quarterly-session.html` → `quarterly-sessions.html`.
- `run-team-checkin.html` → `team-checkins.html`.

### Kept (3 account-level pages)
- `account-strategy.html`, `account-operations.html`, `account-planning.html` — their bottom-nav has only the `🏛️ Account` tab (one item, already-active). With no real navigation rail at the bottom, the header back link is the obvious way out.

### Side effect — account-scope JS on the planning lists
`annual-sessions.html`, `quarterly-sessions.html`, `team-checkins.html` each have `?scope=account` JS that previously swapped the back-link's text/href to `← Account Planning`. The `if (back) { ... }` guard makes the now-dead `querySelector('.header-back')` a no-op (no error), but the legacy back-to-account-planning affordance is gone. That's fine — `account-planning.html` was already noted as "legacy" in v0.5.146 and is reachable only via the Account button in the header.

---

- **Org chart "Add" copy.** User: "In org chart say add leadership team member."

`leadership-team.html`'s primary CTA: `+ Add Team Member` → `+ Add Leadership Team Member`. The page is reached via the **Organisational Chart** card on Strategy (renamed in v0.5.183), so the button now matches that framing — you're adding a Leadership Team Member to the Organisational Chart. The worksheet page title still reads "Leadership Team" and the underlying table is still `leadership_team_members` for compatibility.

---

## v0.5.190
- **Two cleanups on the one-page docs.** User: "I think the font is different from one page links. Make consistency. Also the financials are on both of them. Only needed on strategy."

### Font consistency
The 4 doc files (`one-page-plan.html`, `one-page-operations.html`, `account-plans.html`, `account-ops-plans.html`) all had `.plan-page { font-family: 'Aptos', 'Segoe UI', system-ui, sans-serif; }` — missing the `-apple-system` + `BlinkMacSystemFont` fallbacks that the site-wide `--font-body` CSS variable in `css/style.css` includes. On iOS this resolved through a slightly different fallback path than the rest of the app, producing the subtle inconsistency the user spotted.

Changed each `.plan-page` override to `font-family: var(--font-body)` so the docs now use the exact same stack as every other page:
```css
--font-body: 'Aptos', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
```

### Financials moved off Operations one-pagers
The "Financial Outlook" strip (Last Year + This Year annual totals) used to render on both the Strategy one-pager and the Operations one-pager. Now it lives only on Strategy — that's the right place for financial outlook (the Operations doc is about quarterly goals + weekly numbers + open issues, not financial summary).

**`one-page-operations.html`**:
- Removed the `.doc-financials` HTML block (3 cards row → footer).
- Removed `fmtCurrency`, `profitClass`, `aggregateYear`, `renderAnnualFinancials` helpers.
- Removed the `financial_periods` query from `Promise.all` (4 parallel queries → 3).
- Removed the `thisYear`, `lastYear`, `finStart`, `finEnd` windowing constants.
- Removed `renderAnnualFinancials([])` from the catch-block fallback.

**`account-ops-plans.html`**:
- Removed the `.doc-financials` HTML block from the carousel card template.
- Removed `buildAnnualTotalsBlock` + `fmtCurrency` + `thisYear`/`lastYear` constants.
- Removed the `financial_periods` query (4 parallel queries → 3) and the per-org `finByYear` accumulator.

### What's preserved
- The `.doc-financials` + `.fin-strip-*` + `.fin-line*` CSS rules stay in both files (small, harmless, and identical to the strategy docs that still use them). Not worth churning the diff for a few rules of dead styling.
- Strategy one-pager (`one-page-plan.html`) + Strategy carousel (`account-plans.html`) keep the financial outlook strip — that's the only place it now renders.

No SQL.

---

## v0.5.189
- **Removed the redundant back link from the one-page plan + ops toolbars.** User: "The back link isn't needed is it?"

After v0.5.188 added the standard 5-tab bottom-nav (Home · Planning · Strategy · Operations · Learn) to both presentation docs, the toolbar's `← Strategy` / `← Operations` back link was redundant — Strategy and Operations are now one tap away in the nav, plus Home (which the back link never offered).

### Change
- `one-page-plan.html` — removed `<a href="strategy.html" class="toolbar-back">← Strategy</a>` from `.toolbar-left`.
- `one-page-operations.html` — removed `<a href="operations.html" class="toolbar-back">← Operations</a>` from `.toolbar-left`.

### Net effect
- **Desktop toolbar**: `[page title · 🏢 IASHQ]` left, `[🖨️ Print]` right.
- **Phone toolbar** (where `.toolbar-title` is hidden via the v0.5.186 rule): `[🏢 IASHQ]` left, `[🖨️ Print]` right — clean and uncluttered.

The CSS for `.toolbar-back` itself is left in the file in case it's reused elsewhere; it just doesn't render anymore. Bottom-nav and print rules unchanged.

---

## v0.5.188
- **Bottom-nav added to the one-page plan + one-page operations.** User: "The link to the one page operations page has a back link to operations. I wonder if it should have the tabs down the bottom like the other pages?"

### Why
After v0.5.185 made these docs screen-friendly (single-column stacked on phones), the doc scrolls a long way. Without a bottom-nav, the only navigation affordance was the `← Strategy` / `← Operations` back link at the top of the page — so from the bottom of a long scroll, the user had to scroll all the way back up to leave for any other tab. Every other business-level page (22 of them) already has the standard 5-tab nav fixed at the bottom; these two were the odd ones out.

### Change
`one-page-plan.html` and `one-page-operations.html` each get a `<nav class="bottom-nav">` block matching the other business-level pages:
- Items: **🏠 Home · 🗺️ Planning · 🧭 Strategy · ⚙️ Operations · 📚 Learn**.
- Active tab: **Strategy** on `one-page-plan.html`, **Operations** on `one-page-operations.html` — same hub the back link goes to.
- CSS for `.bottom-nav` + `.bottom-nav-item` + `.bottom-nav-icon` inlined into each file's `<style>` block (matches the existing pattern across the codebase rather than relying on css/style.css).
- `body { padding-bottom: 24px }` → `80px` so the doc-footer doesn't sit behind the fixed nav.

### Print is unchanged
The existing `@media print` block in each file now hides `.bottom-nav` alongside `.screen-toolbar` and `.mobile-hint`, so paper output is still just the doc — no nav, no toolbar.

---

## v0.5.187
- **External Org Chart URL on the Leadership Team page + One-Page Plan.** User: "Add to organisation chart a way they can add a link to their org chart. This can be created external from app if they want it. Including this link on the one page plan."

### Why
Many users prefer to build their org chart in a visual tool (Lucidchart, Miro, Google Drawings, Figma, draw.io, Whimsical, FigJam…) rather than describe it as a list of leadership-team rows. This lets them paste that share-link once and have it surface for the whole team.

### Leadership Team page (`leadership-team.html`)
- New **🔗 Org Chart Link** card at the top of the worksheet, above the "+ Add Team Member" button.
- Single URL input + a teal **👁️ View →** button that appears next to it when a URL is set (opens in a new tab with `rel="noopener noreferrer"`).
- Auto-saves on input with a 400ms debounce; status line shows "Saving…" → "Saved ✓".
- URLs pasted without a scheme (e.g. `lucid.app/lucidchart/xxx`) get `https://` prepended on render so the link still works.
- Defensive: if the migration hasn't run yet (column doesn't exist), the status line shows "Schema not migrated yet — run supabase/v0.5.187-delta.sql" rather than failing silently.

### One-Page Plan (`one-page-plan.html`)
- New small `🔗 View org chart →` link in the **Leadership Team** field of the "Who We Are" column, below the team-member list. Teal, hidden when no URL is set.
- The `organisations` query that was conditional (`cachedName ? null : fetch name`) now always runs and selects `name, org_chart_url` — tiny cost, much simpler.

### Account-level carousel (`account-plans.html`)
- The cross-business one-page plan carousel surfaces the same link per business — fetches `org_chart_url` via the existing `organisations!inner(...)` join on the `team_members` query, then renders via a `chartLink()` helper inside the Leadership Team field.

### Schema — `supabase/v0.5.187-delta.sql`
```sql
ALTER TABLE public.organisations
  ADD COLUMN IF NOT EXISTS org_chart_url text;
```
No RLS change — the existing `organisations` policies cover it (members read, admins + subscription owner write). The column is nullable; businesses without a chart link just don't render the link.

### Out of scope
- The parent/child inheritance pattern from v0.5.145 doesn't apply here — `organisations.org_chart_url` is not in the children-read-parent policies (those cover `core_values`, `core_focus`, `targets`). A child business sees only its own `org_chart_url`, not the parent's. If we want a parent's link to inherit to children automatically, follow the same RLS-additive pattern; not done here because the typical case is each business has its own chart.
- `account-leadership.html` (the leadership-team carousel) was not updated in this version; it shows just the team list. Easy follow-up if needed.

---

## v0.5.186
- **Tidier toolbar on phones for the one-page plan + operations.** User screenshot of `one-page-plan.html` on iPhone showed the white screen-toolbar cramming 4 elements (`← Strategy` + page title + biz pill + Print button) into ~390px width — the page title was truncated to "One-P..." and the biz pill clipped to "I...".

### Hide the toolbar page title on phones (≤ 600px)
Below 600px viewport, `.toolbar-title` is set to `display: none`. The page title ("One-Page Business Plan" / "One-Page Operations") is redundant on a phone because the navy doc-header right below the toolbar already renders it prominently as `.doc-plan-title` ("ONE-PAGE BUSINESS PLAN" in large letterspaced caps). Dropping it from the toolbar frees enough room for the biz pill ("🏢 IASHQ") to render its full text. Desktop (> 600px) still shows the title in the toolbar.

### Trim the Print button label
"🖨️ Print / PDF" → "🖨️ Print" everywhere. Modern browsers' print dialog always includes "Save as PDF" anyway, so the "/ PDF" was redundant. On phones (≤ 600px), the button also gets a smaller padding (`8px 12px` vs `8px 14px`) and font-size (`0.78rem` vs `0.82rem`) so it takes less horizontal space.

### Net effect
- Phone toolbar: **`← Strategy · 🏢 IASHQ · 🖨️ Print`** — no truncation, all elements readable.
- Desktop toolbar: **`← Strategy · One-Page Business Plan · 🏢 IASHQ · Print`** — unchanged.

---

## v0.5.185
- **One-page plan + one-page operations: screen-first layout for phones + portrait tablets.** User: "I really like the one page printed plan but can this information appear online screen first. ... I just think for those people that prefer to see it on screen."

### Approach
Rather than create separate screen-only files, the existing `one-page-plan.html` and `one-page-operations.html` are now responsive. Same URL, same data fetching, two presentations:
- **Screen viewport ≥ 820px** — current 3-column landscape layout (unchanged).
- **Screen viewport < 820px** (phone, portrait tablet) — single-column stacked layout with thumb-readable typography.
- **Print** — current 3-column landscape A4 layout (unchanged, always wins via `@media print`).

The `screen` keyword on the new mobile rules (`@media screen and (max-width: 820px)`) prevents them applying when printing, so tapping Print / PDF on a phone still outputs the proper landscape A4.

### What the screen layout does
- `.plan-page` — drops the `min-width: 760px` (plan) / `min-width: 820px` (ops) so the doc collapses to viewport width.
- `.doc-body` — switches `grid-template-columns` from `1fr 1.45fr 1fr` (plan) / `1fr 1.55fr 1fr` (ops) to a single `1fr`, so the 3 cards stack vertically.
- `.doc-col` — swaps `border-right` (column divider) for `border-bottom` (row divider) so the visual rhythm follows the stack.
- **Typography bumped for thumb reading**: field labels 0.56→0.66rem, field values 0.76→0.95rem, column headings 0.6→0.72rem, value pills 0.68→0.82rem, num-list items 0.73→0.92rem, padding 14→18px.
- `.fin-strip-body` — Financial Outlook strip (Last 12/Next 12 on plan; Last Year/This Year on ops) stacks to 1 column.
- **Operations scorecard**: `#opp-scorecard` gets `overflow-x: auto` so the wide weekly-numbers table can scroll horizontally inside its column while the rest of the doc still stacks normally. Cell padding bumped from 4px to 6-7px for finger taps.

### Cleanup
- Removed the obsolete "← Scroll right to see the full plan" mobile-hint banner from both files (no longer needed — the doc fits the viewport now).
- Toolbar hint updated: "Scroll to see full plan · Print for landscape A4" → "Tap Print to save as PDF or print landscape A4".

### Entry points
Unchanged. The `🗓️ View One-Page Plan` and `📋 View One-Page Operations` quick-action buttons already live on the Home page (`business.html`) from v0.5.174.

---

## v0.5.184
- **Consistent wording + de-duplicated the 12-Month horizon.** User: "The yearly /12 month wording needs to be consistent. Does the split make sense over the 2 pages?" + "It's not intention to have on both pages. Agree with your suggestions."

### Wording — "Yearly Issues" → "12 Month Issues"
The Operations card sat at the same time-horizon as "12 Month Goal" but used different words. Renamed everywhere it surfaces:
- `operations.html` — card title (label only; URL still `issues.html?category=yearly`, DB category value still `'yearly'`).
- `issues.html` — `CAT_META.yearly.title` switches from "⚡ Yearly Issues" to "⚡ 12 Month Issues" (page heading + `document.title`).
- `issues.html` — modal Category `<select>` option label "Yearly Issues — long-horizon" → "12 Month Issues — long-horizon".

### Split — 12-Month moves off Strategy, lives only on Operations
Strategy's Targets card and Operations' "12 Month Goal" card both opened `targets.html`, which showed all 4 timeframes (10/5/3-Year + 12-Month). The user could set the 12-month goal from either entry point, which contradicted the intent that Operations owns the annual horizon.

- **`targets.html`** — dropped the 12-Month card from the UI. Worksheet now has 3 cards: 10-Year, 5-Year, 3-Year. `FIELDS` array shrinks from `['ten_year', 'five_year', 'three_year_desc', 'one_year_goals']` to the first three. Sub-heading updated to mention the move: "10-year, 5-year, and 3-year goals. (The 12-Month goal lives on Operations.)"
- **New `twelve-month-goal.html`** — dedicated single-textarea editor. Same Operations chrome (← Operations back, Operations active in bottom nav). Reads + writes `targets.one_year_goals` for the active org with the standard 300ms debounce + auto-save pattern. Layout copied from `targets.html` so it feels native.
- **`operations.html`** — "12 Month Goal" card `href` changed from `targets.html` to `twelve-month-goal.html`.
- **`strategy.html`** — Targets card description trimmed: "10-year, 5-year, 3-year and 12-month goals" → "10-year, 5-year and 3-year goals".

### Data — no schema change
The `targets.one_year_goals` column stays in the schema and is still read by everything that consumed it before:
- `business.html` — 1-Year Goal panel (own + parent rollup).
- `one-page-plan.html` — printable strategy doc.
- `account-plans.html` — cross-business strategy carousel.
- `account-targets.html` — Targets carousel.
- `run-annual-session.html` + `run-quarterly-session.html` — area link rewriting unchanged.

Only the **editor** moved; the data layer is untouched. Existing 12-month goals continue to display on all dashboards and one-pagers; users now edit them via Operations → 12 Month Goal instead of Strategy → Targets.

---

## v0.5.183
- **Strategy + Operations restructure with a 3-way Issues split.** User: "This is the order for strategy: Financials / Core values / Marketing strategy / Leadership team / Organisational chart" + new Operations layout listing 12 Month Goal / Yearly Issues / Quarter Goals / 90 Day Numbers / Issues List / Future Issues List / Weekly Meetings.

### Strategy (`strategy.html`)
- Cards reordered: **Financials → Core Values → Marketing Strategy → Organisational Chart → Targets**.
- The "Leadership Team" card is renamed to **Organisational Chart**. Card still links to `leadership-team.html` — the underlying worksheet keeps its name to avoid breaking deep-links and historical references.
- **Core Focus** is removed from Strategy. It moves to Operations as **12 Month Goal** (links to `targets.html`).
- Targets card description trimmed to `10-year, 5-year, 3-year and 12-month goals`.

### Operations (`operations.html`)
- Rebuilt as 7 cards in the new order:
  1. **🎯 12 Month Goal** — `targets.html`
  2. **⚡ Yearly Issues** — `issues.html?category=yearly`
  3. **🏆 Quarter Goals** — `goals.html`
  4. **📊 90 Day Numbers** — `scorecard.html`
  5. **📋 Issues List** — `issues.html?category=current`
  6. **⏳ Future Issues List** — `issues.html?category=future`
  7. **🗓️ Weekly Meetings** — `meeting.html`
- The 3 issues cards are a real category split, not a label swap.

### Issues (`issues.html`) — categorised
- Reads `?category=` from the URL (`yearly` | `current` | `future`, defaults to `current` if missing or invalid).
- `<h1>` + sub-paragraph + `document.title` swap based on category:
  - `yearly` → "⚡ Yearly Issues — Long-horizon issues to surface at annual planning."
  - `current` → "📋 Issues List — This week and this quarter — discuss and resolve."
  - `future` → "⏳ Future Issues List — Backlog of things to address later — not urgent yet."
- The Supabase `from('issues').select()` query gains `.eq('category', CATEGORY)` so each card only shows its own bucket.
- New **Category** `<select>` in the add/edit modal (Yearly / Current / Future). New issues default to the current view's category; existing issues can be re-classified by changing the dropdown and saving.
- Insert + update payloads now include `category`.

### Other callers filtered to `category='current'`
The operational dashboards/one-pagers should ignore yearly + backlog items so the weekly meeting view stays clean:
- `business.html` — own-mode "Open Issues" count + parent-mode child-rollup query.
- `one-page-operations.html` — printable ops doc Open Issues column.
- `account-ops-plans.html` — cross-business ops carousel Open Issues column.
- `account-issues.html` — account-level issues carousel.
- `run-meeting.html` — IDS section link `issues.html` → `issues.html?category=current`.

### SQL — `supabase/v0.5.183-delta.sql`
```sql
ALTER TABLE public.issues
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'current';

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'issues_category_check') THEN
    ALTER TABLE public.issues
      ADD CONSTRAINT issues_category_check
      CHECK (category IN ('yearly', 'current', 'future'));
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS issues_org_category_idx
  ON public.issues(organisation_id, category);
```
Existing rows backfill to `current` so day-1 the Issues List card on Operations looks identical to today's Issues view.

---

## v0.5.182
- **Trim Targets card titles to just the timeframe.** User: "Change the targets to each target / 10 year, 5 year etc."
- Dropped the "Goal" suffix from each card on `targets.html`. Net titles:
  - "10-Year Goal" → "10-Year"
  - "5-Year Goal" → "5-Year"
  - "3-Year Goal" → "3-Year"
  - "12-Month Goal" → "12-Month"
- The Strategy hub still labels the section "Targets" (the worksheet title `🎯 Targets` is unchanged), so each card being just the timeframe reads cleanly.
- Card descriptions, placeholders, columns (`ten_year`, `five_year`, `three_year_desc`, `one_year_goals`) and save logic unchanged.
- **No SQL.**

---

## v0.5.181
- **Simplify the Targets worksheet: one text box per timeframe + new 5-Year Goal.** User: "Change targets and move to individual boxes for 10 year goal / 5 year goal / 3 year goal / 12 month goal."
- **Before:** 3 worksheet cards.
  - 10-Year Vision (one textarea → `ten_year`).
  - 3-Year Outlook (3-column grid of date/revenue/profit text inputs + a description textarea → `three_year_date`, `three_year_revenue`, `three_year_profit`, `three_year_desc`).
  - 1-Year Plan (same 3-column grid + a numbered-goals textarea → `one_year_date`, `one_year_revenue`, `one_year_profit`, `one_year_goals`).
- **After:** 4 cards, each with a single `<textarea>`:
  - 10-Year Goal → `ten_year`
  - 5-Year Goal → `five_year` (NEW column added by migration)
  - 3-Year Goal → `three_year_desc`
  - 12-Month Goal → `one_year_goals`
- **`FIELDS` array dropped from 9 → 4.** Only those 4 columns get touched on save now.
- **Non-destructive:** the other 6 columns (`three_year_date` / `three_year_revenue` / `three_year_profit`, `one_year_date` / `one_year_revenue` / `one_year_profit`) stay in the schema with their existing data intact. They're just no longer editable in the worksheet UI. Consumer pages that read those legacy columns (the standard-mode 1-Year Goal panel on `business.html`, the parent-mode Group Financials Revenue rollup, `one-page-plan.html`'s 3-year / 1-year rows) keep working — they'll show empty for orgs that never had those values, populated for those that did.
- **Migration (`supabase/v0.5.181-delta.sql`):**
  ```sql
  ALTER TABLE public.targets ADD COLUMN IF NOT EXISTS five_year text;
  NOTIFY pgrst, 'reload schema';
  ```
  RLS unchanged — the existing "children read parent targets" SELECT policy already covers the whole row, so the new column inherits the same gating.

---

## v0.5.180
- **Strip the last mini-stat from child cards on the parent dashboard.** User: "Remove goals on track in child accounts."
- v0.5.179 had already trimmed child cards down to a single "Goals on track: X of N" line. This version removes that line too, leaving each child card as just **↳ Name  Open ›**.
- **HTML:** dropped the entire `<div class="child-card-mini">…</div>` block from the per-card template, including the `goalsValClass` variable. The card template is now just `child-card-head` with the arrow + name + Open chip.
- **CSS:** nulled the `margin-bottom: 10px` on `.child-card-head` (no row below it anymore).
- **JS:** `rocksPerChild` Map is still computed (one extra `forEach` over the rocks fetch is cheap and the data may resurface elsewhere), but no longer read. Child-card click handler that switches the active org and reloads is unchanged.
- **No SQL.**

---

## v0.5.179
- **Trim + re-order the parent dashboard.** Four changes on `business.html`'s parent-mode (rendered when the active biz has children, e.g. IASHQ):
- **(1) Group Strategy panel** — shows ONLY the 12-Month Goal row. The 10-Year Vision and 3-Year Outlook rows were dropped. The JS still computes the 10yr / 3yr text from `targets`, but `setText('parentTenYear', …)` / `setText('parentThreeYear', …)` become no-ops because the elements no longer exist in the DOM — `setText` guards with `if (!el) return`.
- **(2) Group Financials panel** — shows ONLY 2 cells: "1-Year Revenue Target" + "Last 12mo Profit". The "Last 12mo Revenue" and "Last 12mo Expenses" cells were dropped. `setFin` got the same `if (!el) return` guard so the remaining calls don't try to write to gone-elements.
- **(3) Panel order** changed:
  - was: Group Strategy → This Quarter's Priorities → Group Financials → Child Businesses
  - is: **Group Strategy → Group Financials → This Quarter's Priorities → Child Businesses**
  - Rationale: financials are the headline number; the user wants to glance at them right after the strategy line.
- **(4) Child cards** — show ONLY "Goals on track: X of N". Removed the "Open Issues:" and "Next meeting:" rows. The `allChildIssues` / `allChildMeetings` queries still fire (they're cheap, may be used elsewhere later); the maps just aren't rendered.
- **Net:** parent dashboard reads tighter — 4 panels in the new order, each with less competing detail. Same data still in the database; readers just see a focused subset.
- **No SQL.**

---

## v0.5.178
- **Align heading positions across the 5 hub pages.** User: "If you look at each page the headings all start at a different spot. Should all be consistent."
- **Root cause:** `css/style.css` line 161 sets a global `.container { max-width: 1200px; margin: 0 auto; padding: 32px 20px; }`, with a `@media (max-width: 640px)` override to `padding: 20px 16px`. Four hubs (Home / Planning / Strategy / Operations) overrode only `padding-bottom: 80px` (or 88px) in their inline `<style>` blocks. CSS cascade: their other three sides inherited the global rule, so the heading sat ~32px (or ~20px on mobile) below the container top edge and ~20px (16px mobile) from the left. `learning-vault.html` used the shorthand `padding: 0 0 90px`, which **fully resets** all four sides to 0/0/90/0 — its heading sat at the container's top-left corner.
- **Net visible difference on mobile:** Learn heading ~20px below container top, 16px from left edge. Other four hubs: heading ~40px below, ~32px from left edge. ~20px horizontal + ~20-32px vertical misalignment.
- **Fix:** changed the four hubs' container rule from `padding-bottom: Xpx` to `padding: 0 0 Xpx;` (full shorthand) — same form Learn was already using:
  - `business.html`: `padding-bottom: 88px` → `padding: 0 0 88px;`
  - `planning.html`: `padding-bottom: 80px` → `padding: 0 0 80px;`
  - `strategy.html`: same
  - `operations.html`: same
  - `learning-vault.html`: already correct (`padding: 0 0 90px`)
- The `.ws-header` (and `.vault-header`) `padding: 20px 16px 0;` is now the sole thing controlling where each heading sits — identical on all five pages.
- **No SQL.**

---

## v0.5.177
- **Center the "Run Weekly Meeting" button on the home page.** User: "Run weekly meeting box needs to be centred."
- The button was using `display: flex; justify-content: space-between;` with a label-span on the left and a `›` arrow-span on the right. That made the label sit hard-left in a button right above two centred view-plan buttons — visually jarring.
- **CSS:** `justify-content: space-between` → `justify-content: center`. Added `text-align: center`. Font-size bumped 0.88rem → 0.9rem so it matches `.view-plan-btn` exactly. Dropped the unused `.meeting-btn-arrow` rule.
- **HTML:** removed the `<span>label</span><span class="meeting-btn-arrow">›</span>` two-span markup; the anchor now contains plain inline content (`🗓️ Run Weekly Meeting`). Both occurrences updated — `#runWeeklyMeetingBtn` in standardMode and `#runWeeklyMeetingBtnParent` in parentMode.
- **No SQL.**

---

## v0.5.176
- **Add the same heading + sub pattern to Home and Learn, completing the five-hub consistency.** User: "Have home and learn with the same headings."
- **Home (`business.html`):**
  - Added `.ws-header` / `.ws-title` / `.ws-sub` CSS (same values as the other hubs).
  - Inserted `<div class="ws-header"><h1>🏠 Home</h1><p>…</p></div>` at the top of `.container`, just above the parent/child context row (`#bizContextRow`).
  - Sub copy: *"Your business overview at a glance — key numbers, this week's focus, and quarterly priorities."*
  - The active-org pill in the sub-toolbar above still shows the business name; the new heading announces *what page you're on*.
- **Learn (`learning-vault.html`):**
  - Aligned existing `.vault-header` / `.vault-title` / `.vault-sub` rules to match `.ws-*` values:
    - padding `24px 16px 4px` → `20px 16px 0`
    - title font-size `1.15rem` → `1.2rem`
    - sub margin `0` → `0 0 20px`; line-height `1.45` → `1.5`
  - Title renamed `📚 Learning Vault` → `📚 Learn` to match the bottom-nav tab label (Home / Planning / Strategy / Operations / Learn).
  - Sub copy preserved.
- **Net consistency:** all five hub pages now render an identical-looking heading block (icon-prefixed title + grey sub-line) above their main content. CSS values are byte-identical across the five files — keeps the visual pattern locked in.
- **No SQL.**

---

## v0.5.175
- **Add page-title + sub-description to Strategy and Operations hubs, matching Planning.** User: "The planning page has a heading a description. Do the same heading and sub detail under in the operations and operations."
- Both hubs (`strategy.html`, `operations.html`) were going straight from the navy header / active-org pill into the activity cards — no page identity, no orienting copy. The Planning page already had a `.ws-header` block above its cards from a previous build.
- **Inserted in each file:**
  ```html
  <div class="ws-header">
    <h1 class="ws-title">🧭 Strategy</h1>
    <p class="ws-sub">The foundations of your business — Core Values, Core Focus, Targets, Marketing and your Leadership Team.</p>
  </div>
  ```
  (Operations title is `⚙️ Operations` with sub *"Your weekly cadence — track the numbers, run team meetings, ship quarterly goals, surface and resolve issues."*)
- **CSS added** to both files (each maintains its own `<style>` block):
  ```css
  .ws-header { padding: 20px 16px 0; }
  .ws-title { font-size: 1.2rem; font-weight: 800; color: var(--primary); margin: 0 0 4px; }
  .ws-sub { font-size: 0.85rem; color: #666; margin: 0 0 20px; line-height: 1.5; }
  ```
  These are the same rules planning.html uses — values copied verbatim so the three hubs are visually consistent.
- **No SQL.**

---

## v0.5.174
- **Consolidate the three primary actions onto the home page.** User: "Move one page plan to home page and remove it from planning and strategy and also move run weekly meetings and view one page operations to home and remove it from operations."
- **Added to `business.html`** at the top of both `<div id="standardMode">` and `<div id="parentMode">`:
  ```html
  <div class="quick-actions">
    <a class="meeting-btn" id="runWeeklyMeetingBtn">🗓️ Run Weekly Meeting ›</a>
    <a class="view-plan-btn" href="one-page-plan.html">📋 View One-Page Plan</a>
    <a class="view-plan-btn" href="one-page-operations.html">📋 View One-Page Operations</a>
  </div>
  ```
  Parent mode uses `runWeeklyMeetingBtnParent` as the id so both can co-exist in markup; only one is visible at a time depending on which mode renders.
- **New JS `wireRunMeetingButton(btnId, activeId)`** in `business.html` — same create-or-open-this-week's-meeting logic as the old button on `operations.html`, parametrised so it can be called once per mode (standard + parent).
- **Removed from `business.html`:** the "Go to This Week's Meeting" `<a class="meeting-btn" id="thisWeekMeetingBtn">` that used to sit between the Core Values and This Week panels; the JS line that rewrote its `href`. The Next-Meeting stat tile and "View Meeting ›" link inside the This Week panel still navigate to the meeting row when one exists.
- **Removed from `planning.html`** + **`strategy.html`:** the `<a class="view-plan-btn" href="one-page-plan.html">View One-Page Plan</a>` block. Those hubs now lead straight into their activity cards.
- **Removed from `operations.html`:** both the `<a class="meeting-btn" id="runWeeklyMeetingBtn">` and the `<a class="view-plan-btn" href="one-page-operations.html">` blocks; plus the `wireRunMeetingButton()` function definition + its call inside `init()` (~38 lines of JS).
- **CSS added to `business.html`:** `.quick-actions { padding: 12px 0 0; }` and `.view-plan-btn { ... }` — same pattern as the operations.html button it used to live in.
- **No SQL.**

---

## v0.5.173
- **Hotfix: green pill missing on home page.** User: "There is no green pill heading on Home Screen."
- **Cause:** in v0.5.164, when the navy header on `business.html` was decluttered (removed the `← Account` back link), the `<span id="activeBizName" class="biz-pill"></span>` was also dropped. As long as the v0.5.163 in-body BUSINESS row existed, the missing span didn't matter — the user could still switch businesses via that row. v0.5.172 removed the in-body row expecting the active-org.js pill to take over, but the script needs that span element to exist in the navy header. Without it, `relocatePillToSubToolbar()` finds nothing to relocate and the pill silently fails to render. No console error because the script defends with `if (!pill) return`.
- **Fix:** added `<span id="activeBizName" class="biz-pill"></span>` back to `business.html`'s `.header-left`, exactly where every other business-level page has it. On boot, `active-org.js`:
  1. Finds the empty span
  2. Sets its text to `🏢 IASHQ`
  3. Calls `relocatePillToSubToolbar()` — wraps it in a `<div class="biz-switcher-bar">` after the header
  4. Calls `renderBizSwitcher()` — since the IAS HQ account has 2+ businesses, replaces the span with a `<select>` populated by `fetchBizList()`
- Net result: the green pill (and its dropdown of IASHQ / IAS General / IAS Life / IAS Outsourcing) now appears in the standard sub-toolbar position on the home page, matching every other business-level page.
- **No SQL.**

---

## v0.5.172
- **Remove the in-body BUSINESS: row from `business.html`** — the home page now uses the same compact green pill (`js/active-org.js`'s sub-toolbar) as every other business-level page. User: "Show business: I want the green pill size the same as the other pages."
- **Why:** the in-body BUSINESS row added in v0.5.163 was a wide full-width affordance with a `BUSINESS:` label + a stretched `<select>`. Other business-level pages (planning / strategy / operations / etc.) just had a small teal pill in the sub-toolbar. Home page looked bigger / different. Two patterns for the same control.
- **Removed from `business.html`:**
  - `<div class="biz-switcher" id="bizSwitcherRow">` HTML block
  - `.biz-switcher` / `.switcher-label` / `.switcher-select` CSS rules
  - `.biz-switcher-bar { display: none !important; }` rule (was hiding the active-org.js pill on this page only)
  - The JS that computed `groupParentId`, filtered + sorted `groupMems`, and populated the `<select>` (~40 lines)
- **What stays:** the `.biz-extra-action` wrapper still hosts the `↑ Part of …` / `↓ N children` parent/child indicator. The `active-org.js` pill now appears on this page in the standard sub-toolbar position, matching the rest of the app.
- **Trade-off:** parent-child group scoping (v0.5.166 + v0.5.168) was specific to the in-body dropdown. The `active-org.js` pill scopes to the active subscription instead. For the current user (Cath, IAS HQ subscription contains exactly IASHQ + 3 IAS children), same result. If a user later puts multiple unrelated groups inside one subscription, the active-org pill would show all of them — could be addressed by updating `active-org.js` to apply the same parent-child scoping.
- **No SQL.**

---

## v0.5.171
- **Restyle the top-right Account button from a square chip to a teal pill.** User: "It's the square look instead of the green pill on top right."
- **CSS change in `css/style.css`** on `.header-account-btn`:
  - `background: rgba(255,255,255,0.15)` → `background: var(--accent)` (solid teal)
  - `border: 1px solid rgba(255,255,255,0.3)` → `border: none`
  - `border-radius: var(--radius-sm)` → `border-radius: 99px` (full pill)
  - `width: 32px; height: 28px;` → `height: 28px; padding: 0 11px 0 9px;` (auto-width to fit icon + label)
  - Added `gap: 4px; font-size: 12px; font-weight: 700; letter-spacing: 0.2px;` for the new label
  - Hover state darkens to `var(--accent-dark)` (was a brighter translucent white)
- **HTML change on 22 business-level pages** via Python pass:
  - Old: `<a class="header-account-btn" title="Account dashboard" aria-label="Account dashboard">🏛️</a>` (icon-only)
  - New: `<a class="header-account-btn" title="Account dashboard"><span>🏛️</span><span>Account</span></a>` (icon + label)
- The button now matches the green-pill language used by Open buttons on biz cards, role pills, value pills, parent pills etc. Sign Out keeps its existing white-translucent chip — the two top-right buttons now read as distinct affordances rather than two of-the-same.
- **No SQL.**

---

## v0.5.170
- **Reorder the Learn vault sections to Planning → Strategy → Operations.** User: "In learn Change the order planning, then strategy then operations."
- Previous order (from v0.5.119 when the vault was built): Strategy → Operations → Planning.
- New order matches the rhythm of how the user runs their year: Planning sets the direction (annual + quarterly + check-ins), Strategy locks in the foundations (Core Values / Focus / Targets / Marketing / Leadership / Financials), Operations runs the cadence (Goals / Weekly Numbers / Meetings / Issues).
- **Implementation:** Python script reads `learning-vault.html`, identifies the three `<div class="vault-section">` blocks by their `<!-- ═══ X ═══ -->` markers, lifts them out, and writes them back in the new order. The three blocks themselves (cards, icons, links, descriptions) are byte-identical to before — only their position in the file changed.
- **Verification:** post-write grep shows the section labels in the new order at lines 128 / 172 / 253.
- **No SQL.**

---

## v0.5.169
- **Strip the redundant `← Home` back-link from hub-page headers.** User: "Can you see this home name looks different. I am ok with home going back to the green pills."
- **Why:** The Home tab returned to the bottom nav in v0.5.167 (as a green/teal pill icon+label). On hub pages — `planning.html`, `strategy.html`, `operations.html`, `learning-vault.html` — there was *also* a small white-translucent `← Home` link in the top-left of the navy `.site-header`, pointing to the same `business.html`. Two affordances for the same path, styled completely differently → looks like a bug.
- **Fix:** Python regex pass removes the `<a href="business.html" class="header-back">← Home</a>` element from those four files. The bottom-nav Home tab now stands alone as the "go to business overview" control.
- **Kept:** the deeper back links on worksheet / operations-tool pages (`← Strategy` on `core-values.html` / `core-focus.html` / `targets.html` / `marketing-strategy.html` / `leadership-team.html` / `financials.html`, `← Operations` on `goals.html` / `issues.html` / `scorecard.html` / `meeting.html` / `run-meeting.html`). Those point to a parent hub, NOT Home, so they're not redundant with the new Home tab.
- **Net effect:** the navy header on hub pages now reads exactly like `business.html`'s — just "Your Business Coach" on the left + the 🏛️ Account icon + Sign Out on the right. Consistent across the whole business-level surface.
- **No SQL.**

---

## v0.5.168
- **Sort the BUSINESS dropdown so the parent appears at the top.** User: "In the click down it should be showing the hq at the top as this is the parent one and should be in order."
- **Cause:** v0.5.166 filtered the dropdown to the parent-child group but didn't sort — so the raw `memberships` order leaked through. Alphabetical natural ordering puts "IAS General / IAS Life / IAS Outsourcing" before "IASHQ", which fights the visual hierarchy.
- **Fix in `business.html`:** compute a `groupParentId` once — it's `activeOrg.parent_organisation_id` when the active biz is itself a child, or `activeOrg.id` when the active biz IS the parent. Both `groupMems` filter and the new sort use the same value, so the parent appears at index 0 regardless of which biz you're looking from.
- The same code path also collapses the previous if/else split into a single filter (less duplication, easier to reason about).
- **Sort:** `groupParentId` first, then everything else by `localeCompare(name)`. Net order on IAS: **IASHQ → IAS General → IAS Life → IAS Outsourcing**.
- **No SQL.**

---

## v0.5.167
- **Restore `🏠 Home` to the bottom nav on every business-level page.** User: "I think the dashboard for each group needs a home tab. It was removed but I think it needs to go back."
- **Context:** Home was dropped in v0.5.147 because it felt redundant with `🏛️ Account` (both lived in the bottom nav and both pointed "up" semantically). In v0.5.165, Account moved out of the bottom nav entirely → up to a top-right icon button. With Account no longer in the bottom nav, Home no longer creates the overlap, and the user's mental model is back to "tap Home → business overview".
- **Patch on 22 business-level pages** via Python regex — insert `<a class="bottom-nav-item[ active]" href="business.html"><span class="bottom-nav-icon">🏠</span><span>Home</span></a>` as the first item inside `<nav class="bottom-nav">`. The `active` class is applied only on `business.html` (where you ARE on the home); on the other 21 pages Home is a regular tab and the existing active item per page (Strategy on strategy.html, Operations on goals.html / issues.html / etc.) is unchanged.
- **Net bottom nav on business-level pages:** **Home / Planning / Strategy / Operations / Learn** (5 items). Account stays as the top-right icon (v0.5.165) — separate.
- **Files patched (22, same set as v0.5.165):** `annual-sessions.html`, `business.html`, `core-focus.html`, `core-values.html`, `financials.html`, `goals.html`, `issues.html`, `leadership-team.html`, `learning-vault.html`, `marketing-strategy.html`, `meeting.html`, `operations.html`, `planning.html`, `quarterly-sessions.html`, `run-annual-session.html`, `run-meeting.html`, `run-quarterly-session.html`, `run-team-checkin.html`, `scorecard.html`, `strategy.html`, `targets.html`, `team-checkins.html`. Account-level pages (`index.html` / `account-users.html` / `account-setup.html`) unchanged — their bottom nav is the 3-tab Businesses / Users / Setup, which doesn't need a Home.
- **No SQL.**

---

## v0.5.166
- **Bugfix: scope the BUSINESS dropdown on parent / child dashboards to the parent-child group only.** User: "The iashq parent page has the wrong business connection as it is including all of the businesses. Should only include the parent and child pages for ias."
- **Cause:** when v0.5.163 added the `BUSINESS: [▾]` switcher in `business.html`, the option list was built straight from `memberships` — which is fetched without a `subscription_id` filter (intentional, so `active-org.js` can switch business + account from one place). On IASHQ this dumped every biz the user is admin of across every account (IAS HQ's 4 plus SARUBA's 3) into the dropdown.
- **Fix:** compute `groupMems` based on the active biz's relationship:
  - If `activeOrg.parent_organisation_id` is set → I'm a child. Include the parent + all siblings (every membership whose `organisation_id === parent_organisation_id` OR whose `organisations.parent_organisation_id === parent_organisation_id`).
  - Else → I'm a parent or standalone. Include self + my direct children (every membership whose `organisation_id === activeOrg.id` OR whose `organisations.parent_organisation_id === activeOrg.id`).
- The option rendering AND the change-handler both use `groupMems`. On IASHQ → dropdown shows IASHQ + IAS General + IAS Life + IAS Outsourcing. On IAS General → same 4 (parent + siblings). On a standalone biz → only itself.
- **Already correct:** the Child Businesses panel + financial rollup were filtered via `childrenInThisAccount` in v0.5.155 and never leaked. This bug was switcher-only.
- **No SQL.**

---

## v0.5.165
- **Move the Account control off the bottom nav on every business-level page.** User: "I just think the flow of working on the account is not as good when it is clicked on. Need an intentional reason to go to the account area."
- **New CSS class `.header-account-btn`** in `css/style.css`: white-translucent rounded button, 32×28, hosts the `🏛️` glyph, `margin-left: auto` so it sits flush right inside `.header-inner` and pulls the existing `.sign-out-btn` along with it.
- **HTML change on 22 business-level pages** (Python regex pass):
  - Inserted `<a href="index.html" class="header-account-btn" title="Account dashboard" aria-label="Account dashboard">🏛️</a>` immediately before the `<button id="signOutBtn">` element in the navy header
  - Removed the `<a class="bottom-nav-item" href="index.html">…Account…</a>` element from the bottom nav (handles both single-line and multi-line markup)
- **Files patched (22):** `annual-sessions.html`, `business.html`, `core-focus.html`, `core-values.html`, `financials.html`, `goals.html`, `issues.html`, `leadership-team.html`, `learning-vault.html`, `marketing-strategy.html`, `meeting.html`, `operations.html`, `planning.html`, `quarterly-sessions.html`, `run-annual-session.html`, `run-meeting.html`, `run-quarterly-session.html`, `run-team-checkin.html`, `scorecard.html`, `strategy.html`, `targets.html`, `team-checkins.html`. Script reports `injected button on 22 files, removed Account nav from 22 files`.
- **Net effect:** the bottom nav on business pages goes from 5 items (Planning / Strategy / Operations / Learn / Account) → **4 items** (Planning / Strategy / Operations / Learn). Working in a business feels in-flow. To leave, the user taps the small Account icon at the top-right — a more intentional gesture than tapping inside the bottom nav.
- **Account-level pages (`index.html` / `account-users.html` / `account-setup.html`) untouched** — they already have no Account button (they ARE account-level) and use their own 3-tab bottom nav.
- **No SQL.**

---

## v0.5.164
- **Removed redundant back/up nav from the parent + child business dashboard.** User: "I think the parent and child pages don't need back arrows and links at the top as they can use the tabs."
- **Dropped from `business.html`:**
  - The `<a href="index.html" class="header-back">← Account</a>` link in the navy header
  - The `<a href="index.html" class="switch-biz-link">Account dashboard ›</a>` link in the v0.5.163 `.biz-extra-action` row
  - The `<span id="activeBizName" class="biz-pill"></span>` from the header-left (left over from before the v0.5.141 sub-toolbar pill move and now redundant — the in-body `BUSINESS: [▾]` switcher is the identifier)
- **Improved:** wrapped the `↑ Part of <parent>` / `↓ N child businesses` context line in a `#bizContextRow` that's hidden by default. `renderBizContext` only shows it when there's actual parent/child info to display — so standalone businesses no longer have an empty action row taking up space.
- **Why it's safe:** the bottom-nav 🏛️ Account tab (added v0.5.142, kept across all business-level pages) gets you back to the account dashboard in one tap. No navigation path is lost.
- **Out of scope:** other business-level pages (strategy.html, operations.html, goals.html, issues.html, etc.) still have `← Home` / `← Strategy` / `← Operations` chains in their navy headers. They could get the same treatment in a follow-up — the user only flagged parent/child (business.html) pages this round.
- **No SQL.**

---

## v0.5.163
- **Business dashboard gets a `BUSINESS: [▾]` switcher row mirroring `ACCOUNT: [▾]` on the account tabs.** User: "Yes to 1 [BUSINESS: switcher row]. I just like consistency."
- **Removed from `business.html`:**
  - `.greeting-row` block (big bold biz name + date + Switch business link)
  - `.greeting-name` / `.greeting-date` / old `.switch-biz-link` CSS rules
  - `document.getElementById('todayDate').textContent = …` JS that fed the (now removed) date span
  - The bizName render block (`bizNameEl.textContent = activeRow.organisations.name;` + the old switchEl wireup)
- **Added to `business.html`:**
  - `<div class="biz-switcher" id="bizSwitcherRow"><span class="switcher-label">Business:</span><select id="businessSwitcher" class="switcher-select"></select></div>` at the top of `.container`, before the standard/parent-mode panels
  - `.biz-switcher` / `.switcher-label` / `.switcher-select` CSS rules — copy of `.acct-switcher` / `.switcher-label` / `.switcher-select` from the account tabs (same padding 16/14, border-bottom, `flex:1; max-width:100%` on the dropdown so it stretches identically)
  - A `.biz-extra-action` flex row below the switcher with two children: `#bizContext` (the `↑ Part of <parent>` / `↓ N child businesses` context — was inline in greeting-row before) on the left, and a new `Account dashboard ›` link on the right
  - `.biz-switcher-bar { display: none !important; }` to hide the v0.5.141 sub-toolbar pill from `js/active-org.js` — the in-body switcher now does that job
  - JS to populate the `<select>` from `memberships`, mark the active option, and reload on change via `activeOrg.set(newId, m.organisations.name)`
- **Effect:** when you tap into a parent (IASHQ) or a child (IAS General / IAS Life / IAS Outsourcing), the top of the page reads `BUSINESS: [<Name> ▾]` in exactly the same visual layout as `ACCOUNT: [<Name> ▾]` on the Businesses / Users / Setup tabs. The biz switcher is interactive — pick a different business and the page reloads to that one.
- **No SQL.**
- **Out of scope:** other business-level pages (strategy.html, operations.html, goals.html, etc.) still rely on the v0.5.141 sub-toolbar pill from `js/active-org.js`. They could get the same in-body BUSINESS switcher in a follow-up, but business.html is where the user lands first and is the priority for consistency.

---

## v0.5.162
- **Match child-card styling on parent dashboard to biz-card styling on account dashboard.** User: "The sections in parent and child fix the look of the name of business to match the account."
- The `.child-card` rules in `business.html` parent-mode were close to but not identical to `.biz-card` in `index.html`. The biz name in child cards appeared smaller (0.95rem vs 1.05rem) and the cards had a tighter corner-radius and padding.
- Updated to mirror the account dashboard:
  - `border-radius: 10px → 12px`
  - `padding: 12px 14px → 14px 16px`
  - `child-card-head { gap: 8px → 10px; flex-wrap: wrap; }`
  - `child-card-name { font-size: 0.95rem → 1.05rem; }`
  - `child-card-arrow { font-size: 1.1rem → 1.15rem; }`
  - `child-card-open { font-size: 0.7rem → 0.78rem; }`
  - hover transition `box-shadow .12s → .15s` to match
  - `position: relative` added so a future indent marker (↳ pseudo-element) can hang off the left
- Added a `@media (max-width: 600px)` block matching the account dashboard: `.child-card-name { flex-basis: 100%; font-size: 1rem; }` so the name takes its own row on phones and the open/arrow row drops below.
- **No SQL.**

---

## v0.5.161
- **Match the switcher dropdown width across all three account-level tabs.** User: "This version still is different on first page" (after v0.5.160 moved the New-Client button to its own row).
- Root cause: `.switcher-select` on `index.html` had `min-width: 180px` only. On `account-users.html` + `account-setup.html` (where I added the switcher in v0.5.158) the rule was `min-width: 180px; flex: 1; max-width: 100%;`. Result: Businesses dropdown stayed at 180px with empty space; Users/Setup stretched full-width.
- Fix: added the missing `flex: 1; max-width: 100%;` declarations to `index.html`'s `.switcher-select` rule. The `Account: [dropdown ▾]` row now renders pixel-identically on all three tabs.
- **No SQL.**

---

## v0.5.160
- **Make the `Account:` row identical across the three account-level tabs.** User: "Account : is different on first page to the other 2."
- The `+ New client account` button was inline with the switcher on `index.html` (`<div class="acct-switcher">…<button class="switcher-btn">+ New client account</button></div>`). The button:
  1. squeezed the switcher dropdown narrower than the same dropdown on Users/Setup (`.switcher-select` is `flex: 1`)
  2. made the switcher row visibly taller (button wraps under on mobile, makes a 2-line row)
- Moved the button into its own row in a new `.acct-extra-action` wrapper directly under the switcher, right-aligned (`display: flex; justify-content: flex-end; padding: 0 16px 4px;`). Removed the obsolete `margin-left: auto` from `.switcher-btn`.
- The `Account: [dropdown ▾]` row now renders identically on Businesses / Users / Setup. The create-account button is still on Businesses only (deliberate — see v0.5.159) but no longer interferes with the switcher's layout.
- **No SQL.**

---

## v0.5.159
- **Audit + cleanup of the three account-level tabs.** User: "Audit the account three tabs for consistency and ensure that all of the links work."
- **Method:** systematic grep across `index.html` / `account-users.html` / `account-setup.html` for: head meta + scripts, site-header structure, account switcher block, bottom nav (active state), footer version label, auth check, membership gate, sign-out wireup, `<a href>` links, `getElementById` references vs declared IDs (scripted via Python).
- **Bug fixed:** `index.html` was missing the `membership_status = 'active'` gate. Users with an inactive subscription could load Businesses but get redirected from Users / Setup → caller sees inconsistent gating. Added the same gate (queries `users.membership_status`, redirects to `inactive.html` if not active).
- **Page-header parity:** `index.html` now has the same `.page-header` block as the other two — title "💼 Business Management" + sub describing the page. Page-header CSS (`.page-header` / `.page-title` / `.page-sub`) added to its `<style>`. Section title under it changes from "💼 Your Businesses" → "Your Businesses" (briefcase moves up to the page-header so the emoji doesn't appear twice). The `.section-blurb` rule remains in CSS but is no longer used on this page (page-sub serves the purpose).
- **Header markup cleanup:** removed `<span id="activeBizName" class="biz-pill"></span>` from the site-header on `account-users.html` and `account-setup.html`. The span was hidden via `.biz-switcher-bar { display: none !important; }` but shouldn't be in the markup at all on account-level pages — a business pill is meaningless there.
- **Resume Planning Session pill parity:** `js/active-session.js` was loaded on `index.html` only. Added to both other account-level pages so the floating "Resume Planning Session" pill appears uniformly.
- **Audit results that were already correct (no change needed):**
  - Bottom nav: all three tabs link to the right URLs (`index.html` / `account-users.html` / `account-setup.html`) and apply `.active` to the right item per page.
  - Switcher behaviour: change handler reloads correctly on all three; `allSubs` populated; selected option matches the current sub.
  - Sign-out: present and wired on all three.
  - Element-ID integrity: 0 broken `getElementById` references on any of the three pages (Python-scripted check across all `getElementById('…')` strings vs `id="…"` declarations).
  - Footers: all four files (business.html + the 3 account-level pages) now show v0.5.159.
- **Deliberate non-fix:** the `+ New client account` button stays Businesses-only. Each tab has its own primary create action (Businesses = + New Business, Users = + Invite User, Setup = no create — it's an edit page). Replicating the New-Account button across all three would duplicate the modal and JS without UX benefit.
- **No SQL.**

---

## v0.5.158
- **Consistent chrome across the three account-level tabs.** User: "The business setup needs to be consistent I think over the 3 pages."
- Three things were inconsistent between Businesses (`index.html`), Users (`account-users.html`), and Setup (`account-setup.html`):
  1. The `ACCOUNT: [dropdown]` switcher was only on Businesses. Users + Setup had no way to switch accounts without going back to Businesses first.
  2. Users + Setup showed the `🏢 [Biz Name]` pill (e.g., "IAS General") in the sub-toolbar that `js/active-org.js` injects — but that's a business-level indicator and meaningless on an account-level page.
  3. Users + Setup footers were stuck on `v0.5.153` (the version they were created at) — never got bumped because they weren't on the version-bump checklist.
- **Switcher added to `account-users.html` + `account-setup.html`:**
  - HTML: `<div class="acct-switcher"><span class="switcher-label">Account:</span><select id="accountSwitcher" class="switcher-select"></select></div>` placed at the top of the container, above the `.page-header`.
  - CSS: same rules as `index.html` for `.acct-switcher`, `.switcher-label`, `.switcher-select`.
  - JS: `loadSub` / `loadAll` now also fetches every subscription the user owns, stashes them in `allSubs`, and populates the `<select>`. Change handler sets the active sub via `window.activeOrg.setSubscription`, clears the org cache, and reloads the current page (so you stay on Users / Setup but viewing the new account).
  - The `+ New client account` button stays only on Businesses — creating a new account is a one-off admin action that lives there. No need to duplicate the modal.
- **Biz pill hidden on all three pages:** added `.biz-switcher-bar { display: none !important; }` to each. The pill is still useful on business-level pages; on account-level pages it just confused.
- **Footers bumped + checklist updated:** the project's "files to keep in sync per version" rule in CLAUDE.md goes from 5 → 7. Added `account-users.html` and `account-setup.html`, with a note about the v0.5.153 → v0.5.158 drift they had.
- **No SQL.**

---

## v0.5.157
- **Block deleting a parent business while it still has children.** User: "I think the parent needs to be set up not to deleted unless all children are removed. Appreciate feedback on this."
- **Why:** the FK on `organisations.parent_organisation_id` was `ON DELETE SET NULL` (v0.5.145), which meant deleting a parent silently orphaned its children — they'd become standalones, inheritance would break without warning, and the user usually wouldn't realise. High-blast-radius operation deserves a safety gate.
- **(1) SQL — replaces `delete_business` RPC** with a new version that COUNT(*)s rows in `organisations` where `parent_organisation_id = business_id`. If > 0, raises:
  ```
  Cannot delete this business while it is the parent of N child business(es).
  Unlink or delete the children first.
  ```
  All other checks (admin role + subscription ownership) unchanged.
- **(2) UI — `index.html`** renders the `⋮ → Delete` button with `disabled` + a `title="Has children — unlink them first"` tooltip when `hasChildren` is true for that row. Label changes to "Delete (has children)". Defence in depth — the user gets feedback before they hit the disabled button.
- **CSS:** added `.actions-menu button:disabled { color:#b8b8b8; cursor:not-allowed; font-style:italic; }` so the disabled state reads clearly in the dropdown.
- **Unlink flow (already in place since v0.5.149/150):** set the child's Parent dropdown to "— None —" — one tap per child via the inline picker. Once the last child is unlinked, the Delete option re-enables and the RPC will allow it.
- **Migration file:** `supabase/v0.5.157-delta.sql` (full `CREATE OR REPLACE FUNCTION delete_business` + `GRANT EXECUTE` + `NOTIFY pgrst`).

---

## v0.5.156
- **Remove duplicate account name on the Businesses tab.** User: "The name of the business is showing twice on account page."
- `index.html` was rendering the account name in two places:
  1. The `<select id="accountSwitcher">` dropdown (live, interactive, lets you switch between accounts) — e.g., `[Insurance Advisory Service NSW Pty Ltd ▾]`
  2. A large `<h1 class="acct-title" id="accountName">🏢 Insurance Advisory Service NSW Pty Ltd</h1>` immediately below it
- Dropped the `<h1>` block + the entire `.acct-header` `<div>` wrapper.
- Dropped the `renderAccountHeader()` JS function (no longer has a target element).
- Dropped the `renderAccountHeader()` call from `refresh()`.
- The switcher dropdown is now the sole account-name indicator and remains interactive.
- `account-users.html` and `account-setup.html` are unchanged — neither had the duplication.

---

## v0.5.155
- **Parent business dashboard becomes a holding-co rollup view.** User: "The parents dashboard needs to be more focused on a summary of entire businesses."
- **Detection:** in `business.html` `init()`, after the active row is resolved, scan `memberships` for any row whose `organisations.parent_organisation_id === activeOrg.id`. If at least one, render parent-mode; otherwise render the existing standard dashboard.
- **Standard own-business panels wrapped in `<div id="standardMode">`** (Stat tiles / 1-Year Goal / Core Values / Meeting button / This Week / This Quarter). Hidden when parent-mode is on.
- **New `<div id="parentMode">` with four panels:**
  1. **Group Strategy** — the parent's own targets row, three labels: 10-Year Vision, 3-Year Outlook, 12-Month Goal. 3-Year and 12-Month combine the worksheet's date/revenue/profit/desc/goals fields into a single block.
  2. **This Quarter's Priorities** — the parent's `rocks` for the current quarter, with status pills (same `STATUS_LABEL` / `STATUS_PILL` palette as the standard dashboard).
  3. **Group Financials** — 2×2 grid: `1-Year Revenue Target` (sum of parsed numbers from each org's `targets.one_year_revenue` — strips `$`/`,`/etc. with `parseFloat`), `Last 12mo Revenue`, `Last 12mo Expenses`, `Last 12mo Profit` (revenue − expenses). Sourced from `financial_periods` for parent + all children, filtered to the 12 most-recent `YYYY-MM-01` period dates (exclusive of current month).
  4. **Child Businesses** — tappable card per child showing **Open Issues**, **Goals on track (X of N)**, **Next meeting**. Tapping a card sets the active org to that child and reloads → user lands on the child's standard dashboard.
- **New JS function `renderParentMode(parentOrgId, children)`** fires 7 parallel Supabase queries (`targets` ×2, `rocks` ×2, `financial_periods`, `issues`, `meetings`) and renders the panels.
- **CSS additions:** `.group-target-row` / `.group-target-label` / `.group-target-value`, `.financial-grid` / `.financial-cell` / `.financial-label` / `.financial-value` / `.financial-sub`, `.child-card` / `.child-card-head` / `.child-card-arrow` / `.child-card-name` / `.child-card-open` / `.child-card-mini`.
- **Standalone businesses + child businesses (those with `parent_organisation_id` set but no children of their own) are unchanged** — they still get the standard own-business dashboard.
- **No SQL change.**
- **Known limitation:** the rollup only includes child businesses the current user is a member of (RLS). For an admin of a parent who isn't a member of any child, the rollup would silently miss those children. In practice (e.g., IAS admin Cath is admin of all 4) this isn't an issue; could be addressed later with a "parent admins can read child strategy" RLS policy.

---

## v0.5.154
- **Move the "Business Management" subtitle on `index.html` to sit under the section heading instead of the account header.** User: "The wording for business management should be under the heading of businesses."
- With long account names ("Insurance Advisory Service NSW Pty Ltd" wraps to two lines on phones), having a subtitle paragraph between the bold account name and the "💼 Your Businesses" section header was crowded and read like duplicated headings.
- Changes:
  - Removed the `<p class="acct-sub">` paragraph from `.acct-header`. Header is now just the account name (`<h1 class="acct-title" id="accountName">🏢 [Name]</h1>`).
  - Added a `.section-blurb` line right under the "Your Businesses" section title (still in the section-head visual block via negative top-margin). Copy reads "Add, rename, delete businesses and wire up the parent/child structure of your account."
  - New CSS: `.section-blurb { font-size: 0.78rem; color: #888; line-height: 1.5; margin: -4px 0 12px; }`.
- `account-users.html` and `account-setup.html` are unchanged — their page-headers double as the section heading (no competing title below), so they don't have the duplication issue.

---

## v0.5.153
- **Account dashboard split into three tabbed pages.** User: "The accounts area needs to have 3 different areas. Business management, user management and setup of of accounts name (invoicing information)" + "Tabs at the bottom like the other pages are structured."
- **New bottom nav at the account level** (`index.html` / `account-users.html` / `account-setup.html`):
  ```
  💼 Businesses  👥 Users  ⚙️ Setup
  ```
  Each tab is `active` on its own page. Replaces the single 🏛️ Account tab from v0.5.146.
- **`index.html` becomes the Businesses page.** Strips:
  - The "Your Team" section (HTML + section markup)
  - The user-edit / invite / remove-member modals (3 modals)
  - `renderUsers()`, `openUserEditModal()`, `saveUserEdit()`, `populateInviteBizList()`, invite + remove JS blocks (~210 lines)
  - The team-rows fetch inside `loadAll()` — only `subscriptions` + `team_members` (own memberships) are loaded now
  - `teamRows` + `teamGroups` state vars
  - The rename-account modal + JS (moved to Setup)
  - The "Rename account ›" inline link in the account header
  - Subtitle copy updated to read "💼 Business Management — add, rename, delete businesses and wire up the parent/child structure of your account."
- **`account-users.html` (new).** Self-contained team-management page:
  - Same `.site-header` + biz pill chrome (from `js/active-org.js`)
  - "👥 User Management" page header + section title "Members (count)" + Invite User
  - Same `.user-card` UI with "Tap to edit access ›" hint
  - Same Edit-team-member modal (display name + per-business role pickers, picker options `— No access — / Member / Coach / Admin`)
  - Same Invite User modal + Remove Member confirm modal
  - Same save handler: `remove_team_member` RPC for no-access, direct UPDATE for role changes on existing rows, `invite_team_member` RPC for new access when email is on file
  - Independent data fetch: subs → my memberships in active sub → team_members in admin orgs
- **`account-setup.html` (new).** Auto-saving form for the account / invoicing details:
  - Fields: **Account name** (required), **Billing email**, **Billing address** (textarea), **Tax ID (ABN / VAT / company number)**
  - 400ms debounced auto-save on input + immediate save on blur. Status label below the card flips between "Changes save automatically.", "Saving…", "Saved ✓", or "Could not save: …".
  - Direct `UPDATE subscriptions` against the active subscription (RLS via `owner_user_id = auth.uid()` — unchanged).
  - Keeps `activeOrg.setSubscription(sub.id, name)` in sync after a name change so the cached account label updates across other pages.
- **Both new pages have a `v0.5.153` footer label** and register the service worker for PWA install consistency.
- **No SQL change** — the `subscriptions.billing_email`, `billing_address`, `billing_tax_id` columns already shipped in `v0.5.152-delta.sql`, along with the `team_members` RLS hotfix that unblocks the Edit-team-member save.

---

## v0.5.152
- **SQL-only release.** Hotfix the broken save on the v0.5.151 Edit-team-member modal, plus add billing fields for the upcoming Account Setup page.
- **(1) Hotfix — RLS policy on `team_members`.** User report: "Could not save: permission denied for table users". The error came from the long-standing `"invited user accepts own invite"` policy, whose `USING` clause SELECTed `email` from `auth.users` — which the `authenticated` role doesn't have permission to read in current Supabase. The previous code paths (single-row UPDATEs on team_members) seem to have dodged that policy evaluation; the multi-row `.in('id', memberIds)` UPDATE introduced in v0.5.151 hit it.
  ```sql
  DROP POLICY IF EXISTS "invited user accepts own invite" ON public.team_members;
  CREATE POLICY "invited user accepts own invite" ON public.team_members
    FOR UPDATE
    USING (
      invited_email IS NOT NULL
      AND lower(invited_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    )
    WITH CHECK (user_id = auth.uid() AND status = 'active');
  ```
  Same semantics — a logged-in user can claim a pending invite that matches their email — but now reads the email from the JWT claim instead of querying `auth.users`. No table access needed.
- **(2) Billing fields on `subscriptions`.** ADD COLUMN IF NOT EXISTS billing_email, billing_address, billing_tax_id (all nullable text). Used by the upcoming 3-tab Account Setup view in v0.5.153. Owner-owned by the existing "owner updates own subscription" policy (no RLS change needed).
- **No app code change in this release** — version bump just keeps SW/footer aligned with the migration file. Both fixes shipped via `supabase/v0.5.152-delta.sql`.

---

## v0.5.151
- **User cards on the account dashboard become clickable** with a new "Edit team member" modal. User: "I can't click into it. There needs more options the user as they can be admin some or all."
- **`renderUsers()` changes:**
  - `.user-card` markup gets `data-user-key`, `role="button"`, `tabindex="0"`, and a small `Tap to edit access ›` hint at the bottom.
  - `.user-card { cursor: pointer; transition: border .12s, box-shadow .12s; }` plus a hover state matching the biz cards.
  - After render, every group object (the `Map` keyed by `u:user_id` or `e:invited_email`) is stashed in a new `teamGroups` state map so the click handler can look up the right group.
  - Click handler ignores clicks on inline buttons (the existing Remove button still works).
- **New modal `#userEditModal`:** avatar + name + email at the top, a Display name input, then a per-business "Access" list. For every business the **current user** is admin of in the active account, one row: business name + a 4-option role picker (`— No access — / Member / Coach / Admin`).
- **Save handler `saveUserEdit()`:**
  - Each picker stores its original value in `data-orig`; only changed pickers are committed.
  - `no_access` on a row that exists → `remove_team_member(member_id)` RPC (soft-removes, guards against last admin).
  - Role change on an existing row → direct `UPDATE team_members SET role = … WHERE id = member_id`.
  - New role on a missing row → `invite_team_member(business_id, email, role)` RPC, but only when an email is available (see caveat).
  - Display name change → bulk `UPDATE team_members SET display_name = … WHERE id IN (…)` across the user's existing rows.
  - All ops fire in parallel via `Promise.all`; if any fail, the first error surfaces in the modal and the page doesn't reload.
- **Caveat — email availability:** the v0.5.x schema clears `team_members.invited_email` when a user signs up (via the `link_pending_invites` trigger on `auth.users`). That means for already-signed-up users we don't have an email at hand, and the `invite_team_member` RPC needs one. The modal handles this by:
  - Disabling Member/Coach/Admin options on no-access rows when no email is on file
  - Showing an inline hint: *"No email on file — use Invite User to add"*
  - Pending invites and the current user still have full add capability.
- **Follow-up worth doing:** a small `SECURITY DEFINER` RPC `get_email_for_team_admin(target_user_id)` that returns the email for a user the caller is admin/coach of. Would let the modal add already-signed-up users to new businesses in one tap. Deferred.

---

## v0.5.150
- **Two fixes on the account dashboard biz table.**
- **(1) Mobile layout** — names like "IAS General" / "IAS Outsourcing" were wrapping mid-word on phones because the `biz-card-head` row was crammed with: name + Parent pill + admin pill + reorder buttons + Open + ⋮. With `flex: 1` on the name and `flex-wrap: wrap` on the parent, the name shrank instead of wrapping the OTHER items.
  - Added `@media (max-width: 600px)` rule that forces `.biz-name { flex-basis: 100% }` so the name always claims its own line. The pills, reorder, Open, ⋮ wrap to a second row.
  - Pills shrink slightly (0.58rem font, 2×7 padding) and Open button (0.74rem, 6×10) for tighter mobile fit.
  - Child indent tightened (margin-left 28 → 22, marker left -22 → -18, top 18 → 16) to free up inner-content width.
- **(2) "Add child" picker.** User: "There needs to be a clearer option to pick a child I think." Previously each row only had a "Parent" picker (which sets *this* row's parent). To make IASHQ a parent you had to go to each child and configure it from there — top-down thinking was missing.
  - Each row's parent-control logic now branches by state:
    - **Standalone (no parent, no children)** → `Parent: [— None — ▾]` + `Add child: [Pick a business… ▾]`. Either direction works.
    - **Child (has a parent set)** → `Parent: [<current> ▾]` only. Can change or clear.
    - **Parent (has children)** → `Children: <names>` read-only chip-list. No Parent picker (depth-1 lock).
  - New `addChildCandidates` pool: admin rows in the account that are themselves standalone (no parent of their own AND no children of their own). Picking one fires `UPDATE organisations SET parent_organisation_id = <current row id> WHERE id = <picked>` and re-renders.
  - Replaced the previous "Has children — can't have a parent" hint with a list of the children, which is more informative.
- **No SQL change.**

---

## v0.5.149
- **Account dashboard becomes a compact admin table.** User: "I don't understand why it can't just be more of an admin dashboard where I can reallocate in a table … I don't need the revenue and open issues etc in the account area."
- **Removed from `index.html`:**
  - Stat tiles row (4 cards: Businesses count, Users count, Open Issues, Goals On Track)
  - `renderStats()` function and its `refresh()` call
  - Snapshot grid inside each biz card (Revenue, Quarter Goals, Open Issues, Next Meeting)
  - `snapshotByOrg` state map
  - Four parallel data-fetch queries (`targets`, `rocks`, `issues`, `meetings`) that only existed to power the above — dashboard load is faster as a result
  - v0.5.148 "Structure" modal + button + all of `refreshStructureButton` / `openStructureModal` / `saveStructure` JS (replaced by inline pickers)
- **New compact biz row markup:** each `.biz-card` is now just the head row (Name + Parent pill + Role pill + reorder + Open + ⋮) plus, for admins, an inline `Parent: [— None — ▾]` dropdown directly under it. Padding tightened (14×16) and the `is-child` indent marker repositioned (top: 18px).
- **Inline parent picker behaviour:**
  - Changing a row's parent fires an `UPDATE organisations SET parent_organisation_id = …` immediately.
  - On success, local `myMemberships` state is mutated and `renderBusinesses()` is re-called — so the tree visually reshuffles AND every other row's candidate list refreshes (since the candidate pool is "top-level admin businesses ≠ self").
  - On error, the picker re-snaps to its previous value and shows an alert.
  - Header switcher cache (`coach4u_biz_list_cache`) busted on every save so the pill dropdown picks up the new parent assignments.
- **Depth-1 still enforced** — only top-level rows are offered as candidates. A row that itself has children shows *"Has children — can't have a parent"* in muted italics instead of a picker (since making it a child would create a depth-2 chain via its existing children).
- **Tree indent kept** for visual hierarchy — parents at top, children indented 28px under them with a teal left border + `↳` marker. Setting/clearing the parent inline causes the row to slide in/out of the indented group on re-render.
- **No SQL change.**

---

## v0.5.148
- **Move parent/child allocation to the account dashboard.** User feedback: "It needs to be easier and done in accounts area. I think allocation is accounts level."
- **Why:** the v0.5.145 design put a "Parent business" picker inside each business's dashboard (`business.html`). Setting up an IAS-style tree (1 parent + 3 children) meant tapping into 4 separate businesses and being careful not to invert the direction (the picker is "this biz's parent", not "this biz's children"). Several users got it wrong on the first try.
- **What's new on `index.html`:**
  - A small `🏛️ Structure` button next to `+ New Business` in the businesses-section header. Hidden unless the user is admin of ≥2 businesses in the active account (no point picking a parent if there's only one biz).
  - Clicking opens a new `#structureModal` listing every admin-controlled business in the account. Each row: `[Business name]  Parent: [— None — / IASHQ / IAS Life / … ▾]`. Pickers exclude rows that would create a cycle (a biz can't pick one of its own current children as its parent).
  - One Save button at the bottom commits every changed parent in parallel via `Promise.all` on `organisations.update`. After save: bust the header switcher cache, reload the dashboard so the tree renders.
  - Client-side guard enforces depth = 1 — if A picks B as parent AND B itself has a parent (per the modal's current state), Save shows an inline error and refuses.
- **`business.html` cleanup:**
  - Removed the entire "Business Structure" panel (the dropdown + children chips).
  - Removed the `wireBusinessStructure(activeRow, memberships)` JS that powered it.
  - Kept `renderBizContext` and the small `↑ Part of IASHQ` / `↓ N children` line under the greeting — read-only "where am I in the tree" indicator.
- **No SQL change** — schema from v0.5.145 unchanged. This is purely a UX relocation.

---

## v0.5.147
- **Remove `🏠 Home` from the business-level bottom nav.** User feedback: "I think now home and account are the same?" — `🏠 Home` (→ `business.html`) and `🏛️ Account` (→ `index.html`) felt synonymous even though they pointed at different pages.
- **Bottom nav on business-level pages is now 5 items:** Planning / Strategy / Operations / Learn / Account.
- **Reaching `business.html` after the change:**
  - From a hub (Strategy / Operations / Planning / Learn): unchanged — 1 tap via the navy-header `← Home` link.
  - From a worksheet (Core Values / Targets / etc.) or operations tool (Goals / Issues / Scorecard / Meeting): 2 taps via the existing header chain (`← Strategy` then `← Home`, or `← Operations` then `← Home`). Previously 1 tap via the now-removed Home tab.
- **What stays:** the navy-header back-link chain on every page; the biz pill + switcher in the sub-toolbar; the Account tab → `index.html` → tap into any business.
- **Files patched (22, business-level):** `annual-sessions.html`, `business.html`, `core-focus.html`, `core-values.html`, `financials.html`, `goals.html`, `issues.html`, `leadership-team.html`, `learning-vault.html`, `marketing-strategy.html`, `meeting.html`, `operations.html`, `planning.html`, `quarterly-sessions.html`, `run-annual-session.html`, `run-meeting.html`, `run-quarterly-session.html`, `run-team-checkin.html`, `scorecard.html`, `strategy.html`, `targets.html`, `team-checkins.html`. Done via Python regex over both single-line and multi-line `Home` markup variants.
- **Side effect:** on `business.html` itself, no bottom-nav item now matches the page → no `.active` highlight there. That's intentional — you're on the home, you don't need a "home" highlight, and adding one would just re-create the redundancy we removed.
- **No SQL.**

---

## v0.5.146
- **Strip the bottom nav at the account level to a single Account item.** User: "the IAS dashboard should have no reference to strategy and operations or Learn. They should all happen at the next level down."
- The old 6-item nav at the account level was misleading — Home, Planning, Strategy, Operations, Learn all linked to **business-level** pages that require an active business. From the account dashboard (where you haven't picked a business yet) they were either confusing or took you somewhere arbitrary.
- Updated files (4): `index.html`, `account-strategy.html`, `account-operations.html`, `account-planning.html`. Each now has:
  ```html
  <nav class="bottom-nav">
    <a class="bottom-nav-item active" href="index.html" title="Account dashboard">
      <span class="bottom-nav-icon">🏛️</span><span>Account</span>
    </a>
  </nav>
  ```
- **Business-level pages unchanged** — they still have the full 6-item nav (Home / Planning / Strategy / Operations / Learn / Account) since all those sections live at the business level.
- **Side effect:** `account-strategy.html` / `account-operations.html` / `account-planning.html` are now only reachable via legacy entry-points from `annual-sessions.html` / `quarterly-sessions.html` / `team-checkins.html`. To revisit in a follow-up — likely either delete them or surface from a "Cross-business views" body section on `index.html`.

---

## v0.5.145
- **Phase 1 of parent / child business relationships.** A business can now link to a parent (e.g., IASHQ → IAS General / IAS Life / IAS Outsourcing). Flat tree, single parent per child.
- **Data model:** new nullable column `organisations.parent_organisation_id` (FK self-referencing organisations, ON DELETE SET NULL), with a `CHECK (id <> parent_organisation_id)` constraint and an index on the FK. Depth-1 is enforced in the UI (parent picker only lists businesses that don't themselves have a parent) — no DB trigger.
- **RLS additions** (in v0.5.145-delta.sql, additive — existing policies still cover own-org reads):
  - `children read parent core_values` — children can `SELECT` from `core_values` rows whose `organisation_id` equals their own `parent_organisation_id`
  - `children read parent core_focus` — same pattern (Phase 2 prep)
  - `children read parent targets` — same pattern (Phase 3 prep)
  - Writes are unchanged — a child still can't write the parent's strategy tables.
- **Account dashboard (`index.html`):** the flat list of businesses becomes a tree.
  - Parents render at top with a navy "Parent" pill.
  - Children indented 28px, teal left border, `↳` prefix marker. Same snapshot grid; only the framing changes.
  - Standalones (no parent, no children) sit alongside parents at top level.
  - Reorder arrows now only appear on top-level rows (children inherit their parent's slot in the order). `moveBiz()` operates on the top-level subset only.
- **Business dashboard (`business.html`):**
  - New admin-only "Business Structure" panel after the Core Values panel — `Parent business: [— None —]` dropdown listing only valid candidates (top-level siblings in the same account, excluding any that are already this biz's children). Save persists the FK to the row immediately and reloads.
  - Children of the active biz render as clickable teal chips (`↳ IAS General`) — tap to switch context to that child.
  - New header-context row under the greeting: `↑ Part of IASHQ` if this biz has a parent (click → switches context); `↓ N child businesses` if this biz has children. Both visible to every role (admin/coach/member).
  - Memberships query extended to include `subscription_id` + `parent_organisation_id`.
- **Core Values inheritance (`core-values.html`):** first inheritable section end-to-end.
  - Load logic:
    1. Try child's own `core_values` row first
    2. If present → `mode = 'local'`, render editable
    3. If absent AND `parent_organisation_id` is set → fetch parent's row, render values read-only, `mode = 'inherited'`
    4. If absent AND no parent → empty local
  - Banner above the worksheet:
    - Inherited: teal background, `Inherited from IASHQ` + `[Override locally]` button
    - Overridden: amber background, `Overridden locally — not following IASHQ` + `[Revert to parent]` button
    - No parent at all: banner hidden, page behaves as before
  - **Override locally:** upserts the currently-displayed (inherited) values into the child's `core_values` row, switches mode → editable.
  - **Revert to parent:** confirms, then DELETEs the child's `core_values` row, re-loads as inherited.
  - Inputs are disabled (greyed) in inherited mode so the user can't type into what's effectively a parent's data.
- **Out of scope (Phase 2 + 3):** Core Focus, 10-Year Vision, Targets. RLS already in place; UI wiring comes next.
- **Verification SQL** (after running the delta):
  ```
  SELECT column_name, data_type FROM information_schema.columns
  WHERE table_name='organisations' AND column_name='parent_organisation_id';
  -- should return 1 row: parent_organisation_id | uuid
  ```

---

## v0.5.144
- **Account nav item now appears on `index.html` and the account hubs.** User reported after v0.5.142 ship: "But if this is the case where is the account area located. Because it's not down bottom." They were looking for the new button on the account dashboard itself, but v0.5.142 had skipped that page on the (wrong) theory that a self-link was redundant.
- **What's actually wrong with skipping it:** the bottom nav becomes inconsistent — 5 items on account-level pages vs 6 on business-level pages — so the change is invisible from the page the user naturally checks.
- **Fix:** added the 6th `🏛️ Account` item to four more pages: `index.html` (marked `.active` since this is the account dashboard), `account-strategy.html`, `account-operations.html`, `account-planning.html`. The carousel pages (`account-*.html`) use the `.screen-toolbar` pattern instead of `bottom-nav`, so they remain unaffected.
- **No SQL, no functional change** beyond nav layout consistency.

---

## v0.5.143
- **Version label on account dashboard was stuck on v0.5.89.** User reported only seeing v0.5.89 on the home/account dashboard even after the v0.5.142 deploy. Cause: the project's version-bump checklist only listed `business.html`'s footer label — `index.html`'s footer label was a separate hardcoded `<p>v0.5.89</p>` that hadn't been touched since the file was created. ~54 versions of drift.
- **Fixed:** `index.html` footer now reads `v0.5.143`.
- **Process fix:** CLAUDE.md's "## Git Workflow" section now lists **five** files that must stay in sync per bump (was four). Added `index.html` to the list with a note explaining when it was added.
- **No functional change** — the Account nav item and everything else from v0.5.142 was already live. This was a label-only bug.

---

## v0.5.142
- **Account item added to bottom nav.** User: "the flow needs to be easier to get back to the main accounts page. can we add this as a box next to learn?"
- **What changed:** the bottom nav on every business-level page goes from 5 items to 6 — the new item sits to the right of "Learn":
  ```html
  <a class="bottom-nav-item" href="index.html" title="Back to your account dashboard">
    <span class="bottom-nav-icon">&#x1F3DB;&#xFE0F;</span>
    <span>Account</span>
  </a>
  ```
- **Why:** previously the only one-tap return-to-account-dashboard path was through the navy header `← Back` link, which goes to `business.html` (not `index.html`). For a multi-business account owner, getting back to the dashboard meant either Home → Home (two steps) or remembering to use the browser history. The new `🏛️ Account` slot puts it in the same place as every other navigation pillar.
- **Files patched (22):** `business.html`, `strategy.html`, `operations.html`, `planning.html`, `learning-vault.html`, `core-values.html`, `core-focus.html`, `targets.html`, `marketing-strategy.html`, `leadership-team.html`, `financials.html`, `scorecard.html`, `goals.html`, `meeting.html`, `run-meeting.html`, `issues.html`, `annual-sessions.html`, `run-annual-session.html`, `quarterly-sessions.html`, `run-quarterly-session.html`, `team-checkins.html`, `run-team-checkin.html`.
- **Not patched (correct):** `index.html` (the destination), `account-strategy.html`, `account-operations.html`, `account-planning.html` (account-level hubs — already at the top of the tree). The `account-*` carousel pages use the `.screen-toolbar` pattern rather than the bottom nav, so they're unaffected.
- **CLAUDE.md rule updated:** the nav-order convention now reads "Home / Planning / Strategy / Operations / Learn / Account".
- **No SQL.**

---

## v0.5.141
- **Header layout rework.** User: "move the pill for the drop down out of the main header and put it to the right side of the screen and I want it a square 'pill'. And Your business coach more at the top."
- **Sub-toolbar relocation:** `js/active-org.js` now detects the `#activeBizName` pill on init and, if it's inside `<header class="site-header">`, moves it into a new `<div id="bizSwitcherBar" class="biz-switcher-bar">` inserted right after the header. The move happens once per page load via `insertBefore` — preserves event listeners, dataset attributes, and the v0.5.135 account-override flag. Account-level toolbar pages (those using `.screen-toolbar` instead of `.site-header`) are untouched.
- **CSS:**
  - New `.biz-switcher-bar` — `display: flex; justify-content: flex-end; padding: 8px 16px; background: #f4f6f9; border-bottom: 1px solid #e5e7eb; position: sticky; top: 0; z-index: 40;`. Right-aligned content, hides itself when empty.
  - `.biz-pill` border-radius: `14px` → `6px` (square-ish). Padding bumped slightly (6px×12px) and font-size 13px so the new shape doesn't look cramped.
  - Removed the v0.5.124/130 `.site-header:has(.biz-pill:not(:empty)) .header-title { display: none; }` rule — the pill no longer lives in the header, so the title doesn't need to give it space. On phones the title now always shows.
  - `.header-title` font on phones: `1rem` → `1.05rem`, font-weight `700` → `800`. Slightly more prominent on small screens.
- **Compat with v0.5.139 switcher:** `renderBizSwitcher()` runs after `relocatePillToSubToolbar()`, so the `<select>` it builds lives in the sub-toolbar from the start. Click-to-switch behaviour unchanged.
- **Compat with v0.5.135 account override:** the account-scope override (`🏛️ [Account Name]`) still writes to `#activeBizName` — which is now in the sub-toolbar. Same visual result, just relocated.
- **No SQL.**

---

## v0.5.140
- **Manual reordering of businesses.** User asked: "I want to be able to move the order of the businesses." Previously they were sorted alphabetically (by name) wherever they appeared (account dashboard list, v0.5.139 navy header switcher, account-level carousels). Now the order is admin-controlled.
- **`supabase/v0.5.140-delta.sql`** — one column, one index, no RLS change:
  ```sql
  ALTER TABLE organisations ADD COLUMN IF NOT EXISTS sort_order int NOT NULL DEFAULT 0;
  CREATE INDEX IF NOT EXISTS organisations_sub_sort_idx ON organisations(subscription_id, sort_order);
  ```
- **UI on `index.html`**: each biz card now has a small ↑/↓ pair next to the role pill, hidden for non-admins and when there's only one biz. Click swaps `sort_order` between the clicked biz and its neighbour, persists both updates to Supabase, re-renders the list. Top biz's ↑ is disabled; bottom biz's ↓ is disabled.
- **`renderBusinesses()` sort** changed from "alphabetical by name" to "sort_order ASC then name ASC" so ties from default-0 rows resolve sensibly. The first reorder click migrates default-0 rows to distinct values based on their current position.
- **`js/active-org.js`** — the multi-biz switcher dropdown (v0.5.139) now selects `sort_order` and applies the same ordering. Reorder clicks on the dashboard invalidate the `coach4u_biz_list_cache` localStorage entry so the switcher picks up the new order on the next page load.
- **No new pages.** All changes land on `index.html`, `js/active-org.js`, `css/style.css` (one small block of CSS for the `.reorder-btn` style — square 26x26 buttons with subtle hover), and the SQL delta.

---

## v0.5.139
- **Business-switcher dropdown in the navy header.** User feedback: working with a multi-business client account, they wanted to jump between businesses without leaving the page they're on. "If I'm in issues I need to go to each issue for each business with a drop down."
- **How it works:** `js/active-org.js` now detects when the active subscription has 2+ businesses the user is a member of, and converts the `🏢 [Biz Name]` pill (a `<span>`) into a `<select>` listing every business. Picking a different biz from the dropdown calls `activeOrg.set(newOrgId, newName)` then `window.location.reload()` — same page (issues.html / goals.html / scorecard.html / wherever), different business's data.
- **Available on every business-level page** automatically — they all already render the `#activeBizName` pill from `active-org.js`. Single-business accounts don't see the dropdown (no point); the pill stays a plain span.
- **Lazy-loaded Supabase:** active-org.js wasn't tied to Supabase before. Now it dynamically `import()`s the client only when the switcher needs to fetch the business list. No upfront cost on page loads where it's not used.
- **5-minute localStorage cache** (`coach4u_biz_list_cache` keyed by subscription id) so the switcher renders instantly on subsequent pages without re-querying. Invalidated automatically when the account is switched via `setSubscription(...)` (the index.html switcher already calls this).
- **Account-scope override compat:** the v0.5.135 account-pill override (`🏛️ [Account]` on `annual-sessions.html?scope=account`, `quarterly-sessions.html?scope=account`, `team-checkins.html?scope=account`, and the two account-scope session workspaces) now marks the pill `data-overridden="1"`. The switcher checks for that flag and leaves the override alone. If the switcher had already replaced the pill with a `<select>` first, the override swaps it back to a `<span>` showing the account context.
- **CSS:** added `select.biz-pill` rules (appearance:none, inline SVG caret, teal background) so the dropdown looks like the existing pill rather than a native select control.
- **No SQL.** One file (`js/active-org.js`) gained ~70 lines of switcher logic, plus a small CSS addition and one-line marker insertions across 5 account-scope pages.

---

## v0.5.138
- **Promote an issue to a Quarterly Goal.** User asked to "set up the issues and add a button to add the goal on the back of the issues" — the common IDS-on-the-back-of-an-issue flow: discuss issue, decide it's actually a strategic priority, make it a goal.
- **UI:** new teal "Make a goal →" button in the Edit-Issue modal footer (only shown on existing issues, hidden on Add-new since the row needs an ID before it can be promoted).
- **What it does on click:**
  1. Confirms with the user (shows the issue text + current quarter label so they know exactly what they're creating)
  2. Inserts a `rocks` row scoped to the active `organisation_id`: `description` and `owner` copied from the issue, `quarter = current quarter`, `status = on_track`, `company_rock = false`
  3. Marks the source `issue.status = 'resolved'` and writes a solution note: `"Promoted to Q[n] [YYYY] goal: '[description]'"` so the link is visible in the issues archive
  4. Closes the modal, shows a toast, navigates to `goals.html` (800ms later) so the user can finish setting up SMART criteria / status / etc.
- **Falls back gracefully**: if the rocks insert fails (RLS, schema, network), the toast surfaces the Postgres message and the issue is left untouched. If the rocks insert succeeds but the issue update fails, the goal still exists — the issue just won't auto-resolve; admin can mark it manually.
- **No SQL.** Reuses the existing `rocks` and `issues` tables and the v0.5.110+ RLS that lets admins+coaches write both.

---

## v0.5.137
- **Financial Outlook on the Operations one-pager.** User asked: "change the financials for each operations as an annual figure for last year and this year." Strategy one-pager has had financials for a while (v0.5.117 — 12 / 12 months rolling; simplified to totals in v0.5.118); Operations one-pager didn't have any. Now it does &mdash; annual format.
- **Two new strips, both at the bottom between the 3-column body and the footer:**
  - **`one-page-operations.html`** &mdash; single-business doc. Last Year + This Year (YTD), each with Revenue / Expenses / Profit.
  - **`account-ops-plans.html`** &mdash; carousel renders the same strip inside every business card, with the totals scoped to that business.
- **Data source**: reuses the existing `financial_periods` table (no SQL changes). Query `period >= [lastYear]-01-01 AND period <= [thisYear]-12-01`, aggregate by `YEAR(period)`.
  - Last Year = previous calendar year, full-year totals
  - This Year = current calendar year, YTD totals (months already entered)
  - Profit = Revenue &minus; Expenses, coloured teal / red against zero, grey when both inputs are empty
  - Per-row missing data shows "—"; rows where neither was entered get the empty profit treatment
- **Account carousel** adds one parallel query (`financial_periods.in(orgIds)`) when loading; results bucketed per-org client-side into `data.finByYear[year] = { totRev, totExp, anyRev, anyExp }` so each card renders independently.
- **CSS**: copied the `.doc-financials` / `.fin-strip-*` / `.fin-line-*` block from the Strategy one-pager so both ops pages match the look. Print rules added (`page-break-inside: avoid`, tighter padding in print).
- **Trade-off note**: the Strategy one-pager uses *rolling* 12 months (May 25 → Apr 26 last; May 26 → Apr 27 next). The Ops one-pager uses *calendar year* totals (2025 full year; 2026 YTD). Different framings; matches the user's "last year / this year" ask.

---

## v0.5.136
- **Account-scoped session area links now route to the account carousels.** User report from inside an iasHQ account-level session: "the links in the annual session ie targets needs to go to the IAS area, not the outsourcing." The "Open Targets →" link was hardcoded to `targets.html` &mdash; a biz-scoped page &mdash; so it opened whatever business `window.activeOrg.get()` was holding (some other biz like Outsourcing), not the account context.
- **Pattern:** added an `ACCOUNT_LINK_MAP` in both `run-annual-session.html` and `run-quarterly-session.html`:
  - `core-values.html` &rarr; `account-values.html`
  - `core-focus.html` &rarr; `account-focus.html`
  - `targets.html` &rarr; `account-targets.html`
  - `marketing-strategy.html` &rarr; `account-marketing.html`
  - `leadership-team.html` &rarr; `account-leadership.html`
  - `goals.html` &rarr; `account-goals.html`
- A `scopeAreaLinks(areas, isAccount)` helper rewrites the `href` on every area link before render. When `isAccount` is false (biz-scoped sessions), the helper is a no-op &mdash; existing behaviour preserved. When the session has `subscription_id` set and `organisation_id` is null, the map is applied.
- **Why account carousels:** they're cross-business read-only views that already exist (added in v0.5.96; multi-tenant-scoped to the active subscription in v0.5.116). Landing there gives the user the right context for account-level planning &mdash; they can see every business's targets/values/etc. side by side.
- No SQL. UI-only fix on two files.

---

## v0.5.135
- **Account-scope context fix on planning pages.** User report: "iasHQ - click on planning - start a planning day and it's opening the general business." On a closer look the session was being created with the correct `subscription_id` (iasHQ's sub), so the data was right — but the navy header pill still showed whatever business was last active (typically Coach4U from another account), which made the workspace LOOK like it belonged to that biz. Confusing.
- **What changed:** on the three account-scoped list pages (`annual-sessions.html?scope=account`, `quarterly-sessions.html?scope=account`, `team-checkins.html?scope=account`) and their workspaces (`run-annual-session.html`, `run-quarterly-session.html` when the loaded row has `subscription_id` set but no `organisation_id`), the `#activeBizName` element is overridden after init to read `🏛️ [Account Name]` instead of `🏢 [Biz Name]`. Different icon (`🏛️` ≠ `🏢`) so the user can tell account-scope from biz-scope at a glance.
- **Also hidden in account scope:** the ws-hint links at the top of `annual-sessions.html` ("View your current One-Page Plan →") and `quarterly-sessions.html` ("Open Quarterly Goals →") — those point at business-scoped destinations and don't apply when running account-level planning.
- **Account name source:** `window.activeOrg.getSubscriptionName()` (set when the user switches account via the `index.html` switcher in v0.5.111). Falls back to the literal word "Account" if for some reason the name isn't in localStorage yet.
- **No SQL.** Pure UI override on five pages.

---

## v0.5.134
- **Surfaced actual insert errors on the "+ New" buttons.** User reported "the account create planning annual day link start new meeting isn't working" — generic "Could not create session" toast was hiding the real cause.
- **Pattern applied to three pages** — `annual-sessions.html`, `quarterly-sessions.html`, `team-checkins.html`. Now the toast picks the right hint based on the Postgres error:
  - `column subscription_id does not exist` → "SQL not applied — run supabase/v0.5.132-delta.sql"
  - `row-level security` / `policy` → "Permission denied — you need to be the account owner"
  - `violates check constraint` → "Schema mismatch — re-run v0.5.132-delta.sql"
  - Otherwise → the raw Postgres message verbatim
- Also added explicit pre-check: if `IS_ACCOUNT` is true but `subId` is null at click time, the toast reads "No active account — switch account first" instead of going straight to the API.
- Errors also now `console.warn` the full error object (not just `.message`) so DevTools shows the full hint/details for further triage.
- No SQL changes. Pure UX fix for diagnostics.

---

## v0.5.133
- **Hygiene fix to `supabase/schema.sql`.** User hit the error `cannot drop function user_org_ids(uuid) because other objects depend on it ... policy "members read financial_periods" on table financial_periods depends on function user_org_ids(uuid) ... use DROP ... CASCADE` while applying SQL.
- **Root cause:** the error came from running `schema.sql` (the full source-of-truth file) on a populated DB, *not* from `v0.5.132-delta.sql`. The delta file is clean — it doesn't drop user_org_ids anywhere. But `schema.sql` line 59 had `DROP FUNCTION IF EXISTS public.user_org_ids(uuid)` without `CASCADE`. That was safe pre-v0.5.117 (no dependents); after the financial_periods table arrived with a policy that uses user_org_ids, the bare DROP fails.
- **Fix:** changed those two DROP FUNCTION lines (user_org_ids and user_admin_org_ids) to use `CASCADE`. Fresh installs are unaffected (nothing to cascade). Accidental schema.sql re-runs on a populated DB now succeed because dependent policies get dropped along with the function, then recreated by the schema.sql CREATE POLICY statements further down.
- **Better practice for the user:** for incremental DB updates, only run the `vX.Y.Z-delta.sql` file for the version being applied. `schema.sql` is the source-of-truth artefact for cold-starting a fresh project, not for migrating an existing one.
- **No new SQL to run** for this hygiene fix unless they want to update their schema.sql copy; the v0.5.132 delta is the only thing that actually needs applying.

---

## v0.5.132
- **Dual-mode planning + new Team Check-ins module.** User asked: should planning live per-business or per-account? Answer: both. Sessions and check-in batches can now be created at either scope; admin picks when creating. Also asked: ability to delete an unintentional meeting; that's in too.
- **SQL — `supabase/v0.5.132-delta.sql`:**
  - **`annual_sessions` / `quarterly_sessions`** — `organisation_id` made nullable; new `subscription_id uuid` (nullable, FK → subscriptions). New CHECK constraint: exactly one of (`organisation_id`, `subscription_id`) is set per row. Existing per-business sessions keep working (organisation_id NOT NULL); new account-level sessions set subscription_id only.
  - **`checkin_batches`** — new table for standalone check-in runs not tied to a planning session. Same dual-scope shape (organisation_id OR subscription_id). Columns: `name`, `run_date`, `invitees jsonb`, `notes`, `status` ('open'/'closed').
  - **`team_checkins.session_type`** — CHECK widened to include `'batch'`. A submitter's row carries their own `organisation_id` (which sub-org they belong to) even when the batch / session is account-scoped.
  - **Two new helper functions:** `public.user_account_ids(uid)` returns all subscription_ids the user has access to (owner OR active member of any org in the sub); `public.user_admin_account_ids(uid)` returns subs where the user is owner OR admin/coach of any org in the sub.
  - **RLS rewritten on annual_sessions, quarterly_sessions, checkin_batches** to handle both scopes — biz rows checked via `user_org_ids` / `user_admin_org_ids`, account rows via the new `user_account_ids` / `user_admin_account_ids` helpers.
  - **`team_checkins` SELECT** policy tightened: rows with `session_type='batch'` are admin/coach-only readable (per user direction "data analysed in one place, admin only"). Annual/quarterly rows stay member-readable as before.
- **Front-end pages:**
  - **New `team-checkins.html`** — list of batches at biz or account scope (via `?scope=account`). "+ New Check-in" modal creates a batch (name + date) and navigates to the workspace.
  - **New `run-team-checkin.html`** — admin workspace for one batch. Editable name / date / status. Invitees list (name + email, no enforcement — informational). "Copy link" share button. Admin notes textarea. Aggregated results table with the 17 questions ranked by lowest-scoring at the top. Delete batch (with confirm — also deletes submitted check-in rows).
  - **`team-checkin.html` (member form)** — now accepts `?batch_id=X&kind=batch` in addition to the existing `?session=X&type=annual|quarterly`. When the session/batch is account-scoped (subscription_id set, no organisation_id), the form looks up the user's first active org in that subscription and uses that as their submitting org_id. Membership verification + duplicate-check logic preserved.
  - **`planning.html` (biz-level hub)** — gained a third card "Team Check-ins" alongside Annual + Quarterly.
  - **`account-planning.html` (account-level hub)** — restructured with two sections: **"Run for the whole account"** (three account-scope cards: Annual / Quarterly / Team Check-ins) and **"Across all your businesses"** (the existing carousel links: annual / quarterly / check-in views per biz, read-only).
  - **`annual-sessions.html`, `quarterly-sessions.html`** — accept `?scope=account` URL param. When set: queries scoped to `subscription_id` instead of `organisation_id`; "+ New Session" inserts with `subscription_id`; header rewires to point back to `account-planning.html`; page title gains "(Account)" indicator.
  - **`run-annual-session.html`, `run-quarterly-session.html`** — detect scope from the loaded row (which scope column is set). Header-back link rewires to the matching scoped list; title shows "(Account)" when appropriate. All workspace functionality (notes, links, commitments from v0.5.131; check-in results; status flip) works identically across both scopes.
- **Meeting delete** — `meeting.html` list view gains a small `×` button beside each meeting row. Click → confirm → `DELETE FROM meetings WHERE id = ?`. RLS lets admins+coaches delete; members can't.
- **Build size:** 3 new pages (team-checkins.html, run-team-checkin.html, v0.5.132-delta.sql) + meaningful edits across ~8 existing pages + schema mirror updates.
- **schema.sql** mirror: partial. The delta is the source of truth for applied changes; schema.sql will be brought fully into sync in a follow-up version.

---

## v0.5.131
- **Improved Annual Planning Session workspace** &mdash; richer capture, less rigid structure. User feedback: "the EOS way is too structured" and "maybe a link to their recording if this is helpful for clients. I don't want to store data &mdash; they can set up external folders and link it to docs for the session."
- **`supabase/v0.5.131-delta.sql`** &mdash; three new columns on `annual_sessions` (all `ADD COLUMN IF NOT EXISTS`, no RLS changes):
  - `notes text` &mdash; free-form session notes
  - `external_links jsonb` &mdash; array of `{label, url}`; defaults to `[]`
  - `commitments jsonb` &mdash; array of `{name, commitment}`; defaults to `[]`
- **`run-annual-session.html`** &mdash; three new blocks inserted between Areas-to-Cover and Team Check-in:
  - **Session Resources** &mdash; "Link to your recording, slides, shared folder, or photos. Nothing is uploaded &mdash; just URLs to your own storage (Google Drive, Zoom, Notion, etc.)" Add/remove rows with label + URL inputs. URL field rendered in teal monospace for visual scanning.
  - **Session Notes** &mdash; "What got decided? What surprised you? What worked, what didn't?" Big resizable textarea, autosaves on input (500ms debounce).
  - **Personal Commitments** &mdash; "What's the one thing each leader will work on this year? These carry into your quarterly sessions." Add/remove rows with name + multi-line commitment. The "One Thing" exercise from the deepened annual guide gets a place to land.
- **CSS additions** for `.row-list`, `.link-row`, `.commit-row`, `.row-input`, `.row-del`, `.row-add`, `.row-empty` &mdash; consistent grid-based row pattern shared between links and commitments. Mobile breakpoint at 540px stacks the URL/textarea below the label/name to one column.
- **Autosave behaviour** &mdash; all three new sections auto-save with a 500ms debounce. Adding or deleting a row saves immediately. Failed saves show a toast.
- **Existing structure preserved** &mdash; the 4-area checklist (Review Last Year, Refresh Core Values + Core Focus, Update 10-Year + 3-Year Outlook, Set 1-Year Plan + Q1 Goals) stays as a lightweight preflight. The new sections are where the actual session substance lives.
- **Scoped to annual sessions only** &mdash; quarterly sessions unchanged for now. Same treatment can be applied later if useful.
- **No file storage.** Per the user: "I don't want to store data." Only URL strings + text are stored; no uploads, no file references, no third-party API integrations.

---

## v0.5.130
- **Dropped all dead Coach4U sample-data seeds from `business.html`'s `ensureSeeds()`.** The strategy seeds went in v0.5.113; this version removes the operations + planning seeds — `coach4u_demo_meetings`, `coach4u_demo_rocks`, `coach4u_demo_scorecard`, `coach4u_demo_issues`, `coach4u_annual_sessions`, `coach4u_quarterly_sessions`. 130 lines of dead code gone. Every page now reads from Supabase; `ensureSeeds()` stays as a no-op stub so the call-site in `init()` doesn't need editing.
- **Rewrote `operations.html`'s "Run Weekly Meeting" button to use Supabase.** It was the last reader of `coach4u_demo_meetings`. Now finds-or-creates a `meetings` row for this Monday (this org + `meeting_date = thisMondayIso`) and navigates to `run-meeting.html?id=…`. Falls back to `business.html` if there's no active org.
- **Mobile keyboard handling.** New `js/mobile-keyboard.js` (~50 lines) wired into all 61 root + learn pages. On touch devices, listens for `focusin` on inputs/textareas/contenteditables, waits ~350ms for the keyboard to animate in, and calls `scrollIntoView({ behavior: 'smooth', block: 'center' })` on the focused field. Adds `body.keyboard-open` while typing so other CSS can react. Skips non-text inputs (checkbox, radio, button etc.).
- **CSS for the keyboard fix** in `css/style.css`: `input, textarea, select, [contenteditable] { scroll-margin-bottom: 260px; }` so the browser leaves room below the input when scrolling it into view; `body.keyboard-open .ws-save-bar { transform: translateY(120%) }` so the sticky save-bar slides out of the way while typing, preventing it from sitting on top of the field.
- **Restored "Your Business Coach" title in the navy header on phones for account-level pages.** User reported the navy bar on `index.html` was empty on first launch — just "Sign Out" on the right with nothing on the left. The v0.5.124 hide-on-phones rule was too broad. New rule uses CSS `:has()`: `.site-header:has(.biz-pill:not(:empty)) .header-title { display: none; }` — title only hides when a populated biz pill (business-level page) is competing for space. Account-level pages (no biz pill) now show the title. Title font tightened to 1rem on phones.
- **No SQL.**

---

## v0.5.129
- **VB2 source arrived &mdash; deepened the two guides that couldn't be fully audited against a source in v0.5.126.** User uploaded `EOS-VB2-Implementer-Guide.pdf` (2.5MB, the real PDF) which had previously been a 2-byte stub. Moved it to `/EOS/2022-07-14_EOS-VB2-Implementer-Guide.pdf` to match the rest.
- **`learn/marketing-strategy.html` &mdash; rewritten from ~200 to ~700 words.** Was audited as "SOLID (within what's verifiable)" but the source was missing. Now matches VB2 depth:
  - **DGP framework** &mdash; Target Market via Demographic + Geographic + Psychographic, leading to "The List" as a finite, named filter
  - **Rule of 7** &mdash; customers need to hear the message 7+ times before they hear it for the first time
  - **3 Differentiators competitor test** &mdash; "every competitor may do one or two; you're the only one that does all three" (Southwest Airlines 3LFs example)
  - **Process and Guarantee as YES/NO decisions** &mdash; decide today, then either commit to building it as a future quarterly goal, or remove from the plan; no half-measures
  - **Common pitfalls** specific to each of the four: target-too-wide, adjective differentiators, sales-funnel as Process, toothless guarantee
- **`learn/targets.html` &mdash; tightened the 3-Year and 1-Year sections with VB2 facilitation details.** The agent flagged these as partial (no source) in v0.5.126:
  - **"Shot over the bow then debate"** framing for every number (Revenue / Profit / Measurables)
  - **3-Year specific bullet prompts**: # employees + right-people-right-seats, # clients, locations, new products, marketing efforts, your own role
  - **5&ndash;15 surviving bullets** target with "err on the side of leaving something on the list"
  - **The see-it / want-it / believe-it three-question test** at the end of 3-Year (previously had only "do you see it?")
  - **Each person shares their role** at end of 3-Year &mdash; no discussion &mdash; to surface misalignment
  - **1-Year quiet-time prompt** explicitly references the 3-Year Outlook + Issues List + Org Chart as the inputs
  - **One-at-a-time onto the board** rule for 1-Year goals (don't batch &mdash; weak goals survive in noise)
  - **Full closing read-back** &mdash; "If we're sitting here on [date] with this revenue, profit, measurables, and we have achieved goal #1 [name], goal #2 [name]&hellip; will that have been a great year?"
- Built via one-shot Python (`_deepen_vb2.py`, deleted after run). No SQL. No EOS trademark terminology in user-facing copy &mdash; the v0.5.116 wording rules still apply (Niche stays as a worksheet field name but is generic enough).

---

## v0.5.128
- **Fixed a wording bug in the Annual Planning Session guide's Coach's tip.** User caught it: the tip read "If you wait, it'll slip into a busy quarter, then slip again" &mdash; recycled language from the Quarterly tip that doesn't fit the annual cadence (annuals slip across years, not quarters). Rewrote: "If you wait, the date gets eaten by busy quarters and the year quietly disappears."
- One-line front-end fix. No SQL.

---

## v0.5.127
- **Removed the standalone Values Discovery exercise.** User feedback: "I don't think the run the values guide is needed. It's just not helpful compared to the comprehensive other document." Agreed — the 3-step interactive page (~430 lines) was always a slimmer take, and the deepened Core Values guide (v0.5.125) now contains the full facilitated exercise with timings and steps anyway. Two doors to the same room, where one is the better door.
- **Changes:**
  - Deleted `learn/values-discovery.html` (the 3-step interactive page).
  - Removed the "Run the Values Discovery exercise" ghost button from `learning-vault.html`'s Core Values card. The card now shows two actions: `Read the guide →` (primary) and `Open worksheet` (ghost).
  - Removed the "Run the Values Discovery exercise" primary CTA from the bottom of `learn/core-values.html`. The CTA row now shows just `Open the Core Values worksheet →` (primary, teal). Reading the guide and running the exercise are now the same thing — the guide is the script.
- **Verified zero orphan references** to `values-discovery.html` across `*.html` and `learn/*.html`.
- **No SQL.**

---

## v0.5.126
- **Deepened the 9 remaining light Learning Vault guides** to match the depth of v0.5.125's Core Values rewrite. The parity audit (run in v0.5.125) found 6 TOO LIGHT and 3 LIGHT guides versus the EOS implementer source docs in `/EOS/`. Each is now a real how-to playbook with the actual exercise the facilitator runs, not a concept summary.
- **What's now in each guide** (the patterns the audit flagged as universally missing):
  - **Silent-write-then-share-around-the-table** facilitation pattern at the start of every exercise
  - **Keep / Kill / Combine** voting mechanic (colour-coded where relevant)
  - **Closing read-back or visualisation checks** ("when this is done, will it have been a good X?", "close your eyes — do you all see it?")
  - Explicit **timings per step** so the session can be run to the clock
  - The **specific prompts** that elicit good answers (e.g. the "desert-island" prompt for the scorecard, the "100 of them" prompt for values)
- **What each guide gained:**
  - **Core Focus** — silent-write / stir-the-pot / 80% consensus sequence; 4 Purpose archetypes (Solving / Helping / Building / Winning); "client × problem × outcome" Niche test
  - **Targets** — three sub-exercises (10-Year / 3-Year / 1-Year) each with their own steps; the close-eyes test on 3-Year; the budget-support check on 1-Year; cascade to departmental plans
  - **Leadership Team** — two ground rules (forward 6–12 months; no people yet); three major functions + Integrator; LMA rule (Lead / Manage / Accountability); fit test (understands / wants / capacity); the 3 yes questions
  - **Quarterly Goals** — Big Rocks (Covey) + laser focus framing; full 7-step exercise (silent → board → K/K/C colour-coded → star round → SMART → first step → read-back); don't-erase-the-killed-list rule
  - **Weekly Numbers** — the 8 reasons every leader needs a number; desert-island prompt; two-job test (pulse + predict); lead vs lag filter (≥ 50% leading)
  - **Weekly Meeting** — the 5-point cadence rule; explicit "drop it down" principle for the front of the agenda; 90%-of-todos-dropping-off rule; cascading messages in conclude
  - **Issues** — full 3-step Identify/Discuss/Resolve protocol with examples; the 80% rule + "disagree and commit"; 30-second prioritisation ritual
  - **Quarterly Planning Session** — 9-step agenda with timings; 80% completion target; operating-system health check across 6 components
  - **Annual Planning Session** — 2-day structured agenda (Day 1: where are we / Lencioni 5-Dysfunctions / One Thing / SWOT; Day 2: 3-Year / 1-Year / Q1 / cascade); the One Thing exercise (60 min) called out as highest-leverage of the two days
- **No EOS trademark terminology** in user-facing copy — the wording rules from v0.5.116 still apply. The methodology comes from the EOS implementer guides; the Lencioni 5-Dysfunctions framework and Covey's Big Rocks metaphor are non-EOS public sources cited directly. The DB table name `rocks` keeps its name; UI text reads "Quarterly Goals".
- **3 guides left unchanged** per the audit:
  - `marketing-strategy.html` — verdict SOLID; VB2 source (where Marketing Strategy is taught in EOS) is a 2-byte stub in the repo, no docx fallback, so couldn't deepen against a source.
  - `financials.html` — no EOS counterpart (financials aren't a separate EOS tool).
  - `team-checkin.html` — Organizational Checkup source not in the repo.
- **Built via a one-shot Python rewrite script** (`_deepen_guides.py`, deleted after the build) — each guide's body sections + tip body replaced in place, preserving the smart-back-link header (v0.5.122) and the bottom CTA row.
- **No SQL.** Pure content build.

---

## v0.5.125
- **Rewrote `learn/core-values.html` to match the depth of the original EOS implementation experience.** User feedback: "Check again at the activities especially the values one as I think the one written is a little light on." Confirmed by re-reading the EOS VB1 (Vision Building Day 1) Implementer Guide — the Core Values exercise in that document is a 2-hour structured group exercise; my guide had compressed it to 4 bullet points.
- **What's now in the guide** (~800 words, up from ~200):
  - **The "100 of them" prompt** as the starting point — name 3 people you'd want 100 of, not 3 best people. The framing is what makes it work.
  - **The 5-step exercise flow** with timings: silent listing → characteristics on the board → first Keep/Kill/Combine pass (down to 10–15) → break → apply traps → second pass (down to 3–7) → test.
  - **Lencioni's three value traps** with a test for each: Accidental (emerged from a past or partial subset), Aspirational (you wish, you don't), Permission-to-play (generic table-stakes any competitor could claim).
  - **The People Test** — score 3–5 real team members 1–5 against each draft value; real values differentiate (stars high, bottom-end low).
  - **The Five-Use Test** — would you actually use this to hire / fire / review / reward / recognise? If not five out of five, it's not a value.
  - **Updated Common Pitfalls** — skipping the people-listing, doing it solo, trying to land it in one pass, wordsmithing too early, too many.
  - **Coach's tip** rewritten to emphasise the hiring use of values + the cost of letting in a single low-scoring hire.
- **Source**: the EOS VB1 Implementer Guide (`EOS/2023-04-27_EOS-VB1-Implementer-Guide(1).docx`), Core Values section pages 17–20. The methodology is faithfully translated; **no EOS trademark terminology is used in user-facing copy** (the v0.5.116 rules still apply). The Lencioni value-trap framework is from Patrick Lencioni's 2002 HBR article *Make Your Values Mean Something* — not EOS-specific, so the framework name and trap names are kept as-is.
- **CTA order swapped on the guide** — "Run the Values Discovery exercise" is now the primary action (teal), worksheet is secondary (ghost). The exercise is the way to discover values; the worksheet is where you commit them once known.
- **Parity audit running in background** for the other 12 guides against their EOS source docs. Results inform v0.5.126.
- **No SQL.**

---

## v0.5.124
- **Decluttered the navy site-header on phones.** User feedback: "The top blue header looks too busy now on phone." Four elements were competing inside a ~390px iPhone bar: back link, "Your Business Coach" title, 🏢 biz pill, Sign Out — plus their gaps. Reading as cluttered.
- **Hid `.header-title` (the "Your Business Coach" wordmark) at ≤ 640px** — `display: none` in the mobile media query. The brand is preserved everywhere else: the PWA icon + name on the user's home screen, the body `<h1>` on every page that names the activity, and the back link that names the section. Removing the redundant third copy from the navy bar gives the back link + biz pill + sign-out room to breathe.
- **Minor tighten while in there:** mobile header padding 12px → 10px vertical; biz pill `max-width` 110 → 160px at 480px and 90 → 120px at 400px (so long business names truncate less); back-link font 12 → 14px (less eye-strain).
- **Tablet/desktop header unchanged** — the full `← Back · Your Business Coach · 🏢 Biz · Sign Out` row stays above 640px.
- **No SQL.** Single CSS change in `css/style.css`.

---

## v0.5.123
- **Fixed the broken PWA install.** User screenshot of "Add to Home Screen" dialog showed the app name as "Coach4U" with a generic auto-generated "C" letter avatar, URL truncated to `cathcoach4u.github.io/exte…`. Three things were wrong:
  - **`manifest.json` had stale paths.** `start_url`, `scope` and the two icon `src` values all pointed at `/external-Coach4u-app/` (the old repo path). The site lives at `/yourbusinesscoach/`, so iOS launched the installed app at a 404 and couldn't load the icon — falling back to its auto-generated letter avatar. Rewrote with relative paths (`./`, `./icon-192.png`, `./icon-512.png`) so the manifest works on any hosting URL.
  - **`apple-touch-icon` missing on most pages.** Only `business.html` and `setup.html` declared the link, and both pointed at `favicon.svg`. iOS Safari doesn't reliably honour SVG as a home-screen icon; it needs a PNG. Added `<link rel="apple-touch-icon" sizes="180x180" href="apple-touch-icon.png">` to every page (57 files: every root HTML + every `learn/` guide).
  - **No PNG icons existed.** Generated three from a Python/Pillow script that matches the brand: 180×180 (`apple-touch-icon.png`, what iOS uses for home-screen), 192×192 and 512×512 (manifest icons, what PWA installers + Android Chrome use). Design: navy rounded square with diagonal gradient + subtle decorative circle, white **B** and teal **C** centred (per user request, "BC such as Business Coach"). Also updated `favicon.svg` to the same BC mark so the browser tab matches.
- **`offline.html`** had `window.location.href='/external-Coach4u-app/'` baked into its "Go to home" button — fixed to use relative `./`.
- **Service-worker cache version bumped** to `coach4u-v0.5.123` so iOS picks up the new manifest + icons on the next visit. The user will need to **remove the existing app icon from their home screen and Add to Home Screen again** — iOS aggressively caches PWA icons and won't update them in place.
- **No SQL.**

---

## v0.5.122
- **Smart "back" link on every Learning Vault guide.** User feedback: "It says back to learning vault but if you have opened it from the sections you need to go back to the section you have opened it. But good to also go to learning vault." Two paths in, one path back wasn't right.
- **The pattern**: on guide page load, check `document.referrer`. If the visitor came from the matching worksheet/tool (e.g. they clicked `Read the Quarterly Goals guide →` from `goals.html`), swap the header back link from `← Learning Vault` → `← Quarterly Goals` and point it at `../goals.html`. If they came from the Vault index (or from anywhere unrecognised), the link stays `← Learning Vault`. Brief flicker on the swap is acceptable — the JS runs at the top of `init()` before the auth check.
- **Mapping per guide** (the parent worksheet/tool each guide checks for as its "came from" source):
  - Strategy guides → their matching worksheet (`core-values.html`, `core-focus.html`, `targets.html`, `financials.html`, `marketing-strategy.html`, `leadership-team.html`).
  - Operations guides → their matching tool (`goals.html`, `scorecard.html`, `meeting.html`, `issues.html`).
  - Planning guides → their session list page (`quarterly-sessions.html`, `annual-sessions.html`, `planning.html` for team check-in).
- **Wiring**: each guide's `<a class="header-back">` gained two data attributes (`data-worksheet-href`, `data-worksheet-label`) and a small synchronous swap snippet at the top of `init()` that reads them, compares the filename of `document.referrer` against the worksheet href, and rewrites the link if they match.
- **Bottom `← Back to Learning Vault` link unchanged** — that's the always-on Vault path the user explicitly wanted to keep. The primary teal `Open the worksheet →` CTA also stays, so the user can move forward into the activity even if they came from somewhere else.
- **Built via a one-shot Python patch** across all 13 guide files so the wiring stays uniform. No SQL.

---

## v0.5.121
- **Deep-linked the in-page Vault tip box** on every worksheet and operations tool to its specific guide. User feedback from inside `goals.html`: "There is a click button in there taking me to the learning area. This is a generic link and doesn't connect to the specific activity. Wouldn't it be better to go to the specific activity area." Yes — fixed.
- **Mapping** applied to 10 pages:
  - `core-values.html` → `learn/core-values.html`
  - `core-focus.html` → `learn/core-focus.html`
  - `targets.html` → `learn/targets.html`
  - `financials.html` → `learn/financials.html` (had no Vault link before; added one)
  - `marketing-strategy.html` → `learn/marketing-strategy.html`
  - `leadership-team.html` → `learn/leadership-team.html`
  - `goals.html` → `learn/quarterly-goals.html`
  - `scorecard.html` → `learn/weekly-numbers.html`
  - `meeting.html` → `learn/weekly-team-meeting.html`
  - `issues.html` → `learn/issues.html`
- **Link label tightened too.** Was "Explore [topic] exercises in the Learning Vault →" (vague, sounded like a placeholder). Now "Read the [Activity Name] guide →" (specific, action-oriented, matches the Vault index button label so the user knows it's the same thing).
- **Bottom-nav "Learn" tab still goes to the Vault index** (`learning-vault.html`) — that remains the entry point for browsing all activities. Only the in-page contextual tip box deep-links.
- **Workspaces** (`run-meeting.html`, `run-annual-session.html`, `run-quarterly-session.html`) don't have an in-page Vault tip box and weren't changed — the read-the-guide framing fits worksheets, not in-flight workspaces.
- **No SQL.** Pure content/link tidy.

---

## v0.5.120
- **Wrote actual content for every Learning Vault guide.** User pushback on v0.5.119: "I don't see what value you have offered. The links don't go to the actual page — they still must go for [the] Learning Vault." Fair criticism — v0.5.119 indexed the activities but the "Read guide" buttons were grey "Coming soon" placeholders, so the Vault was just a launcher pointing back to pages already reachable via the bottom nav. No new value.
- **13 new guide pages** under `learn/<slug>.html`, one per activity in the program:
  - **Strategy** — `core-values`, `core-focus`, `targets`, `financials`, `marketing-strategy`, `leadership-team`
  - **Operations** — `quarterly-goals`, `weekly-numbers`, `weekly-team-meeting`, `issues`
  - **Planning** — `quarterly-planning-session`, `annual-planning-session`, `team-checkin`
- **Guide template** — uniform structure across all 13: eyebrow (section · GUIDE), title with icon, one-line tagline, then four sections (What this is / Why it matters / How to do it well / Common pitfalls), a teal `Coach's tip` callout, and a CTA row with `Open the worksheet →` primary + `← Back to Learning Vault` link. Auth-gated like the rest of the app. Loads `active-org.js` so the business pill still shows in the header.
- **Content style** — direct, no fluff, no EOS jargon. Each guide ~250-400 words. The "How to do it well" sections are numbered steps the user can actually execute; "Common pitfalls" calls out the specific failure modes; "Coach's tip" is the one piece of advice that\'s most often missing.
- **Vault index rewired** — every card's primary CTA changed from `Open worksheet` (live) → `Read the guide` (live, links to `learn/<slug>.html`). The worksheet link drops to a secondary ghost button. The Core Values card keeps `Run the Values Discovery exercise` as a third ghost button alongside.
- **Built via Python script** (`_build_guides.py`, deleted after the build) — the content lives in a single Python dict so all 13 stay structurally consistent. Regenerating is easy if the template needs to change later.
- **No SQL, no schema.** Pure content build.

---

## v0.5.119
- **Rebuilt the Learning Vault as a structured activity index** mapped to the full Coach4U program. User asked: "all the activities that align to the full program."
- **13 activities, 3 sections:**
  - **Strategy — the foundations** (6): Core Values, Core Focus, Targets, Financials, Marketing Strategy, Leadership Team.
  - **Operations — the weekly cadence** (4): Quarterly Goals, Weekly Numbers, Weekly Team Meeting, Issues.
  - **Planning — the longer rhythm** (3): Quarterly Planning Session, Annual Planning Session, Team Check-in.
- **Each card has two CTAs side by side:**
  - A solid teal `Open worksheet / Open Quarterly Sessions / Run the Values Discovery exercise` — links straight into the live page in the app. The user can jump from the index directly into doing the activity.
  - A grey disabled `Read guide · Coming soon` — reserves the slot for written guides (no clutter, but the user can see what's coming).
- **The one existing guide** — `learn/values-discovery.html` (the 3-step Core Values exercise) — is surfaced as the secondary CTA on the Core Values card, instead of as a separate "Guided Exercises" section. Keeps the cards uniform.
- **Section blurbs** give a one-line framing for each group ("Set once, review every quarter — together these make up your One-Page Plan", etc.) so the index doubles as a quick orientation to the program structure.
- **Card design** is one column on mobile, one card per activity (icon + name + 2-line description + 2 buttons). No more "Coming Soon" cards that look broken — every card has at least one live action.
- **No SQL, no schema.** Pure front-end rewrite of `learning-vault.html`.
- **Open question for the next pass:** when the written guides ship, each will live as a new `learn/<activity>.html` page. The grey `Read guide` ghost button on the matching card becomes a live teal link. No structural changes needed to the Vault index when each guide arrives — just swap the ghost button for an anchor.

---

## v0.5.118
- **Simplified the Financial Outlook strip** on `one-page-plan.html` and the `account-plans.html` carousel. User feedback: "change figures to just show the final numbers not each month."
- **Before**: 12 month-rows + a totals row, with Month / Rev / Exp / Profit columns — quite dense.
- **After**: just the 12-month totals as three lines per side — Revenue, Expenses, Profit. The date range still shows in the column heading (e.g. *Last 12 Months · May 25 → Apr 26*) so the reader knows what the totals cover.
- **Replaced**: the `<table class="fin-mini">` mini-table + the `buildTable()` row-by-row builder is gone. Now a `<div class="fin-totals">` containing three `.fin-line` rows (Revenue / Expenses / Profit), with the profit line teal/red against zero and grey when both columns are empty.
- **CSS replaced**: removed the `.fin-mini` table styles and added `.fin-totals` / `.fin-line` / `.fin-line-label` / `.fin-line-value` (plus `.fin-line-profit` colour variants). Print rules updated accordingly.
- **Worksheet unchanged**: `financials.html` still lets the admin/coach enter month-by-month figures across the 24-month window — the simplification is display-only on the printed one-pager.
- **No SQL changes.**

---

## v0.5.117
- **Monthly financials added to the one-page plan.** User asked: "Does the one-page plan have revenue/expenses for the next 12 months? If not, this needs to be added. And list the last 12 months if figures available."
- **New `financial_periods` Supabase table** (`supabase/v0.5.117-delta.sql` + mirror in `schema.sql`):
  ```
  financial_periods (id, organisation_id, period [date, first-of-month],
                     revenue numeric, expenses numeric, created_at, updated_at,
                     UNIQUE (organisation_id, period))
  ```
  RLS mirrors the rest of the strategy tables: SELECT by active org members (via `user_org_ids`), INSERT/UPDATE/DELETE by admins + coaches (via `user_admin_org_ids`). Multi-tenant safe — every query is `eq('organisation_id', orgId)` and the account-level carousel scopes to the active subscription.
- **New worksheet `financials.html`** — linked from Strategy as a new `Financials` card. Renders 24 month-rows in two grouped tables: **Last 12 Months** (actuals) above **Next 12 Months** (forecast; current month sits at the top of the future block). Each row: month label + revenue input + expenses input + auto-computed profit. Inputs auto-save on each keystroke (500ms debounce) and immediately on blur via `upsert` against the `(organisation_id, period)` unique constraint. Totals row at the bottom of each table sums Rev/Exp/Profit with teal/red colouring. Inputs accept raw numbers — the helper strips `$` / commas / `K` etc. Profit auto-calculates per row and live-updates the section totals as you type.
- **`one-page-plan.html` extended** with a new **Financial Outlook** strip between the existing 3-column body and the footer. Two compact mini-tables side by side — Last 12 / Next 12 — month × Rev × Exp × Profit with totals. Months print at 0.62rem (smaller in print mode). Empty cells render as grey "—". Loads `financial_periods` via a 6th parallel query in the existing Promise.all. Empty state at the top of the strip: "No figures recorded yet — fill in Strategy → Financials."
- **`account-plans.html` carousel extended** to render the same financial strip inside every business card. The carousel fans out one extra `financial_periods` `.in('organisation_id', orgIds)` query, bucketed per-org client-side, so all businesses' financials load in a single round-trip. Each carousel card shows that business's own last 12 + next 12. Print rules updated so the financial strip stays on the same A4 page as the rest of the doc.
- **`strategy.html`** card grid gained a teal `💰 Financials` card linking to `financials.html`. Also tidied the Targets card description: "10-year vision, 3-year picture and 1-year plan" → "10-year vision, 3-year outlook and 1-year plan" (catching a leftover from the v0.5.116 EOS sweep).
- **`CLAUDE.md`** updated: `financials.html` added to the file structure, `financial_periods` added to the Strategy tables list.
- **Re-run required:** `supabase/v0.5.117-delta.sql` in the Supabase SQL Editor before testing. The CREATE is idempotent (`IF NOT EXISTS`) and the policies are `DROP POLICY IF EXISTS` + `CREATE POLICY` so re-runs are safe.

---

## v0.5.116
- **Full multi-tenant scoping sweep.** User asked: "Do a full audit to check all." The v0.5.111 multi-tenant work scoped the dashboard (`index.html`), v0.5.115 backported the fix to `account-plans.html` and shipped the new `account-ops-plans.html` already scoped. The remaining **12 account-level carousel pages** had the same pre-existing leak: their `team_members` query pulled every business the user was a member of, mixing client accounts together. Fixed in: `account-numbers`, `account-goals`, `account-meetings`, `account-issues`, `account-values`, `account-focus`, `account-targets`, `account-marketing`, `account-leadership`, `account-annual`, `account-quarterly`, `account-checkins`. Each now loads `js/active-org.js` and filters by `organisations.subscription_id = activeSub.id` when an active subscription is set. All 12 patched with one Python sweep so the wording is identical and the pattern is stable.
- **EOS de-jargoning.** User asked: "check the wording for EOs and change anything that sounds like EOs". Audited every HTML/JS/CSS file. Removed verbatim EOS terminology from user-facing copy:
  - `learning-vault.html`: "How to Run Level 10 Meetings" → "How to Run Weekly Team Meetings" (90-minute reference dropped); "3–7 quarterly Rocks" → "3–7 quarterly priorities".
  - `run-meeting.html`: agenda item 4 "Customer & Employee Headlines" → "Customer & Team Highlights"; agenda item 6 "Issues — Identify, Discuss, Solve" → "Issues — Discuss & Resolve".
  - `marketing-strategy.html`: "Our three uniques are…" → "What makes us different is…"; "Our Proven Process" → "Our Process".
  - `targets.html`, `one-page-plan.html`, `account-targets.html`, `account-plans.html`: "3-Year Picture" → "3-Year Outlook" (4 files).
  - `run-annual-session.html` area card: "Update 10-Year + 3-Year Picture" → "Update 10-Year + 3-Year Outlook".
  - **The 17 team-checkin questions** (identical block in `team-checkin.html` / `run-annual-session.html` / `run-quarterly-session.html`) rewritten end-to-end. Position and meaning preserved so the 1-5 scores stored in `team_checkins.scores` still map to the same conceptual statement, but the wording dropped: "Accountability Chart", "right seat" / "right people" / "get it, want it, capacity" (GWC), "Quarterly Projects", "Annual Meetings", "10-Year Target", "3-Year Target", and the "(core business)" / "(big, long-range business goal)" / "(organisational chart...)" parenthetical EOS glosses.
  - The DB table name `rocks` stays — renaming it would require an SQL migration touching every read/write path. The UI surfaces it as "Quarterly Goals" everywhere, which it already did.
- **`CLAUDE.md` substantially refreshed** to match current state. The "Data layer (localStorage demo stub)" section was deeply stale — every strategy worksheet and operations tool moved to Supabase several versions ago. Rewrote the data-layer section, file structure (added `one-page-operations.html`, `account-ops-plans.html`, every account-* page), Current Status, and the Architecture section. Renamed "Planned Architecture (Supabase Migration)" to "Architecture (Supabase + Multi-Tenant)" since the migration is done. Added a Multi-Tenant section documenting the active-subscription scoping pattern that every account-level page must follow. Added a "Wording / Tone" section banning EOS terms going forward. The Pricing Model + role definitions updated to include Coach (v0.5.110).
- **No SQL changes** in this version. All edits are front-end + docs.

---

## v0.5.115
- **New `account-ops-plans.html`** — the account-level companion to `one-page-operations.html` (v0.5.114). User asked: "is this added to the account level as well?" — it wasn't, now it is. Mirrors the existing strategy pattern: `one-page-plan.html` is the per-business strategy doc, `account-plans.html` is the carousel of all businesses' strategy docs; `one-page-operations.html` is the per-business ops doc, `account-ops-plans.html` is the carousel of all businesses' ops docs.
- **Carousel mechanics** — copied directly from `account-plans.html`: prev/next buttons with hint of the next business name, dots, keyboard arrow nav (don't hijack while typing), wraps at the ends.
- **Per-business render** — same 3-column doc as v0.5.114 (Quarterly Goals · Weekly Numbers · Open Issues), one card per business, doc-header carries the business name + today's date.
- **Data layer** — fans out 3 parallel queries (`rocks`, `scorecard_metrics`, `issues`) `.in('organisation_id', orgIds)` for all loaded businesses, plus one `scorecard_entries` query across every metric. Result is bucketed back per-org client-side. Reads the current quarter (`Q{n} {year}`) for rocks; reads the last 6 Monday-anchored weeks for the scorecard.
- **Multi-tenant scoping** — the membership query has `.eq('organisations.subscription_id', activeSubId)` when an active subscription is set, so a user who owns SARUBA + Acme + … only sees the businesses inside the currently-selected account. The active subscription is read via `window.activeOrg.getSubscription()` (added by v0.5.111).
- **Same scoping fix backported to `account-plans.html`** — that strategy carousel had the same pre-existing leak: without subscription scoping it pulled every team_membership the user had, mixing businesses across all their client accounts into one strip. Added the `if (subId) memQuery.eq('organisations.subscription_id', subId)` filter, plus loaded `js/active-org.js` (which it wasn't previously). The 11 other `account-*.html` carousel pages have the same bug and should get the same fix in a subsequent pass; out of scope for this version since the user's ask was specifically about the operations one-pager.
- **Linked from `account-operations.html`** via a new "View One-Page Operations — All Businesses" `.view-plan-btn` (style added inline, mirroring `account-strategy.html`).

---

## v0.5.114
- **New `one-page-operations.html`** — parallel to the existing `one-page-plan.html` (which covers strategy). User asked: "create a one page plan to house the goals, weekly numbers and the issues, similar for the one page plan."
- **Layout** — landscape A4, three columns of equal-ish weight (`1fr 1.55fr 1fr`):
  - **Column 1 — Quarterly Goals**: every row in `rocks` for the active org + current quarter (`Qn YYYY`), ordered by `sort_order`. Each goal shows status icon (🟢🟡🔴✅⚪), description, owner (teal), status label, and a navy "Company" pill when `company_rock = true`.
  - **Column 2 — Weekly Numbers**: mini-table of `scorecard_metrics` × the last 6 Monday-anchored weeks. Columns are Metric · Goal · 6 week-date headers. Each cell is teal (`hit`) or red (`miss`) against the metric's goal (when goal is non-null); empty cells are grey em-dashes. Owner is shown as a teal sub-line under the metric name.
  - **Column 3 — Open Issues**: numbered list of `issues` rows where `status = 'open'`, ordered by `created_at ASC`. Each issue shows description + owner sub-line. Count of open issues appears in the heading-meta.
- **Doc header** — business name (from `activeOrg.getName()` with a fallback Supabase lookup if the cache is empty), "Operations Snapshot" subtitle, today's date.
- **Data layer** — reads `rocks`, `scorecard_metrics`, `scorecard_entries`, `issues`, all scoped by `organisation_id = activeOrg.get()`. Same RLS gate as the per-page tools. No new schema, no SQL.
- **Empty states** — "No quarterly goals recorded." / "No weekly numbers recorded yet." / "No open issues. Nice work." per column when the active business has none.
- **Print** — same `@page A4 landscape` rules + print-only stylesheet as `one-page-plan.html`, so the print button drops to a clean one-page PDF.
- **Linked from `operations.html`** via a new "View One-Page Operations" `.view-plan-btn` (matching style added inline, mirroring `strategy.html`).

---

## v0.5.113
- **Fixed cross-account data leak on `business.html`.** User opened the business dashboard for a brand-new client account and saw Coach4U's sample 1-year goal ("Sign 20 new clients, launch group coaching program, hire first associate coach by Q3, and publish Signature Program workbook") plus Coach4U's core values pills (Integrity / Growth Mindset / Client First / Accountability) — even though no `targets` or `core_values` row existed in Supabase for the new org. Looked like multi-tenant data was bleeding across accounts; actually a pre-existing display bug that only became visible once a second account existed.
- **Root cause:** the 1-Year Goal and Core Values panels had hardcoded Coach4U sample text inside the HTML (`<div id="oneYearGoal">Sign 20 new clients…</div>`, `<span class="value-pill">Integrity</span>` etc.). The render JS only overwrote those defaults IF the Supabase query returned a row. For a new biz with no row, the JS bailed out of the `if (targets)` / `if (cv)` block and the hardcoded Coach4U text just stayed visible. Same pattern as the `one-page-plan.html` issue that v0.5.104 fixed — this was the other half.
- **Fix:** replaced the hardcoded sample text with empty-state placeholders ("No 1-year goal set yet." / "No core values set yet."). Render logic now toggles the placeholder explicitly — when Supabase has data, show it (in primary navy); when it doesn't, show the placeholder (in grey). Also clears the `oneYearMeta` line when no data, instead of leaving "Target: Dec 2025 · Revenue: $420K" stale.
- **Removed 5 dead localStorage seeds** from `ensureSeeds()`: `coach4u_core_values`, `coach4u_core_focus`, `coach4u_targets`, `coach4u_marketing_strategy`, `coach4u_leadership_team`. The strategy worksheets all moved to Supabase a while back, so these keys had no readers — `ensureSeeds()` was just writing Coach4U sample data into the user's localStorage on every page load, where it sat globally (not scoped to org or account) and could confuse anyone digging into devtools. The `coach4u_demo_meetings` / `coach4u_demo_rocks` / `coach4u_demo_scorecard` seeds stay — `operations.html` still wires off `coach4u_demo_meetings` for its "Run Weekly Meeting" button, and the other two stubs feed operations tools that haven't been migrated yet.
- **No SQL changes.** This was front-end-only.

---

## v0.5.112
- **Fixed UX inconsistency in the multi-tenant flow.** Reported by user: "I put in the first business and it went back to accounts. I put in the second business and it went to the business IAS Life." The two creation paths (`+ New client account` vs. `+ New Business`) had different post-create destinations — confusing, and the dashboard isn't the right landing place after creating a business anyway. Now both flows navigate to `business.html` for the newly-created business, so the user can start filling in worksheets / scorecard / etc. immediately.
- **`create_client_account` RPC — return type widened.** Was `RETURNS uuid` (the subscription_id only). Now `RETURNS TABLE(subscription_id uuid, organisation_id uuid)` so the front-end has both ids and can `activeOrg.set(newOrgId, bizName)` before navigating into the new business. The SQL delta gained a `DROP FUNCTION IF EXISTS public.create_client_account(text, text)` before the CREATE — Postgres won't let `CREATE OR REPLACE` change a function's return type, and the user already ran the previous version, so the DROP is required for the re-run to succeed. `supabase/v0.5.111-delta.sql` was edited in-place rather than spawning a v0.5.112-delta, since the v0.5.111 RPC and v0.5.112 RPC describe the same intent — anyone setting up fresh just runs the latest delta once.
- **Front-end** (`index.html`): the modal save handler now reads `row.subscription_id` + `row.organisation_id` from the RPC result, calls `activeOrg.setSubscription(...)` and `activeOrg.set(...)` for both, and redirects to `business.html` instead of `window.location.reload()`.
- **Re-run required:** `supabase/v0.5.111-delta.sql` in the Supabase SQL Editor. The DROP at the top makes it idempotent.

---

## v0.5.111
- **Multi-tenant — one user can own multiple client accounts.** User feedback: "I want to set up a test client from the top, replace SARUBA with the client's details". Built end-to-end so you (the business coach) can manage many clients from one login: each client is its own `subscriptions` row, you're the owner of each, you switch between them with a dropdown at the top of the dashboard.
- **`supabase/v0.5.111-delta.sql` — two changes:**
  - New RPC **`create_client_account(account_name, business_name)`** — always creates a new subscription (vs. `bootstrap_account_and_business` which reuses one if you have it). Also creates the first business + admin team_member row, all in one transaction.
  - **`bootstrap_organisation`** signature changed from `(business_name)` to `(business_name, subscription_id uuid DEFAULT NULL)`. If `subscription_id` is provided, validates ownership and targets that sub. If NULL, falls back to LIMIT 1 (backward compat for `setup.html`). The old single-arg function is dropped — `CREATE OR REPLACE` with the new signature would have created a separate function rather than replacing.
- **UI changes in `index.html`:**
  - New top-of-page **account switcher** — a `<select>` listing every subscription you own, plus a teal `+ New client account` button on the right. Hidden when you have only one account (still visible via the "Set up another client" UX once it's wired). Lives above the account header in its own `.acct-switcher` bar.
  - New **"Set up a new client account"** modal — two fields: client/account name + first business name. On submit calls `create_client_account` RPC, sets the new subscription as active in localStorage, reloads the dashboard.
  - **Active-subscription tracking** in `js/active-org.js`: extended to store/retrieve `coach4u_active_subscription_id` and `coach4u_active_subscription_name`. Switching account calls `setSubscription(...)` and clears the active-org cache (so a stale business name from another client doesn't bleed across).
  - **Data scoping**: the memberships query now uses Supabase's `!inner` join to filter by `organisations.subscription_id = activeSub.id`, so the dashboard only shows businesses inside the currently-selected account.
  - **Rename account** now uses a direct `UPDATE subscriptions SET name = ? WHERE id = ?` (RLS enforces ownership), scoped to the active subscription. The legacy `update_account_name` RPC updated every sub the user owned — wrong for multi-tenant.
  - **+ New Business** passes `subscription_id: sub.id` so the new business lands in the active client account, not an arbitrary one.
  - Empty-state for an account with no businesses now says "No businesses in *Acme Group* yet. Click + New Business to create one." (instead of redirecting to setup.html, which would have created a fresh subscription on top of everything else).
- **First-run guard** moved up: only redirects to `setup.html` if the user has zero subscriptions. An empty subscription (zero businesses) shows the friendly empty state instead.
- **No schema changes** — `subscriptions.owner_user_id` already supported multiple per user (the index is non-unique). RLS policies on subscriptions already allowed owner reads/inserts/updates of their own rows.
- **Next test client flow:** sign in → top switcher → **+ New client account** → enter client's account name + first business name → start populating. Repeat per client. Switch between them via the dropdown.

---

## v0.5.110
- **Added the Coach role** — admin-equivalent for data/team operations, intended to be exempt from per-seat billing when billing is wired. Use case: you (the business coach) live inside a client's account, edit alongside them, but shouldn't consume one of the client's 3 included paid seats. This was the locked-in plan from the conversation around v0.5.107 — now built end-to-end.
- **What a Coach can do:** edit every data table (worksheets, scorecard, goals, meetings, issues, planning sessions), invite/remove other team members. **What a Coach CANNOT do:** rename or delete the business itself — those stay admin-only because they're business-lifecycle actions tied to the subscription owner.
- **Schema delta — `supabase/v0.5.110-delta.sql` (paste-and-run in Supabase SQL Editor):**
  - `ALTER team_members` CHECK constraint to allow `role IN ('admin', 'coach', 'member')` (was `'admin','member'`)
  - `CREATE OR REPLACE FUNCTION user_admin_org_ids(uid)` to return orgs where role is `admin` OR `coach` — this single change cascades through every data-table RLS policy that uses the helper, granting coaches admin-write access without per-table edits
  - `CREATE OR REPLACE FUNCTION invite_team_member()` — accepts `'coach'` in the role validation; the admin-check now allows admin OR coach to invite
  - `CREATE OR REPLACE FUNCTION remove_team_member()` — same admin-or-coach allowance; the "don't remove the last admin" guard still only counts admins (coaches don't satisfy the admin requirement for that org)
  - `rename_business()` and `delete_business()` are LEFT untouched — those check role='admin' directly (not via the helper), so they remain admin-only as designed
- **`schema.sql`** updated in lockstep so future fresh deployments have the right shape from the start.
- **UI in `index.html`:**
  - Invite modal: third option "Coach — admin rights, not billed as a user" with help text below explaining when to use it ("for service providers who edit alongside the team but shouldn't consume a paid seat")
  - New `.role-coach` pill style — purple (`#ede9fe` bg, `#6d28d9` text) for clear visual distinction from the blue Admin pill and grey Member pill
  - Two `myMemberships.filter(m => m.role === 'admin')` call sites updated to include `'coach'` so coaches see the team list across all their orgs and the invite-business picker shows orgs they coach for
  - The per-business `⋮` actions menu (Rename / Delete) is gated to `role === 'admin'` only — coaches don't see it, matching the SQL gating
- **No client-side billing logic changes** because billing isn't wired up yet. When it lands (subscription seat count), the rule will be: count team_members where `status='active' AND role != 'coach'` for the seat tally.

---

## v0.5.109
- **Extended the team-member dropdown to the other 3 free-text owner fields** — completes the v0.5.108 pattern. Now consistent across every owner field in the app: every "who's responsible?" picker is a select populated from the active org's `team_members`, so reports can `GROUP BY owner` reliably.
- **Files migrated (3):**
  - `scorecard.html` — `metric-owner` in the Add/Edit Metric modal (was `<input type="text" placeholder="Name">`)
  - `issues.html` — `issue-owner` in the Add/Edit Issue modal (was `<input type="text" placeholder="Who raised this?">`)
  - `run-meeting.html` — `todo-owner` in the inline "Add a to-do" row at the bottom of the To-Dos list (was `<input type="text" placeholder="Owner" style="max-width:120px;">`). This one's special because the input is rendered inside a template string per call to `renderTodos()`, so it uses an `ownerSelectHtml(id, currentValue)` builder helper rather than the imperative `renderOwnerSelect(currentValue)` pattern used by the modals.
- **Same loader + fallback pattern** as v0.5.108: `loadOwnerOptions()` queries `team_members WHERE organisation_id = orgId AND status != 'removed'`, builds a deduped sorted list (preferring `display_name`, falling back to `invited_email`). When editing an existing row whose owner doesn't match a current team member, the option "Name (not on team)" is appended so legacy values aren't lost.
- **No schema changes.** Values still stored as text in `scorecard_metrics.owner`, `issues.owner`, `meeting_todos.owner`. RLS untouched.
- **Architectural detail:** for `run-meeting.html`, the IIFE needed careful re-closing (`})()`) and the helpers were added at module-scope after the IIFE. `OWNER_NAMES` and `loadOwnerOptions` / `ownerSelectHtml` are accessible from `renderTodos` because the IIFE pauses at its first `await`, letting the script's top-level continue executing past the IIFE call before `renderTodos` is ever invoked.

---

## v0.5.108
- **Quarterly Goals owner field is now a dropdown of the active org's team members** instead of a free-text input. User feedback: with the old text field, typos like "cath" vs "Cath" prevented reliable per-user reporting — "show me all of Cath's goals" wouldn't work because the values were inconsistent.
- **How it works:**
  - On page load, `loadOwnerOptions()` queries `team_members` for the active org (excluding `status='removed'`) and builds a deduped, sorted list of names — using `display_name` first, falling back to `invited_email` if no display name has been set.
  - The Add / Edit Goal modal's Owner field renders as `<select>` with "— Unassigned —" + each team member name.
  - When editing a rock whose `owner` is a legacy free-text value (e.g. a name that's no longer on the team), the select appends a one-off option labelled "Name (not on team)" so the original value isn't lost.
- **No schema change** — the saved value is still text in `rocks.owner`. The change is purely UI-side. Reports against canonical owner names (`GROUP BY owner`) now produce correct counts because the strings are constrained to the team list.
- **Same pattern can be applied later** to `scorecard_metrics.owner`, `meeting_todos.owner`, `issues.owner` — they're all free-text today. Doing them in a follow-up if requested.

---

## v0.5.107
- **Bug fix: every "Send invite" click failed with `column reference "role" is ambiguous`.** The `invite_team_member(business_id, email, role, display_name)` RPC has a parameter named `role`, and the `team_members` table has a `role` column. The admin-check inside the function used the unqualified `role` reference, which Postgres flagged as ambiguous and refused to run.
- **Fix:** qualified every column reference inside the function as `team_members.role` / `team_members.organisation_id` / `team_members.user_id` / `team_members.status` / `team_members.invited_email`, plus `auth.users.email` in the user-lookup query. The function signature and behaviour are unchanged.
- **Requires SQL:** see `supabase/v0.5.107-delta.sql` — paste the entire file into the Supabase SQL Editor and run once. The `CREATE OR REPLACE FUNCTION` replaces the function in place. No data migration.
- **Verified the fix matches `schema.sql`** — both are now in sync, so any future fresh deployment of the schema will already be correct.

---

## v0.5.106
- **Mobile responsive fixes for the standardized navy header (v0.5.105).** With "Your Business Coach" + back-link + biz-pill + Sign Out all in the same bar, the worst-case width at ~390px (iPhone) added up to ~415px — overflow / wrap territory. Audited the 22 navy-header pages: none of them have inline header CSS, so the fix is purely in `css/style.css`.
- **Changes in `css/style.css`:**
  - `@media (max-width: 640px)` — tightened `.header-inner` gap from 16px → 8px, `.header-left` gap from 16px → 10px with `min-width: 0; flex: 1 1 auto` so it can shrink. `.header-title` dropped from 17px → 16px with `white-space: nowrap; overflow: hidden; text-overflow: ellipsis` so it truncates instead of overflowing. `.header-back` and `.sign-out-btn` get `flex-shrink: 0; white-space: nowrap` so they stay intact. Sign Out padding shrunk 5px 10px → 5px 9px and font 13px → 12px.
  - `@media (max-width: 480px)` — `.header-title` to 14px. `.biz-pill` font 11px → 10px, padding 3px 8px → 3px 7px, max-width 140px → 110px.
  - `@media (max-width: 400px)` — new breakpoint just for tight phones. `.header-left` gap → 8px, `.header-title` → 13px, `.biz-pill` max-width → 90px, `.header-back` → 12px.
- **Bottom-nav** (5 items: Home / Planning / Strategy / Operations / Learn) was already handled — each `.bottom-nav-item` uses `flex: 1`, so 5 even slots fit on any phone width down to ~320px.
- **No per-page HTML changes** — all 22 navy-header pages share `css/style.css`, so the single CSS update fixes them all.

---

## v0.5.105
- **Every navy site-header now says "Your Business Coach"** instead of the page-specific name. User feedback: with the same navy bar showing different titles per page (Planning, Strategy, Core Values, etc.), there was no consistent brand anchor. The page-specific name was also redundant with the body subheading (`<h1 class="ws-title">🗺️ Planning</h1>` etc.) right below it.
- **The header now reads identically on every business-level and account-level hub/worksheet page:** `← Back · Your Business Coach · [🏢 Active Business pill]`. Context comes from the back-link target (Home / Account / Strategy / etc.) and the body's page-intro `<h1>` (which already exists on every page — `core-values.html`'s "⭐ Core Values", `planning.html`'s "🗺️ Planning", `scorecard.html`'s "📊 Weekly Numbers", etc.).
- **Files updated (22):** `business.html`, `index.html`, `account-strategy.html`, `account-planning.html`, `account-operations.html`, `strategy.html`, `planning.html`, `operations.html`, `learning-vault.html`, `core-values.html`, `core-focus.html`, `targets.html`, `marketing-strategy.html`, `leadership-team.html`, `scorecard.html`, `goals.html`, `meeting.html`, `run-meeting.html`, `issues.html`, `annual-sessions.html`, `quarterly-sessions.html`, `run-annual-session.html`, `run-quarterly-session.html`, `team-checkin.html`.
- **One ordered sed pass:** `s|<span class="header-title">[^<]*</span>|<span class="header-title">Your Business Coach</span>|g` across all root HTML files. The biz-pill (`#activeBizName`) markup that v0.5.98 added is unaffected — it still sits right after the header-title and renders `🏢 [Business Name]` on business-level pages.
- **Not touched:** account-level carousel leaf pages (`account-plans`, `account-values`, etc.) use a separate white `.screen-toolbar` pattern (toolbar-back + toolbar-title), not the navy `site-header`. Their toolbar titles are page-specific by design ("One-Page Plans — All Businesses" etc.) and weren't part of the user's "dark blue area" feedback. Same for `404.html`, `offline.html`, `inactive.html`, `forgot-password.html`, `reset-password.html`, `login.html` (no header) and `setup.html`.

---

## v0.5.104
- **Stripped hardcoded sample text from `one-page-plan.html`.** This was the root cause of the user-reported "the previous dummy data is still appearing". The page's body had Coach4U-flavoured sample text baked into the HTML (Integrity / Growth mindset / Client first / Accountability pills; "To help business owners build thriving…" purpose; "$1.2M" 3-year revenue; etc.). The v0.5.99 migration swapped the data source from localStorage to Supabase but kept the render helpers as overlays — `setText` / `renderValuesPills` / `renderNumList` only OVERWROTE the DOM when the field had a value, so when the Supabase row was empty (e.g. a fresh business), the hardcoded fallback stayed visible. Looked like the data had migrated; was actually static markup.
- **Cleared every `opp-*` element to empty / `&mdash;`** so the doc starts with no fake content baked in. Including the doc-header `Your Business Name` → bound to active-org name; doc-year `2025 – 2035` → `currentYear – currentYear+10`.
- **Helpers updated to always render with placeholders:**
  - `setText(id, value, placeholder)` now always touches the DOM. Empty value → renders the placeholder (default `—`) with a `.empty` class for muted-italic styling.
  - `renderNumList(id, raw, emptyLabel)` renders a single muted `<li>` with the empty label when no items.
  - `renderValuesPills(data)` adds an `.empty-pills` class and "No core values recorded yet." text when no values.
- **CSS additions:** `.field-value.empty` / `.fin-cell .field-value.empty` / `.num-list.empty-list` / `.values-pills.empty-pills` — all muted grey italic.
- **Org name fetch:** init reads `window.activeOrg.getName()` first. If the cache is empty (e.g. user bookmarked the URL), it adds a 6th parallel query to `organisations` for the name as a fallback so the doc-header always populates.
- **No behaviour change** when the Supabase row IS filled — those values still render the same way.

---

## v0.5.103
- **Removed the stale "data-layer migration pending" banner from all 13 account-level carousel pages.** The yellow `data-banner` was introduced in v0.5.91 / v0.5.96 when the cross-business carousel pages shipped before the worksheet pages were wired to Supabase. After the v0.5.99–v0.5.102 migration the banner became wrong: it kept firing whenever every business returned empty data, but that's no longer "data layer pending" — it's just "no one's filled in this worksheet yet", which the per-card empty-state placeholders (e.g. "No core values recorded yet") already communicate clearly.
- **Mechanics:** stripped the `<div id="dataBanner">…</div>` markup AND the `if (!anyData) document.getElementById('dataBanner').style.display = 'block'` JS toggle from each of the 13 carousel pages: `account-plans`, `account-values`, `account-focus`, `account-targets`, `account-marketing`, `account-leadership`, `account-annual`, `account-quarterly`, `account-checkins`, `account-numbers`, `account-goals`, `account-meetings`, `account-issues`. The `.data-banner` CSS class definitions are left in place as harmless dead code.
- **No other functional changes.** Carousels still work end-to-end; empty cards still show "— not recorded —" / "No X recorded yet" inline; the share-link experience is unchanged.

---

## v0.5.102
- **`team-checkin.html` wired to Supabase — login required.** The deferred item from v0.5.101 is now done. The form is no longer anonymous; respondents sign in with their Supabase account, which lets the page validate them via RLS and stamp `team_checkins.user_id` properly. Matches the "team-scoped, role-based" architecture documented in `CLAUDE.md`.
- **New flow:**
  1. Recipient clicks the share link `team-checkin.html?session={uuid}&type=annual|quarterly`.
  2. Page validates the URL params. Missing / malformed → "Invalid check-in link" message.
  3. `supabase.auth.getUser()` — if no session, redirects to `login.html?returnTo=<current URL>`. After successful sign-in, `login.html` redirects back to the check-in.
  4. Fetches the session from `annual_sessions` or `quarterly_sessions` (single query). RLS naturally enforces membership — if the signed-in user isn't a member of the owning org, the query returns nothing → "You don't have access to this check-in" with a "Sign in as a different user" link.
  5. Queries `team_members` for `display_name` + active membership confirmation.
  6. Checks `team_checkins` for an existing submission by this user for this session. If found → "Already submitted on {date}" — resubmission blocked for MVP.
  7. Otherwise renders the 17-question form with the name field pre-filled from `team_members.display_name` (falling back to the user's email prefix).
  8. On submit → `INSERT INTO team_checkins` with `organisation_id`, `session_id`, `session_type`, `user_id = auth.uid()`, `name`, `role`, `scores` (17-int array), `comments` (17-string array). RLS policy "members insert own team_checkin" handles the WITH CHECK.
- **`login.html` gains `?returnTo=` support.** Reads the param, validates it's same-origin via the URL constructor, and redirects there instead of `index.html` after sign-in (or pre-resolves the session check at page load). Falls back to `index.html` if the param is missing or unsafe.
- **No SQL changes.** The RLS policies for `team_checkins` (`members read team_checkins`, `members insert own team_checkin`, `admins update/delete team_checkins`) were already in the original schema — they just didn't get exercised because the form was localStorage-only.
- **URL shape unchanged.** The share link generated by `run-annual-session.html` / `run-quarterly-session.html` (uuid-based since v0.5.101) keeps working — the page now expects string ids instead of `parseInt`'d numerics.
- **Workspace results light up automatically.** Now that team members write to `team_checkins`, the aggregated read in `run-annual-session.html` / `run-quarterly-session.html` (and the cross-business `account-checkins.html` carousel) shows real responses instead of "No responses yet".
- **Header now includes a "Sign Out" button** so a user who's signed in as the wrong account can swap users without leaving the page.
- **localStorage stub removed.** The old `coach4u_team_checkins` localStorage key is no longer written to. Any existing values are ignored (fresh-data approach, same as the other batches).
- **Data-layer migration complete.** All five batches are now live: Strategy (v0.5.99) → Operations (v0.5.100) → Planning admin (v0.5.101) → Team check-ins (v0.5.102). Every business-level page is on Supabase, scoped by `coach4u_active_org_id` or by URL param + RLS validation.

---

## v0.5.101
- **Planning batch wired to Supabase.** The 4 planning admin pages (`annual-sessions.html`, `run-annual-session.html`, `quarterly-sessions.html`, `run-quarterly-session.html`) are no longer backed by `localStorage` — they now read and write directly to the `annual_sessions` / `quarterly_sessions` / `team_checkins` Supabase tables, scoped by the active organisation. This is the third slice of the data-layer migration (strategy batch in v0.5.99, operations batch in v0.5.100).
- **Fresh-data approach — no localStorage migration.** Consistent with the locked plan, this migration does NOT copy old `coach4u_annual_sessions` / `coach4u_quarterly_sessions` / `coach4u_team_checkins` values into Supabase. New businesses see no sessions until they create one via the "+ New Annual/Quarterly Session" button. The legacy localStorage keys are left in place but unread.
- **The 4 admin pages migrated:**
  - `annual-sessions.html` → `SELECT * FROM annual_sessions WHERE organisation_id = orgId ORDER BY session_date DESC`. The "+ New Annual Session" button INSERTs a new row (today's date, current year, status `scheduled`, empty `attendance`, empty `areas_completed` jsonb) and redirects to `run-annual-session.html?id={uuid}`. Session ids are uuids returned by Postgres `gen_random_uuid()` — the prior `Date.now()*1000+random` numeric id scheme is gone.
  - `run-annual-session.html` → loads a single session by uuid (`.maybeSingle()`) plus its team check-ins (`SELECT * FROM team_checkins WHERE session_id = id AND session_type = 'annual'`). Attendance textarea: 300ms-debounced `UPDATE annual_sessions SET attendance = ? WHERE id = ?`. Area checklist (4 areas): on toggle, full `areas_completed` jsonb is recomputed and immediately upserted; UI state is rolled back on save error. Status dropdown and timer Start/Stop also UPDATE the row. Aggregated check-in results (count, per-question avg with red/amber/green dots, expandable comments) preserved 1:1 — only the data source swapped.
  - `quarterly-sessions.html` → same shape as annual-sessions but for `quarterly_sessions`. "+ New Quarterly Session" opens the existing modal (target quarter + date pickers), INSERTs with the chosen values + `target_quarter`, then redirects. The next-upcoming-quarter helper and `quarterEndDate` math kept as-is.
  - `run-quarterly-session.html` → same shape as run-annual-session but for `quarterly_sessions` with 3 areas instead of 4. Sets the active-session pill label to `(target_quarter || 'Quarterly') + ' Session'` on Start.
- **Per-page behaviour:**
  - **No-active-org guard** — every planning page calls `window.activeOrg.get()` after auth + membership check. No active org → `window.location.href = 'index.html'`.
  - **Workspace pages also guard on `?id=`** — `run-annual-session.html` with no id redirects to `annual-sessions.html`; `run-quarterly-session.html` with no id redirects to `quarterly-sessions.html`. Previously they showed an inline "no session selected" empty state; the redirect is cleaner and matches `run-meeting.html` (migrated in v0.5.100).
  - **Invalid session id** — if `?id={uuid}` doesn't match a row, the workspace shows a friendly "Session not found" message with a back-link to the list page. No crash.
  - **Load on init** — `Promise.all`-style parallel loads (session row + team_checkins) where applicable. Body opacity stays at 0 until the load resolves; set to 1 on success or error so a Supabase failure doesn't trap the user behind a blank page.
  - **Save on edit** — debounce on attendance (300ms), immediate on area checkbox toggle, status dropdown, timer transitions, INSERTs from "+ New Session" buttons.
  - **RLS reality** — admins write, members read. Member writes will hit RLS denial and be logged via `console.warn` + toast. Read-only mode deferred.
- **SEED removal.** The old `_annualSeed()` / `_quarterlySeed()` constants + `_annualLoad()` / `_quarterlySave()` localStorage helpers are deleted from the 4 admin pages. A short JS block comment at the top of each script preserves the previous sample-data shape for future reference. The numeric id scheme (`5001`, `5002`, `6001`, `6002`, `6003`) is gone — uuids only.
- **`coach4u_active_planning_session` localStorage key kept alive.** The floating "Resume Planning Session" pill (rendered by `js/active-session.js` on every main page) still uses this localStorage key to know which session to link back to. Workspace pages continue to call `window.activeSession.set('annual', sessionId, label)` on Start and `window.activeSession.clear()` on Complete. This is a UI hint, not the data of record — the actual session row lives in Supabase.
- **`js/active-session.js` fix.** Previously the pill's `isStillActive()` check read `coach4u_annual_sessions` / `coach4u_quarterly_sessions` localStorage to verify the underlying session was still in progress. With those keys no longer populated, the check would always fail and the pill would self-clear immediately after being set. Simplified `isStillActive()` to trust the pill's own record — the workspace pages call `window.activeSession.clear()` explicitly on completion / timer-stop, which is the correct source of truth for the pill's lifecycle.
- **`team-checkin.html` deferred.** The public, anonymous team check-in form is intentionally left unchanged in this version. Migrating it requires a separate design decision on how to handle anonymous INSERTs into `team_checkins`:
  - **(A)** Loosen RLS to allow anon INSERT after validating the session exists (needs an `EXISTS` clause referencing `annual_sessions` / `quarterly_sessions`).
  - **(B)** A SECURITY DEFINER RPC for anonymous submissions.
  - **(C)** Switch to the "team members must log in" model from the planned architecture (changes UX — no longer truly anonymous).
  - Until that decision lands, `team-checkin.html` still writes to `localStorage` (`coach4u_team_checkins`). The workspace pages now query the Supabase `team_checkins` table for the results display — so until `team-checkin.html` is migrated, the aggregated results section will show "No responses yet" for any new session. Existing localStorage check-ins are no longer surfaced (intentional: fresh-data approach).
- **Visual / UX unchanged.** Existing DOM IDs preserved (`session-status`, `attendance-input`, `areas-progress`, `ci-results`, `ci-comments-toggle`, `timer-btn`, `timer-elapsed`, `new-session-btn`, `new-session-modal`, etc.). Toast notifications still fire for save/update success and failure. The site-header / bottom-nav / `#activeBizName` business pill / Resume Planning Session pill — all unchanged. No frameworks added.
- **Account-level carousel pages light up automatically.** `account-annual.html`, `account-quarterly.html`, and `account-checkins.html` (added in v0.5.96 to aggregate planning data across all businesses) have been waiting for real writes — they now stop showing "data-layer-pending" as soon as any business creates a session.
- **Next:** the `team-checkin.html` migration is the last localStorage holdout for the planning subsystem. Once that lands (along with the design decision on anonymous-submit), the legacy `coach4u_*` localStorage keys can be retired entirely and `ensureSeeds()` in `business.html` removed.

---

## v0.5.100
- **Operations batch wired to Supabase.** The 4 operations tools (`scorecard.html`, `goals.html`, `meeting.html` + `run-meeting.html`, `issues.html`) are no longer backed by `localStorage` — they now read and write directly to the corresponding Supabase tables, scoped by the active organisation. This is the second slice of the data-layer migration (strategy batch shipped in v0.5.99).
- **Fresh-data approach — no localStorage migration.** Per the locked plan, this migration does NOT copy old `coach4u_demo_*` localStorage values into Supabase. New businesses see empty tools and fill them in fresh. The old localStorage keys are left in place untouched (the `ensureSeeds()` block in `business.html` still seeds them for legacy reasons, but the dashboard panels no longer read from them — they query Supabase instead).
- **The 5 operations pages migrated:**
  - `scorecard.html` → 2-table CRUD on `scorecard_metrics` + `scorecard_entries`. Loads metrics ordered by `sort_order`, then loads all entries for the visible 6-week window via `.in('metric_id', [...]).gte('week_date', oldest)`. Cell save uses `upsert({ metric_id, week_date, value }, { onConflict: 'metric_id,week_date' })`. Clearing a cell DELETEs by composite key. Metric add/edit/delete uses INSERT/UPDATE/DELETE; child entries are CASCADE-deleted via the FK. **Schema note:** the page's "measurement type" dropdown now uses the canonical `count|currency|percentage|score` values from the `scorecard_metrics.measurement_type` CHECK constraint (the old localStorage stub used `'number'` — switched to `'count'` to match the DB).
  - `goals.html` → CRUD on `rocks` filtered by `quarter = currentQuarter()`. Computes the current quarter in JS as `'Q' + (Math.floor(d.getMonth() / 3) + 1) + ' ' + d.getFullYear()`. Quarter dropdown now built dynamically (5-quarter window: previous, current, next 3) instead of being hardcoded to Q1–Q4 2026 + Q1 2027. Status options exposed in the modal include `not_started` to match the DB CHECK constraint. `company_rock` is now a real boolean (DB column type) rather than the old 0/1 integer; UI behavior unchanged. Add inserts with `sort_order = max + 1`; edit and delete by id.
  - `meeting.html` → list of meetings ordered by `meeting_date DESC`. "+ New Meeting" INSERTs into `meetings` with `status='scheduled'` and the user-chosen date + quarter, then redirects to `run-meeting.html?id={uuid}`. Quarter dropdown also built dynamically.
  - `run-meeting.html` → loads the meeting + its `meeting_headlines` + `meeting_todos` via `Promise.all`. CRUD on each child table is via INSERT/UPDATE/DELETE keyed by `id`. Status change (Scheduled / In Progress / Completed) updates `meetings.status`. The "Start Meeting" timer transitions status to `in_progress` on start and `completed` on stop. Rating buttons UPDATE `meetings.rating`. Notes "Save Notes" button UPDATEs `meetings.notes`. **Edge case noted:** the existing page used URL param `?id={numeric}`; we now use `?id={uuid}` — the page reads the raw string param and passes it through to Supabase queries unchanged. If no `id` is in the URL, `run-meeting.html` redirects to `meeting.html` (was: showed an empty-state message).
  - `issues.html` → CRUD on `issues` ordered by `created_at DESC`. The kanban Open/Resolved split is computed client-side from the result set. Owner filter is a client-side filter against the in-memory `_issues` list (was: refetched). Mark-as-resolved requires a solution per existing UX. Add inserts, edit updates, delete deletes by id.
- **Per-page behaviour:**
  - **No-active-org guard** — every operations page calls `window.activeOrg.get()` after auth + membership check. No active org → `window.location.href = 'index.html'`. `run-meeting.html` adds a second guard: no `?id=` URL param → `window.location.href = 'meeting.html'`.
  - **Load on init** — Single Supabase query per table scoped by `organisation_id` (or by parent foreign key for child tables). Use `Promise.all` for parallel loads where a page needs both parent + children (run-meeting + business.html dashboard).
  - **Save on edit** — Immediate save for buttons / checkboxes / Add / Delete. Modal-driven edits (goals, issues, metrics) save on the modal's Save button click. Cell edits in scorecard upsert immediately. Save errors are caught with `console.warn` and surfaced via toast — they don't crash the page.
  - **RLS reality** — admins write, members read. Member writes will hit RLS denial and be logged silently. Read-only mode is deferred until a later release.
- **`business.html` dashboard panels migrated.** The 3 panels and 2 stat tiles that previously read `coach4u_demo_*` localStorage now query Supabase:
  - **"Open Issues" stat tile** → `supabase.from('issues').select('id', { count: 'exact', head: true }).eq('organisation_id', orgId).eq('status', 'open')`.
  - **"Goals On Track" stat tile** → count of current-quarter rocks with status `on_track` or `done` over the total. Quarter computed from JS clock; no fallback-to-all-rocks hack (the old localStorage version had one because the seed quarter was hardcoded as Q2 2026 — no longer needed with real per-business data).
  - **"This Week" panel** → most recent meeting's open todos (`meeting_todos` where `done=false`, ordered by `created_at`, limited to 4). The "focus meeting" is the same one used for the "Next Meeting" tile and the meeting button link (this-week's Monday meeting, else next upcoming, else most recent). When no meeting exists the panel keeps its default "No todos for this week yet" copy.
  - **"This Quarter" panel** → rocks for the current quarter from Supabase, rendered with the same status-pill colors as before (`pill-green / pill-amber / pill-red / pill-grey`). Progress bar shows `on_track` count / total.
  - **"1-Year Goal" + "Core Values" panels** were already on Supabase as of v0.5.99 — left as-is; verified they still work after this pass.
  - `renderDashboard()` is now `async`, takes `orgId` as a param, runs 5 parallel queries via `Promise.all`, then a 6th query for todos once the focus meeting is known. Errors are logged via `console.warn`; partial failures don't trap the user behind a blank page.
- **`ensureSeeds()` left in place but unread.** The block that seeds the old `coach4u_demo_*` keys is still called on first visit. Reading from those keys for the dashboard panels is gone — they're now live Supabase queries. The seeds are harmless; they'll be removed in a future cleanup pass once we're sure no other page depends on them.
- **SEED removal in each tool.** Each operations page's old `_*Seed()` constant + `_*Load()` + `api()` function block (the localStorage demo stub from v0.5.50) has been deleted entirely. A short JS block comment at the top of each script preserves the previous sample data values for future reference. The `_LS_KEY` constants are gone. The `currentBusinessId = 1` hardcoded value is gone — now uses real `orgId` from `window.activeOrg.get()`.
- **Visual / UX unchanged.** Existing DOM field IDs preserved (cell-popover, metric-modal, goal-modal, issue-modal, agenda accordion, rating buttons, etc.). Toast notifications still fire for save success / failure. The site-header, bottom-nav, `#activeBizName` business pill — all unchanged. No frameworks added; each page remains a self-contained vanilla ES module with its own Supabase client init.
- **Account-level carousel pages light up automatically.** `account-numbers.html`, `account-goals.html`, `account-meetings.html`, and `account-issues.html` (added in earlier versions to aggregate operations data across all businesses) have been waiting for real writes — they now stop showing "data-layer-pending" as soon as any business uses a tool.
- **Next: v0.5.101+** continues the migration with the planning session workspaces (`annual-sessions.html` / `run-annual-session.html` / `quarterly-sessions.html` / `run-quarterly-session.html`) and the team check-in flow (`team-checkin.html` results aggregation). After that, the localStorage layer can be retired entirely and `ensureSeeds()` removed.

---

## v0.5.99
- **Strategy batch wired to Supabase.** The 5 strategy worksheets and the one-pager reader are no longer backed by `localStorage` — they read and write directly to Supabase, scoped by the active organisation. This is the first slice of the data-layer migration teed up in v0.5.97 / v0.5.98.
- **Fresh-data approach — no localStorage migration.** Per the locked plan, the migration does **not** copy old `coach4u_*` localStorage values into Supabase. New businesses see empty inputs and fill them in fresh. The old localStorage keys are left in place untouched (and the dashboard panels in `business.html` still seed them for sample-data display until that page is migrated separately).
- **The 6 files migrated:**
  - `core-values.html` → single-row upsert on `core_values` (PK `organisation_id`; 8 value columns). `value_1`..`value_8` map directly to the existing input `data-key` attributes.
  - `core-focus.html` → single-row upsert on `core_focus` (PK `organisation_id`; `purpose`, `niche`).
  - `targets.html` → single-row upsert on `targets` (PK `organisation_id`; 9 columns covering 10-year vision + 3-year picture + 1-year plan).
  - `marketing-strategy.html` → single-row upsert on `marketing_strategy` (PK `organisation_id`; `target_market`, `uniques`, `proven_process`, `guarantee`).
  - `leadership-team.html` → multi-row CRUD on `leadership_team_members` (uuid id, `name`, `role`, `responsibilities`, `placeholder`, `sort_order`). INSERT on Add Team Member, DELETE on the per-card trash icon, debounced UPDATE-by-id on field edits.
  - `one-page-plan.html` → READ-ONLY. Replaced the 5 localStorage reads with a single `Promise.all` of 5 Supabase queries (4 `.maybeSingle()` for the org-keyed tables + 1 `.order('sort_order')` for the team). DOM field IDs (`opp-*`) and rendering helpers (`setText` / `renderNumList` / `renderValuesPills` / `renderTeamTable`) are unchanged — only the data source swapped.
- **Per-page behaviour:**
  - **No-active-org guard** — after the auth/membership check, each page calls `window.activeOrg.get()`. No active org → `window.location.href = 'index.html'`. Bookmark-direct-to-worksheet without first picking a business now redirects cleanly to the account dashboard.
  - **Load on init** — `SELECT * FROM TABLE WHERE organisation_id = orgId` with `.maybeSingle()` for the 1-row tables, `.order('sort_order')` for `leadership_team_members`. Body opacity stays at 0 until the load resolves; on success or error it's set to 1 (so a load error doesn't trap the user behind a blank page).
  - **Save on edit** — 300ms debounce on text inputs and textareas, immediate save on Add / Delete. The save sends the full local state via `upsert({ organisation_id, ...data }, { onConflict: 'organisation_id' })` for the 1-row tables. Failures are caught with `console.warn` and don't crash the page — the user can keep typing and the next save attempt may succeed.
  - **RLS reality** — admins write, members read. If a member tries to type in a worksheet the upsert will return an RLS denial; we log it silently and leave the local state in place. Building a proper read-only mode is deferred until later.
- **SEED removal.** Each worksheet's old `SEED = { … }` constant + `loadData()` merge-missing-keys helper has been removed. The old sample-data values are preserved as a JS block comment at the top of the script for future reference. The `STORAGE_KEY` constants are gone too.
- **Leadership team UX preserved 1:1.** Existing card-with-edit-toggle UI, Add button at top, per-card edit + delete icons, "Save Leadership Team" footer button — all unchanged visually. Under the hood: every keystroke in the edit form schedules a debounced `UPDATE` keyed by row `id`; Add inserts a new row (with `sort_order = max + 1`) and returns the generated uuid; Delete removes by id. Pending debounce timers are flushed when the user exits edit mode or clicks Save, and cancelled when a row is deleted. The `placeholder` column is honored: the one-pager view filters placeholder rows out (matching the previous localStorage behaviour); the editable list still shows them so users can promote them once filled in.
- **Account-level carousel pages light up automatically.** `account-values.html`, `account-focus.html`, `account-targets.html`, `account-marketing.html`, `account-leadership.html`, and `account-plans.html` already read from the same 5 Supabase tables (added in v0.5.96). They've been waiting for real writes; now that the worksheets write, those pages stop showing "data-layer-pending" as soon as any business fills in any field.
- **No visual or UX changes elsewhere.** Existing DOM `data-key` and `opp-*` IDs untouched. `autoGrow` textarea behaviour preserved. `body { opacity: 0 }` initial-load pattern preserved. The site-header / bottom-nav / `#activeBizName` business-pill all unchanged. No frameworks added; each page stays a self-contained vanilla ES module with its own Supabase client init.
- **Next: v0.5.100+** continues the migration on the operations tools (`scorecard.html`, `goals.html`, `meeting.html` + `run-meeting.html`, `issues.html`) and the planning session workspaces. `business.html` dashboard panels stay on the localStorage seeds until those datasets land in Supabase too.

---

## v0.5.98
- **Every business-level page now shows a `🏢 [Business Name]` pill in its header.** Before this, all business-level pages (`strategy.html`, `core-values.html`, `scorecard.html`, etc.) looked structurally identical to their account-level counterparts (`account-strategy.html`, etc.) — same site-header, same navy bar, just a different page title. With multiple businesses under one account, the user couldn't tell at a glance which business they were currently editing. Now the business name is unmissable.
- **Visual:** small teal pill (`.biz-pill`) with 🏢 prefix, placed right after the `header-title` span in the site-header. Stands out clearly against the navy background. Empty state collapses to `display: none` so account-level pages (which don't include the pill markup) are unaffected. Mobile shrinks the pill to fit narrow screens.
- **State management:** `js/active-org.js` extended to track both the org ID and the org name in localStorage (`coach4u_active_org_id` + `coach4u_active_org_name`). The set/clear methods always update both in sync. New `renderHeader()` method finds `#activeBizName` and populates it; auto-runs on DOMContentLoaded.
- **Wiring:**
  - `index.html` (account dashboard): when a business card's "Open" button is clicked, calls `set(orgId, orgName)` instead of just `set(orgId)`. Also caches the first membership's name when no active org is set.
  - `business.html`: when it resolves the active org from memberships, calls `set(activeId, name)` so the cache is always fresh before navigation to child pages.
  - 19 other business-level pages: just need the `<span id="activeBizName" class="biz-pill"></span>` markup in their header + the `<script src="js/active-org.js" defer></script>` tag — both added via two sed passes. `one-page-plan.html` uses a sticky toolbar instead of `site-header`, so its pill goes after `.toolbar-title`.
- **Not added to** account-level pages (`index.html`, `account-strategy.html`, etc.) — they're already distinct via their "Account" header and "Across All Businesses" page intros.
- **Edge case:** if a user bookmarks a business-level page URL directly and lands without first going through the dashboard, the name might not be cached yet → pill is empty → `display: none` hides it gracefully. The normal flow (login → account dashboard → click Open → business pages) always primes the cache.

---

## v0.5.97
- **Cleanup pass before the data-layer migration.** Two changes shipped here.
- **(1) File rename — account dashboard is now the root `index.html`.**
  - `my-businesses.html` (account dashboard, post-login landing) → `index.html`
  - Former `index.html` (single-business dashboard) → `business.html`
  - Why: visiting the root URL was loading the business dashboard, which only made sense if you had a single active business already selected. The account dashboard is the true "home" — it shows every business, the stats, the team. Root URL now serves the account dashboard.
  - Update mechanics: two ordered `sed` passes across all HTML files. First pass replaced `index.html` URLs → `business.html` (in `href=`, `'…'`, `"…"` contexts). Second pass replaced `my-businesses.html` URLs → `index.html`. 38 HTML files modified; no broken references left after grep verification.
  - `setup.html` line 70 redirect (when a user with existing memberships hits the wizard) now goes to `index.html` (account picker) instead of `business.html` (specific biz), since multi-business users with no stale active org should land on the picker.
  - `business.html` already had the right guards: no memberships → setup, multi-biz + stale active org → `index.html`, single biz → use it.
  - GitHub Pages serves `/` from `index.html`, so the root URL `https://cathcoach4u.github.io/yourbusinesscoach/` now opens the SARUBA account dashboard directly.
- **(2) Dead CSS removed from the account dashboard.**
  - Stripped `.topic-section`, `.topic-section-title`, `.topic-grid`, `.topic-card`, `.tc-icon`, `.tc-name`, `.topic-card.available:hover`, `.topic-card.coming-soon`, `.coming-soon-pill`, `.available-pill` — all leftover from the v0.5.89 topic launcher that v0.5.95 removed.
  - Also stripped the placeholder comment that said "Hub navigation lives in the bottom-nav" — the bottom-nav speaks for itself.
- **Version label** moved to `business.html` footer (it travelled with the renamed file). CLAUDE.md's version-bump checklist updated to point to `business.html` instead of `index.html`.
- **Next: v0.5.98+** starts wiring the business-level worksheet pages to write to Supabase (fresh-data approach — no localStorage migration). Strategy batch first (5 worksheets + one-page-plan reader).

---

## v0.5.96
- **Built all 12 cross-business carousel leaf pages.** Every card on the 3 account-level hub pages (`account-strategy.html`, `account-planning.html`, `account-operations.html`) now opens to a real navigable page. Same carousel chrome as `account-plans.html`: sticky toolbar with "← Account" back-link + page title + Print/PDF button, page intro, optional yellow data-banner, prev/next buttons hinting the neighbour business name, centre showing current business name + "Business X of Y" + dot indicators, keyboard ArrowLeft / ArrowRight nav, print-current-view via `@media print` hiding everything except the active card. Each page is a leaf page (no bottom-nav), mirroring `one-page-plan.html` at the business level.
- **Strategy ×5:**
  - `account-values.html` — reads `core_values` (PK organisation_id, columns value_1..value_8); per-business card shows big teal pills for each non-empty value (up to 8) in a responsive grid; empty state "No core values recorded yet."
  - `account-focus.html` — reads `core_focus`; two-column layout (Purpose / Niche) that stacks on narrow screens, each in a teal-bordered block with uppercase label.
  - `account-targets.html` — reads `targets`; three sections — 10-Year Vision (text), 3-Year Picture (date/revenue/profit financial row + description), 1-Year Plan (date/revenue/profit row + numbered goals list).
  - `account-marketing.html` — reads `marketing_strategy`; four sections — Target Market, What Makes Us Different (numbered list from `uniques`), Our Process, Our Guarantee.
  - `account-leadership.html` — reads `leadership_team_members` (multi-row per org, ordered by `sort_order`, filtering out `placeholder = true`); list of name (navy bold) · role (teal bold) with responsibilities below.
- **Planning ×3:**
  - `account-annual.html` — reads `annual_sessions`; list ordered most-recent-first with date + year + status pill (green/amber/grey for completed/in_progress/scheduled) + "Areas completed: X of Y" computed from `areas_completed` jsonb (4 areas assumed).
  - `account-quarterly.html` — same shape as annual but uses `target_quarter` instead of year and 3 areas assumed.
  - `account-checkins.html` — reads `team_checkins`; 3-tile stat row (submissions count, overall avg score / 5, most recent submission date) + latest 3 contributors with their average scores. Defensive handling of empty `scores` arrays so a missing-data submission won't crash averaging.
- **Operations ×4:**
  - `account-numbers.html` — reads `scorecard_metrics` ordered by `sort_order`, then a single batched `scorecard_entries` query (`.in('metric_id', metricIds)`, descending by `week_date`) grouped client-side into the metricId → entries map. Per-business table: Metric · Owner | Goal | Most recent value | Last 4 weeks trend.
  - `account-goals.html` — reads `rocks`, filters to current quarter (computed in JS as `Q{n} YYYY`). Top of card: current quarter label + "X on track of Y total" summary. Each row: description (with 🏢 prefix for `company_rock`) + owner + colored status pill (done=green / on_track=teal / at_risk=amber / off_track=red / not_started=grey).
  - `account-meetings.html` — reads `meetings`, descending by `meeting_date`, capped at 10 per business. Each row: date + quarter + status pill + rating (only when status='completed' and rating set) + 1-line notes preview.
  - `account-issues.html` — reads `issues` filtered to `status='open'`, descending by `created_at`. Top banner: "Open issues: X". Each row: description + owner + raised date. Empty state celebrates: "No open issues for this business. 🎉"
- **Hub pages updated:** `account-strategy.html` (5 cards), `account-planning.html` (3 cards), and `account-operations.html` (4 cards) — all 12 previously coming-soon cards flipped to available. Pattern: removed `.coming-soon` modifier class and replaced `<span class="soon-pill">Coming soon</span>` with `<span class="act-arrow">›</span>`, matching the existing available-card style on the business-level hubs.
- **Data layer reality:** most worksheet/operations pages still save to localStorage; the Supabase tables exist (per `supabase/schema.sql`) but most queries currently return zero rows. Every new page shows the same yellow data-layer-pending banner as `account-plans.html` when all businesses return empty, with the per-page worksheet name customised. The banner disappears as soon as any business has real Supabase data.
- **Carousel edge cases:** zero businesses → "Create your first business" link to `setup.html`; one business → no prev/next buttons, just the single card; 2+ businesses → full carousel with dots + keyboard nav (arrow keys ignored when typing in inputs/textareas).

---

## v0.5.95
- **Removed the 4 hub cards from `my-businesses.html`.** They duplicated the bottom-nav added in v0.5.94 — same labels, same destinations, just bigger and higher up the page. With the bottom-nav doing the navigation, the dashboard is cleaner and the focus shifts back to what actually belongs on a dashboard: account info, stats, business snapshots, and team management.
- Dashboard now renders: account header (SARUBA + Rename) → stats row (Businesses / Users / Open Issues / Goals On Track) → per-business snapshot grid → users / team section.
- Dead CSS (`.hub-section`, `.hub-grid`, `.hub-card`, `.hub-icon`, `.hub-text`, `.hub-name`, `.hub-desc`, `.hub-arrow`) stripped from the style block. The 4 account hub pages (`account-strategy.html` etc.) are unchanged and still reachable from the bottom-nav.

---

## v0.5.94
- **Bottom-nav added to the account-level pages**, matching the business app's pattern. Same 5-item layout: Home / Planning / Strategy / Operations / Learn. The user request: "Build the 4 headings the same way you have in the others. Down the bottom." Confirmed the right destinations for each item.
- **Added to:**
  - `my-businesses.html` — active = Home
  - `account-strategy.html` — active = Strategy
  - `account-planning.html` — active = Planning
  - `account-operations.html` — active = Operations
- **Destinations:**
  - Home → `my-businesses.html` (account dashboard)
  - Planning → `account-planning.html`
  - Strategy → `account-strategy.html`
  - Operations → `account-operations.html`
  - Learn → `learning-vault.html` (shared with business app — learning content isn't business-scoped)
- **Not added to leaf carousel pages** like `account-plans.html` — those follow the `one-page-plan.html` pattern (sticky toolbar with "← Account" back-link replaces the bottom-nav, since the carousel UI needs vertical space at the bottom).
- `.container { padding-bottom: 90px; }` on the 4 nav-enabled pages so content doesn't hide behind the nav.

---

## v0.5.93
- **Account-level navigation now mirrors the business app's structure.** The owner's mental model is consistent: SARUBA (account) is structured like a single business — Planning, Strategy, Operations, Learn — just rolled up across every business.
- **`my-businesses.html` restructure:** the 16-card topic launcher is replaced with a clean **4-card hub grid** (Planning / Strategy / Operations / Learn). Bigger cards, accent border, icon + name + description + arrow — same visual language as `strategy.html` / `operations.html` / `planning.html` but more prominent (these are top-level navigation). Card order matches the business app's bottom-nav: Planning, Strategy, Operations, Learn.
- **3 new account-level hub pages** mirroring the business hubs:
  - `account-strategy.html` — copies `strategy.html`. CTA: "View One-Page Plans — All Businesses" (live). Cards: Core Values / Core Focus / Targets / Marketing Strategy / Leadership Team (all coming-soon).
  - `account-planning.html` — copies `planning.html`. Cards: Annual Planning / Quarterly Planning / Team Check-ins (all coming-soon).
  - `account-operations.html` — copies `operations.html`. Cards: Weekly Numbers / Quarter Goals / Meetings / Issues (all coming-soon).
- Each new hub uses the same `.activity-card` pattern as the business hubs, with a `.coming-soon` modifier (opacity 0.55, pointer-events: none, "Coming soon" pill, neutral border). Identical auth gate + Sign Out wiring.
- **"Learn" on the dashboard** links directly to `learning-vault.html` (no account-level hub needed — learning content is shared across all businesses).
- **Architecture is now 3 levels:**
  1. **Account dashboard** (`my-businesses.html`) — header + stats + 4 hub cards + businesses snapshot + users
  2. **Account hub pages** (`account-strategy.html` etc.) — list of cross-business views inside that theme
  3. **Account leaf pages** (`account-plans.html` etc.) — carousel: one business at a time with arrows/dots/keyboard nav
- All 4 hub-card destinations work. Only 1 of 12 leaf pages (`account-plans.html`) is built; the rest follow the same carousel template.

---

## v0.5.92
- **`account-plans.html` switched from "stack all businesses" to a carousel** — one business' one-pager visible at a time, arrows to step through. The v0.5.91 stacked-vertically approach was wrong: scrolling through 3 full one-pagers stacked is overwhelming, and the mental model is "look at one, then look at the next", not "see them all at once".
- **Carousel UI:**
  - Top nav bar (white card, navy buttons): **← Prev (Business name)** | _Current Business Name_ + "Business X of Y" + dot indicators | **(Business name) Next →**
  - The prev/next buttons preview the next/previous business name as a hint inside the button itself.
  - Dot indicators below the counter — click a dot to jump straight to that business.
  - Keyboard `ArrowLeft` / `ArrowRight` to step through (ignored when typing in inputs/textareas).
  - Single business in account → no arrows, just the name + "Your only business" line.
- **Print now prints just the current view** (not all businesses) — `@media print` hides the carousel nav + intro + banner + toolbar, so you get exactly the one one-pager you're looking at as a single landscape A4 page.
- All other v0.5.91 behaviour preserved: Supabase queries scoped to caller's orgs, empty-field placeholders, yellow data-layer-pending banner when all businesses return empty, "← Account" back link.

---

## v0.5.91
- **New page: `account-plans.html` — cross-business One-Page Plans view.** The first real cross-business topic page; the proof-of-concept for the topic launcher (v0.5.89).
- **Use case:** owner running a board / strategy meeting wants to see every business' one-pager side-by-side without drilling into each one individually. Topic-first navigation: "I want to compare plans" → not "I want to open Business A, then Business B".
- **Layout:** account-level page (no business bottom-nav, no "← Home" — "← Account" back link to `my-businesses.html`). Stacked vertically: one compact one-pager card per business, in alphabetical order by name. Each card reuses the same 3-column layout as the per-business `one-page-plan.html` (Who We Are / Where We Are Going / How We Go to Market).
- **Data flow:** loads the caller's active `team_members` rows, then fires 5 parallel Supabase queries scoped to that orgId set — `core_values`, `core_focus`, `targets`, `marketing_strategy`, `leadership_team_members`. Builds a per-org data map and renders one card per business. Empty fields render as muted italic "— not recorded —" placeholders instead of looking broken.
- **Data-layer reality:** worksheet pages still save to localStorage (Supabase wiring lands in v0.5.94). So today the cross-business view will show every business as empty. To make this obvious rather than confusing, when every business returns zero strategy data the page shows a yellow banner: "Heads up: strategy worksheets currently save locally on each business. Once the data layer migration lands (v0.5.94), edits sync to Supabase and this page populates automatically."
- **Print:** landscape A4, page-break-after each business so a 3-business account prints to 3 pages. Toolbar Print/PDF button. Mobile shows a teal hint to scroll right inside each plan card for the 3-column doc.
- **Topic launcher update:** `account-plans.html` card on `my-businesses.html` flipped from `coming-soon` to `available` with an "Open" pill. 4 available cards on the dashboard now: Learning Vault, Businesses, Team, One-Page Plans. 12 still coming-soon (the rest of the cross-business pages).
- **Why this one first:** validates the navigation pattern (topic-first, account-level page, "← Account" back link), the visual pattern (compact card per business), and the data pattern (parallel queries scoped to orgId set, empty-state handling, banner for data-layer-pending). The remaining 12 cross-business pages follow the same template.

---

## v0.5.90
- **Topic launcher fix — Businesses & Team are now `available` cards, not "Coming soon".** The v0.5.89 agent over-applied the "only Learning Vault is clickable" rule and marked all three "Learning & Account" cards as coming-soon. But the Businesses and Team sections exist right below on the same page — their `#businesses` and `#team` anchors are real navigation, not future work. Flipped both cards from `class="topic-card coming-soon"` to `class="topic-card available"` with an "Open" pill.
- Dashboard now has **3 available topic cards** (Learning Vault → `learning-vault.html`, Businesses → `#businesses` anchor, Team → `#team` anchor) and **13 coming-soon** (the cross-business pages still to be built in v0.5.91+).
- No other functional changes. VERSION / `sw.js` / `index.html` footer all bumped to v0.5.90 per the convention.

---

## v0.5.89
- **SARUBA dashboard restructured from a per-business snapshot view into a topic launcher.** `my-businesses.html` now leads with **14 topic cards** organised into 4 themed sections — Strategy / Operations / Planning / Learning & Account — each card a future cross-business view (e.g. "see Core Values for every business side-by-side"). This is the structural step; the actual cross-business pages get built one-by-one in v0.5.90+.
- **Topic card sections** (14 cards total):
  - **📋 Strategy** (6): One-Page Plans, Core Values, Core Focus, Targets, Marketing, Leadership
  - **🎯 Operations** (4): Quarter Goals, Weekly Numbers, Issues, Meetings
  - **🗓️ Planning** (3): Annual Sessions, Quarterly Sessions, Team Check-ins
  - **📚 Learning & Account** (3): Learning Vault, Businesses, Team
- **Topic card states**:
  - **`.coming-soon`** — opacity 0.55, `pointer-events: none`, grey "Coming soon" pill. All 13 cross-business cards.
  - **`.available`** — full opacity, hover lift, teal "Open" pill. **Learning Vault → `learning-vault.html`** + Businesses / Team → scroll-anchor to existing sections on the same page (`#businesses`, `#team`).
- **Destination URLs locked in** for the future cards so v0.5.90+ only has to ship the pages: `account-plans.html`, `account-values.html`, `account-focus.html`, `account-targets.html`, `account-marketing.html`, `account-leadership.html`, `account-goals.html`, `account-numbers.html`, `account-issues.html`, `account-meetings.html`, `account-annual.html`, `account-quarterly.html`, `account-checkins.html`.
- **Account-level scoping cleaned up** — `my-businesses.html` no longer has the business-tools bottom-nav (Home / Planning / Strategy / Operations / Learn) or the "← Home" back link in the site-header. The account dashboard is the top of the hierarchy; there's nothing above. Header is now just **"Account"** + Sign Out.
- **Business dashboard (`index.html`) gains a "← Account" back link** so users can navigate upward from their business view to SARUBA. Other per-business pages (planning.html, strategy.html, operations.html, all worksheets, all tools) keep their existing "← Home" back link — those still point to the business dashboard, which is correct.
- **Existing snapshot cards + team section retained** below the topic launcher (now anchored at `#businesses` and `#team`) so the v0.5.88 snapshot view is still one scroll away. Per-business cards keep their snapshot grid, ⋮ menu (Rename / Delete), and "Open ›" button — full v0.5.88 functionality intact, just no longer the centrepiece.
- **CSS additions**: `.topic-section`, `.topic-section-title`, `.topic-grid`, `.topic-card`, `.topic-card.coming-soon`, `.topic-card.available`, `.coming-soon-pill`, `.available-pill`. Responsive grid: 3 cols desktop, 2 cols tablet, 1 col phone.
- No SQL changes. No data layer changes.

## v0.5.88
- **SARUBA account dashboard rebuilt as an owner's snapshot view.** `my-businesses.html` used to be a business-list switcher (name + role pill + Open ›). It's now a real overview surface so the account holder sees "what's going on across my businesses" without drilling in.
- **Stats row expanded from 2 to 4 tiles**: Businesses / Users / **Open Issues** (NEW — account-level sum of `issues.status='open'` across every org the caller is in) / **Goals On Track** (NEW — `<onTrack>/<total>` rocks for the current quarter, summed across all orgs). Tiles wrap to a 2×2 grid under 480px.
- **Per-business cards are now snapshot "report cards"** with a 3-cell grid (stacks to 1 column under 600px):
  - **📊 Revenue (1yr)** — `targets.one_year_revenue` (e.g. "$420K") or "Not set"
  - **🎯 Quarter Goals** — `<onTrack> of <total>` rocks for `Q<n> YYYY` (current quarter format) or "0 of 0"
  - **⚠️ Open Issues** — count of `issues.status='open'` for that org
  - **📅 Next meeting** line below the grid — earliest `meetings.meeting_date` where status ≠ 'completed' AND date ≥ today, formatted as "Mon 19 May", or "None scheduled"
- **Fetching strategy**: a single `Promise.all` batches 5 queries (memberships team rows + the 4 new snapshot tables). Each of the snapshot queries uses `.in('organisation_id', orgIds)` — so it stays at 1 round-trip per table regardless of how many businesses the user has. Results are grouped client-side into a `snapshotByOrg` Map for O(1) lookup per card.
- **Goals on-track logic**: a rock counts as on-track if `status IN ('on_track','done','complete')` — matches the existing seed-data values.
- **Empty-state handling**: every snapshot field renders gracefully when the underlying tables return zero rows (still localStorage-backed in most pages). Revenue → "Not set", Goals → "0 of 0", Issues → "0", Next meeting → "None scheduled". No errors, no broken UI.
- **Header tweaks**: "Account overview — what's happening across your businesses." subhead replaces the previous "Manage every business and teammate". Section header is now "Your Businesses" / "Your Team (N)" — added a header-aligned `+ New Business` and `+ Invite User` button next to each section title for quicker access (the wide CTA buttons at the bottom of each section are unchanged).
- All admin-only functionality preserved: ⋮ menu (Rename / Delete), `bootstrap_organisation` / `rename_business` / `delete_business` / `invite_team_member` / `remove_team_member` RPC calls, `Open ›` → set active org + `index.html` navigation, "Rename account ›" link. No SQL changes — all schema already exists from v0.5.79 + v0.5.84.

## v0.5.87
- **Removed "Seats: X of Y" stat tile** from the SARUBA account dashboard. It duplicated the Users tile in plan-capacity framing — "1 of 3" felt ambiguous (status? error?). The stats row is now a clean 2-tile grid: **Businesses** + **Users**. Seat-allowance / billing context can surface later in a proper "Account / Billing" section when Stripe is wired up.

## v0.5.86
- **Removed the "Active" pill from `my-businesses.html` business cards.** Previously the page auto-marked one business as "Active" on every visit (the localStorage-default selection), which felt like phantom state — implied a business was open even when the user had just logged in and not done anything. Now the account dashboard is a clean list with role pills only. Users tap "Open ›" on a card to enter that business. The underlying `coach4u_active_org_id` localStorage mechanism is unchanged and still drives which business `index.html` and other tools load when navigated to directly.

## v0.5.85
- **Account dashboard is the first landing page after sign-in.** `login.html` now redirects to `my-businesses.html` (was `index.html`) on a successful sign-in AND when an existing session is detected. Every user lands on their SARUBA parent dashboard first, seeing all businesses, can switch into one, manage users, etc. before drilling into a specific business's data.
- **First-run guard added to `my-businesses.html`**: if a signed-in user has zero active `team_members` rows, the page auto-redirects to `setup.html` so the new-user wizard still fires. Avoids the awkward "empty businesses list" state for brand-new users.

## v0.5.84
- **SARUBA account dashboard** — `my-businesses.html` rebuilt from a simple switcher into the comprehensive parent dashboard:
  - Account header (existing — shows the subscription name)
  - **Stats row** (NEW) — 3 tiles: Businesses count, Users count (de-duplicated across the user's admin orgs + pending invites), Seats used / total
  - **Businesses section** — each card now has a "•••" menu (admin-only) with Rename and Delete actions. Click the row body to switch into that business and go to the dashboard
  - **Users section** (NEW) — lists all teammates the caller can see, grouped by user, with a role-pill per business + × to remove. "+ Invite User" button at section header opens a modal: email + display name + role + checkbox list of admin businesses to grant access to. Pending invites show with a "pending" pill until the invited person signs up.
- **5 new Supabase RPC functions** (`SECURITY DEFINER`, granted to `authenticated`):
  - `invite_team_member(business_id, email, role, display_name)` — admin-only. Creates `team_members` row. If the email already maps to an `auth.users` id, sets `user_id` + `status='active'` immediately. Otherwise stores `invited_email` + `status='pending'`.
  - `remove_team_member(member_id)` — admin-only. Soft-removes by setting `status='removed'`. Prevents removing yourself if you're the sole admin.
  - `rename_business(business_id, new_name)` — admin-only. `UPDATE organisations SET name = …`.
  - `delete_business(business_id)` — admin + subscription owner. `DELETE FROM organisations`. Cascades all team_members + domain data.
  - `link_pending_invites()` — trigger function on `auth.users INSERT`. Auto-converts pending invites matching the new user's email into active memberships.
- **Routing change**: in `index.html`, if the user has >1 membership AND no valid active org is selected, redirect to `my-businesses.html`. Single-business users still go straight to their dashboard. This makes the parent dashboard the natural landing page for multi-business users.

### SQL delta to paste
The new SQL is already appended to `supabase/schema.sql`. To apply, you can either re-paste the whole file (idempotent — DROP block at top handles re-runs) or paste just the new functions from lines 730 onwards.

## v0.5.83
- **Parent account / business hierarchy introduced.**
  - `subscriptions` now has a `name` column representing the account / license-holder name (e.g. "SARUBA").
  - Organisations under it are the operational businesses (e.g. "Coach4U Coaching", "Coach4U Development").
- **Two new Supabase RPC functions:**
  - `bootstrap_account_and_business(account_name, business_name)` — called by `setup.html` on first signup. Creates the subscription with the account name, creates the first organisation, makes the user the admin in one transaction.
  - `update_account_name(new_name)` — called by the "Rename account" modal on `my-businesses.html` so existing users can set their account name.
- **`setup.html` now asks for two names**: account / company (parent) + first business. Submits to `bootstrap_account_and_business`, redirects to `my-businesses.html` (the parent dashboard) instead of straight to the business dashboard.
- **`my-businesses.html` becomes the parent dashboard:**
  - Shows the account name at the top as the page heading.
  - "Rename account ›" link in the header opens a modal that calls `update_account_name`. Shows "Set account name" if the name is still null (handles existing v0.5.81 users).
- **Dashboard "Manage businesses ›" link relabelled to "Account dashboard ›"** to match the parent/child mental model.
- **`supabase/schema.sql` needs re-running OR a small delta** — chat message has the SQL delta block.

## v0.5.82
- **Dashboard "Manage businesses" link always visible.** Previously the link was only rendered when the user belonged to 2+ businesses, leaving single-business users with no in-app way to reach `my-businesses.html` to add their second business. Now the link always shows, with adaptive label: "Switch business ›" if the user has 2+ orgs, "Manage businesses ›" if they have 1.

## v0.5.81
- **New page `my-businesses.html`** — lists every organisation the user is an active member of with role pill, highlights the current active one, and has a "+ Create New Business" modal that calls the existing `bootstrap_organisation` RPC (handles both first business and additional). Tapping a different business sets it active and redirects back to the dashboard.
- **New helper `js/active-org.js`** — tiny module exposing `window.activeOrg.get() / set(orgId) / clear()` backed by `localStorage.coach4u_active_org_id`. Loaded via `<script defer>` on every page that needs to know which business is currently selected.
- **`index.html` (dashboard) extended**:
  - Resolves the user's team memberships on load.
  - Picks the active org (stored selection if still valid, else first).
  - Shows the business name at the top of the dashboard (replaces the static "Business Dashboard" heading).
  - Shows a "Switch business ›" link below the date when the user belongs to more than one business — link goes to `my-businesses.html`.
- **`setup.html`** sets the newly-created org as active immediately after creation, so the user lands on the dashboard with the correct business pre-selected.
- `sw.js` precache adds `js/active-org.js`.
- **Data layer still on localStorage** — every tool reads/writes localStorage as before. v0.5.83 will wire each tool's `api()` to read Supabase scoped by active org.

## v0.5.80
- **First-business setup flow.** New `setup.html` page asks a brand-new user for their business name. On submit it calls a single Supabase RPC (`bootstrap_organisation`) that creates the user's `subscriptions` row + first `organisations` row + admin `team_members` row in one transaction.
- **`bootstrap_organisation(business_name text)` function** added to `supabase/schema.sql`. Marked SECURITY DEFINER so it can write the bootstrap rows that the user's own RLS policies would block (you can't INSERT a team_member admin row when you have no admin team_member row yet). Also handles the case where a user already has a subscription and just wants to add another business — same function, different code path. Granted to the `authenticated` role only.
- **`index.html` auth flow extended.** After the membership-status check, it now looks up `team_members` for the user. If there's no active row, redirect to `setup.html`. Means existing accounts (no team_member yet) hit the wizard the next time they sign in.
- **`supabase/README.md` updated** to document the new bootstrap function with a JS call example.
- **App code still on localStorage for the data tools** — the wizard creates real Supabase rows but the worksheets / sessions / tools all keep using localStorage until v0.5.83.

## v0.5.79
- **Supabase schema written.** `supabase/schema.sql` is a complete clean-slate migration:
  - **DROPs** the old EOS-style tables (`businesses`, `vto`, `rocks`, `scorecard_metrics`, `scorecard_entries`, `meetings`, `meeting_headlines`, `meeting_todos`, `issues`, `seats`, `members`, `values_ratings`, `gwc_ratings`, `user_modules`, `organisations`). Preserves `public.users` (the membership-status gate).
  - **CREATEs** the new team-scoped schema: `subscriptions` (account-level), `organisations`, `team_members`; 5 strategy tables (`core_values`, `core_focus`, `targets`, `marketing_strategy`, `leadership_team_members`); operations (`scorecard_metrics`, `scorecard_entries`, `rocks`, `issues`); meetings (`meetings`, `meeting_headlines`, `meeting_todos`); planning sessions (`annual_sessions`, `quarterly_sessions`); `team_checkins`.
  - **RLS enabled** on every domain table. Two helper functions (`public.user_org_ids(uid)` and `public.user_admin_org_ids(uid)`) make every policy compact. Pattern: members read everything in their orgs; admins write. `team_checkins` is the only domain table where members can INSERT (submit their own check-in); everything else is admin-write.
  - **Indexes** on every FK + commonly-queried columns (subscription_id, organisation_id, quarter, session_date, week_date).
  - **One convenience view** (`v_active_team`) joining team_members + auth.users.users + organisations.
- **`supabase/README.md`** added with paste-and-run instructions + a quick RLS test you can run to verify policies work end-to-end.
- **App code unchanged** — still on localStorage. Wiring tools to Supabase queries begins at v0.5.83.

## v0.5.78
- **Captured the launch pricing model in CLAUDE.md.** New "Pricing Model" section locks in: $150/mo base license (1 business + 3 users included), $75/mo per additional business, $60/mo per additional user.
- **Global-user principle** explicitly documented: one person who's a member of 3 businesses still counts as 1 seat. Matches Notion / Slack / Linear conventions.
- **Schema implication captured**: `subscriptions` table lives at the account level (one subscription per buyer, owns N organisations). Replaces the per-org `seat_count` from the v0.5.75 schema sketch.
- Worked examples included for solo / small team / IAS-style holding / larger configurations.
- Docs-only change — no code touched.

## v0.5.77
- **`sw.js` precache trimmed.** Removed the UMD Supabase CDN URL (`https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js`) — every page consumes the ESM bundle since v0.5.76, so the UMD entry was dead bytes in the precache.

## v0.5.76
- **Pre-Supabase migration cleanup** — fixed all 10 items from the v0.5.74 audit so the codebase is clean before the Supabase data layer is wired in:
  1. **Session shape divergence resolved.** `coach4u_annual_sessions` and `coach4u_quarterly_sessions` now use ONE shape everywhere: `{ id, session_date, year/target_quarter, status, attendance, areas_completed }`. Dropped `agenda` + `rating` from index.html `ensureSeeds()`, the "+ New …" creators in `annual-sessions.html` / `quarterly-sessions.html`, the self-seeds in the run-session pages, and the `${s.rating ? '· …/10' : ''}` list-row fragments.
  2. **Meeting seed status aligned.** Meeting id 4001 is now `status:'completed'` in all 3 places (`index.html` ensureSeeds + `meeting.html` self-seed + `run-meeting.html` self-seed) with matching rating + notes.
  3. **Sign-out class fixed on 5 Ops pages.** `scorecard.html`, `goals.html`, `meeting.html`, `run-meeting.html`, `issues.html` were using `class="signOutBtn"` (rendered unstyled — only `.sign-out-btn` is in CSS). Now all use canonical `class="sign-out-btn" id="signOutBtn"`.
  4. **Dead links fixed.** `learn/values-discovery.html` final CTA → `../core-values.html` (was `../strategy/core-values.html` from before v0.5.45). `404.html` secondary button → `/index.html` (was `/dashboard.html`).
  5. **`ensureSeeds()` now seeds 4 previously-missing keys.** Dashboard pre-seeds `coach4u_core_focus`, `coach4u_marketing_strategy`, `coach4u_leadership_team`, `coach4u_demo_scorecard` (metrics + 6 weeks of sample entries) on first visit, using the same shapes the worksheet/tool pages expect.
  6. **`membership_status` check added to 10 pages.** Was missing on `planning.html`, all 5 Operations tools (`scorecard / goals / meeting / run-meeting / issues`), and all 4 Planning session pages (`annual-sessions / run-annual-session / quarterly-sessions / run-quarterly-session`). Inactive users could deep-link in; now they bounce to `inactive.html`.
  7. **`sw.js` precache cleaned.** Removed non-existent `dashboard.html`. Added `favicon.svg` + `js/active-session.js`. Removed dead `js/auth.js` + `js/supabase.js` entries.
  8. **Supabase SDK consolidated to ESM.** Converted 9 files from UMD (`<script src="…/umd/supabase.min.js">` + `window.supabase.createClient`) to ESM (`<script type="module">` + `import { createClient } from '…/+esm'`). Pages affected: `scorecard / goals / meeting / run-meeting / issues / annual-sessions / quarterly-sessions / run-annual-session / run-quarterly-session`. No inline `onclick` handlers needed migration (all event wiring is `addEventListener` based). `team-checkin.html` does not use Supabase and was untouched.
  9. **Dead JS files removed.** `js/auth.js` and `js/supabase.js` deleted (referenced by no HTML); now only `js/active-session.js` remains.
  10. **Aggregated team check-in results re-introduced.** Both `run-annual-session.html` and `run-quarterly-session.html` now show, below the Copy Link / Open Form buttons: "{N} team responses received" (or "No responses yet"), and when N>0 a compact table — one row per question (truncated to ~80 chars) with average score + red/amber/green dot (red < 3, amber 3–3.9, green ≥ 4), sorted lowest-average first — plus a "Show individual comments" expander grouping comments by question with the submitter's name. The 17 EOS-style `CHECKIN_QUESTIONS` array is duplicated into both run-session files so the questions can be displayed (Supabase migration will make this a server-side constant).
- Version bump: 0.5.75 → 0.5.76. `CACHE_VERSION` in `sw.js` bumped to `coach4u-v0.5.76`. `CLAUDE.md` "Pre-migration cleanup required" subsection removed from the Planned Architecture block (those items are done).

## v0.5.75
- **Documented the planned Supabase team architecture in CLAUDE.md.** Locked-in decisions:
  - **2-tier roles**: Admin (manages seats, edits all data, sends invites) vs. Member (reads team data, fills check-ins only).
  - **Subscription model**: a business buys N seats; first buyer is Admin; Admin allocates seats by email invite.
  - **Team-scoped data**: every data table scoped by `organisation_id`; all team members see ONE shared dataset (One-Page Plan, sessions, scorecard, etc.). Replaces the per-user assumption baked into today's localStorage.
  - **Check-in flow**: Admin schedules session → emails invite link to members → members log in + submit → aggregated results visible to **everyone on the team** (max-transparency model) for setting planning priorities. This reverses the v0.5.73 simplification (which stripped the aggregated results because the form was thought to be public; now that it's authenticated + team-scoped, the aggregation comes back).
- Captured the pre-migration cleanup checklist from the v0.5.74 audit (10 items) into CLAUDE.md so it's not lost.
- Docs-only change — no code touched.

## v0.5.74
- **Restructured project docs.** Moved full version history out of `CLAUDE.md` into `CHANGELOG.md` (this file). CLAUDE.md is now lean project memory + conventions + planned architecture; this file is the version log.
- Tightened `CLAUDE.md` Key Rules: added canonical sign-out ID (`signOutBtn` + class `sign-out-btn`), 300ms debounce convention for auto-save text inputs, explicit no-Google-Fonts rule, and a Supabase key-exposure note (anon key is intentionally publishable; security via RLS; never commit `service_role`).
- Listed all 4 version-sync targets explicitly (CLAUDE.md / VERSION / sw.js / index.html footer label).
- Clarified the team-checkin question count: 17 rated statements + 1 required name field + 1 optional role field (was reported as "17 questions" / "18 questions" depending on whether the name field was counted).
- Documented that the repo is intentionally public (GitHub Pages) and the Supabase anon key in the file is the `sb_publishable_*` variant.

## v0.5.73
- **Planning session workspaces simplified to attendance + checklist + share link.** Both `run-annual-session.html` and `run-quarterly-session.html` previously had a multi-step agenda accordion with per-step notes textareas, a 1–10 session-rating step, a "Review Team Check-in" agenda step, and a big inline aggregated check-in results table at the top. Stripped all of that.
- New workspace shape (both files): **status dropdown + timer**, then a **📋 Attendance** block (single textarea, debounced ~300ms auto-save), then **✅ Areas to Cover** (one checkbox per area with the existing Strategy/Goals deep-links inline beside each row + a "{n} of {total} areas completed" progress hint), then a **🌟 Team Check-in** block reduced to two buttons — **Copy Check-in Link** (teal, clipboard + toast) and **Open Form** (secondary). No count, no aggregated table, no comments view.
- **Annual** workspace has 4 areas: Review Last Year / Refresh Core Values + Core Focus / Update 10-Year + 3-Year Picture / Set 1-Year Plan + Q1 Goals. **Quarterly** has 3 areas: Review Last Quarter / Lessons + Adjustments / Set Next Quarter's Goals.
- **Persistence** — two new fields on each session object: `attendance: '<string>'` and `areas_completed: { [areaId]: boolean }`. Attendance saves debounced on input; checkboxes save immediately.
- Removed CSS / JS: `.rating-btns`, `.rating-btn`, `.notes-textarea`, `.ci-table`, `.ci-dot*`, `.ci-comments`, `.ci-q`, `.ci-c`, `.checkin-empty`, `.label-sm`, `.agenda-*` rules; `loadCheckins`, `aggregate`, `renderCheckinResultsTable`, `renderCheckinComments`, `updateAgendaNotes`, `buildAgendaSteps`, `priorQuarter` helpers.

## v0.5.72
- **Team Check-in form added.** A new public, auth-free page `team-checkin.html` lets team members rate organisational health statements (EOS-style) before each Annual or Quarterly planning session. The leader copies a per-session link (`team-checkin.html?session=<id>&type=annual|quarterly`) from the session workspace and shares it.
- **Form structure**: required name field + optional role field + **17 rated statements** (1–5 Likert, 1 = Strongly Disagree, 5 = Strongly Agree) + optional comment per question.
- **17 statements** cover vision, core focus, 10-year + 3-year targets, accountability chart, "right seat", leadership trust, issue solving, weekly meetings, quarterly priorities, annual meetings, core values hiring/firing, "right people", mentoring/coaching, strengths-based culture, and thriving culture.
- **Database-ready JSON**. Submissions write to localStorage under `coach4u_team_checkins` as `{ id, session_id, session_type, name, role, submitted_at, scores: number[17], comments: string[17] }` — same shape that will post to a future Supabase `team_checkins` table.
- **Workspace aggregation** added in v0.5.72 but later removed in v0.5.73 in favour of the slim share-link block.

## v0.5.71
- **Floating Resume Planning Session pill.** When you tap Start Session on an Annual or Quarterly Planning workspace, a teal pill appears bottom-center on every page in the app. Tap it to return to the in-progress session. Clears automatically when you mark the session completed or click End Session.
- Implemented as a shared `js/active-session.js` loaded via `<script defer>` on every main page (21 pages).
- Exposes `window.activeSession.set()` / `clear()` used by the two `run-*-session.html` workspaces. localStorage key: `coach4u_active_planning_session`.

## v0.5.70
- **`planning.html` restructured as a standard hub** to match the Strategy and Operations layout. Dropped the vertical flow visualisation; replaced with the same `activity-card` pattern.
- Top: "View One-Page Plan" teal CTA. Below: 2 activity cards — Annual Planning → `annual-sessions.html`, Quarterly Planning → `quarterly-sessions.html`.

## v0.5.69
- **Planning is now actionable, not just a diagram.** 4 new pages built on the same pattern as `meeting.html` + `run-meeting.html`:
  - `annual-sessions.html` — list of past + scheduled annual planning sessions
  - `run-annual-session.html` — single-session workspace (originally 5-step agenda; simplified in v0.5.73)
  - `quarterly-sessions.html` — list of past + scheduled quarterly sessions; "+ New" modal asks which quarter
  - `run-quarterly-session.html` — single-session workspace (originally 4-step agenda; simplified in v0.5.73)
- localStorage keys: `coach4u_annual_sessions` (array), `coach4u_quarterly_sessions` (array). No nested wrapper.
- Seed data: annual list seeds 1 completed + 1 scheduled. Quarterly list seeds 2 completed + 1 scheduled.
- `planning.html` cards repointed; `index.html` `ensureSeeds()` extended.

## v0.5.68
- **Planning page collapsed from 5 sessions to 4.** The "Q1 Review" was redundant — the Annual Planning session already produces the Q1 plan.
- New flow: Annual Planning (sets year + Q1) → Q2 Planning Session → Q3 Planning Session → Q4 Planning Session → cycles back.

## v0.5.67
- **Leadership Team moved INTO the One-Page Plan body** so the plan fits on a single A4 landscape page when printed. Lives as a compact field at the bottom of the "Who We Are" column. Empty placeholder rows filtered out.

## v0.5.66
Final polish on `planning.html`:
- Fixed sign-out button class regression. Bottom nav font aligned with other pages.
- Subtitle tightened; stage labels simplified; Annual node balanced with a "Reviews" row; "Start Here" chip added; "View One-Page Plan" CTA at top.

## v0.5.65
Audit fixes for consistency across all pages:
- Hub titles simplified — `strategy.html` "Build Your Strategy" → "Strategy", `operations.html` "Run Your Operations" → "Operations".
- Goals header-title → "Quarterly Goals".
- **Sign-out button id standardised to `signOutBtn` across all 17 pages.** (Some used `sign-out-btn` kebab-case.)
- Google Fonts purged from `offline.html`, `404.html`, `inactive.html`, `forgot-password.html`.
- "Next Meeting" stat tile on the dashboard now opens `run-meeting.html?id=X` directly.

## v0.5.64
- **Consistent hint box across all 9 worksheets/tools.** Every Strategy worksheet and Operations tool now has the same pattern: subtitle + one minimal `.ws-hint` with a single Learning Vault link.
- `.ws-hint` promoted to shared `css/style.css`.

## v0.5.63
- **Text-clipping audit on worksheets.** Added `autoGrow(textarea)` helper to resize each textarea to its `scrollHeight`.
- Marketing Strategy "Our Guarantee" field converted from `<input>` to `<textarea rows="2">`.

## v0.5.62
- **Robust seed merging.** `loadData()` and dashboard `seedIfEmpty()` now use a **merge-missing-keys** strategy: any SEED key that's `undefined` in the stored object gets filled in (intentional empty strings are preserved).
- Core Values worksheet now lists 8 values (was 5); seed still fills 1–5.

## v0.5.61
- **Dashboard panels are now fully live.** Every clickable tile and panel on `index.html` reads from localStorage instead of hardcoded sample text (Open Issues, Goals On Track, Next Meeting, 1-Year Goal, Core Values, This Week todos, This Quarter rocks).
- Pre-seed on first visit via `ensureSeeds()` — writes seeded defaults to all localStorage keys ONLY if missing.

## v0.5.60
- **Strategy worksheets now persist edits and seed dummy data.** All 4 Strategy worksheets auto-save every field edit to localStorage and seed realistic example content on first visit.
  - Keys: `coach4u_core_values`, `coach4u_core_focus`, `coach4u_targets`, `coach4u_marketing_strategy` (plus existing `coach4u_leadership_team`).
- **`one-page-plan.html` now reflects worksheet edits.** Each field on the printable plan got a stable `id`; `applyWorksheetData()` reads the localStorage keys and overrides hardcoded HTML where data exists.

---

## Earlier History (v0.5.9 – v0.5.59) — Summary
Pre-v0.5.60 milestones, compressed:
- **v0.5.59** — Issues simplified (priority removed); "Run Weekly Meeting" CTA creates this-week's meeting; Goals tip box; Scorecard renamed to "Weekly Numbers".
- **v0.5.58** — PWA icon fixed (4U now visible in teal); hub top gap tightened; Dashboard "Go to This Week's Meeting" opens `run-meeting.html?id=X` directly.
- **v0.5.55–v0.5.57** — Issues kanban → 2 columns; Scorecard mobile sticky-column; Hub CTAs moved to top; Dashboard links all repointed to actual tools.
- **v0.5.54** — Meeting split into past-list (`meeting.html`) + active workspace (`run-meeting.html`).
- **v0.5.51** — Strategy worksheets + Operations tools promoted out of `learn/` to project root. `learn/` reduced to reference area (Values Discovery only).
- **v0.5.50** — Operations tools (scorecard/goals/meeting/issues) given localStorage demo data stub in place of dead `/api/...` calls.
- **v0.5.41–v0.5.49** — Multiple structure passes consolidating to Design 1 (Aptos, navy + teal). Deleted legacy `business/`, `css/activity.css`, root orphans (`values.html`, `vision-strategy.html`, `marketing.html`, `targeting.html`). Login gold-standardised.
- **v0.5.33–v0.5.40** — Dashboard placeholder sections built; Strategy + One-Page Plan landscape layout introduced; Learning Vault + Values Discovery exercise added; consolidated to single Supabase project.
- **v0.5.9–v0.5.12** — Root portal restored as primary; legacy modules (Accountability Chart, Team Alignment) moved out to `yourteamcoach`.

---

## Ancient History (v0.5.1 – v0.5.4) — predecessor era

These entries describe an earlier project structure (`business/`, `growth/`, `thrivehq/` paths) that no longer exists. Kept for record only.

### v0.5.4 — 2026-04-29 — Design system alignment (v1.3)
- Updated brand colours across all pages: primary navy `#1B3664`, blue-teal `#5684C4` (later replaced by Design 1 navy `#003366` + teal `#0D9488`)
- Added Inter Bold and Montserrat Regular (Google Fonts) to all pages (later removed)
- Inlined module CSS; inlined Supabase client; standardised login form IDs
- Bumped service worker cache version to `coach4u-v0.5.3`

### v0.5.3
- Built complete ThriveHQ external PWA app (Phase 1) under `/thrivehq/` (later removed)

### v0.5.2
- Standardised typography to 7 size steps

### v0.5.1
- Fixed `business/index.html` loading wrong `app.js`; nav pill restyling; header redesign
