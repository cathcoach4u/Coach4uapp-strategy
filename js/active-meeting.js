/* Active Weekly Meeting — floating, pulsing green pill (v0.5.207).
   When a weekly meeting is in progress, run-meeting.html writes to
   localStorage `coach4u_active_meeting`. This script runs on every
   business-level page and renders a fixed, gently-flashing pill at the
   bottom of the screen that links back to the meeting workspace.

   Auto-clears + hides itself when the underlying meeting is marked
   completed (or when the user clicks Delete on meeting.html).

   Companion to active-session.js (planning sessions) — same pattern,
   slightly higher z-index so it sits above the session pill if both
   happen to be active simultaneously. */
(function () {
  'use strict';
  const KEY = 'coach4u_active_meeting';
  const STYLE_ID = 'activeMeetingStyle';
  const PILL_ID = 'activeMeetingPill';

  function read() {
    try { return JSON.parse(localStorage.getItem(KEY) || 'null'); } catch (_) { return null; }
  }
  function write(data) {
    try { localStorage.setItem(KEY, JSON.stringify(data)); } catch (_) {}
  }
  function clearKey() {
    try { localStorage.removeItem(KEY); } catch (_) {}
  }

  function isStillActive(data) {
    return !!(data && data.id);
  }

  // Hide the pill when the active org changes — the meeting was for a
  // different business; following its link would be confusing.
  function matchesActiveOrg(data) {
    if (!data || !data.org_id) return true;  // legacy / unscoped, allow
    let activeOrgId = null;
    try {
      activeOrgId = localStorage.getItem('coach4u_active_org_id');
    } catch (_) {}
    if (!activeOrgId) return true;  // can't compare, allow
    return String(activeOrgId) === String(data.org_id);
  }

  function injectStyle() {
    if (document.getElementById(STYLE_ID)) return;
    const style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = `
      .active-meeting-pill {
        position: fixed;
        bottom: calc(120px + env(safe-area-inset-bottom));
        left: 50%;
        transform: translateX(-50%);
        /* v0.5.211 — bumped above modal overlays (z-index 1000) and toasts
           (z-index 2000) so the pill stays visible on edit pages that open
           a modal (issues, goals, scorecard cell-popovers, etc.). */
        z-index: 2100;
        background: #16a34a;
        color: white !important;
        padding: 10px 18px;
        border-radius: 999px;
        font-family: inherit;
        font-size: 0.82rem;
        font-weight: 700;
        text-decoration: none !important;
        display: flex;
        align-items: center;
        gap: 8px;
        white-space: nowrap;
        max-width: calc(100vw - 32px);
        box-shadow: 0 4px 14px rgba(22,163,74,0.45);
        animation: ampPulse 1.4s ease-in-out infinite, ampIn 0.25s ease-out;
      }
      .active-meeting-pill:hover {
        animation: none;
        box-shadow: 0 4px 22px rgba(22,163,74,0.75);
        transform: translateX(-50%) translateY(-1px);
      }
      .active-meeting-pill .amp-dot {
        width: 9px; height: 9px; border-radius: 50%;
        background: #4ade80;
        box-shadow: 0 0 0 0 rgba(74,222,128,0.85);
        animation: ampDot 1.4s ease-in-out infinite;
        flex-shrink: 0;
      }
      .active-meeting-pill .amp-icon { font-size: 1rem; line-height: 1; }
      .active-meeting-pill .amp-arrow { font-size: 0.9rem; opacity: 0.9; }
      @keyframes ampPulse {
        0%, 100% { box-shadow: 0 4px 14px rgba(22,163,74,0.45); }
        50%      { box-shadow: 0 4px 22px rgba(22,163,74,0.85), 0 0 0 6px rgba(22,163,74,0.18); }
      }
      @keyframes ampDot {
        0%, 100% { box-shadow: 0 0 0 0 rgba(74,222,128,0.85); }
        50%      { box-shadow: 0 0 0 7px rgba(74,222,128,0); }
      }
      @keyframes ampIn {
        from { opacity: 0; transform: translateX(-50%) translateY(8px); }
        to   { opacity: 1; transform: translateX(-50%) translateY(0); }
      }
    `;
    document.head.appendChild(style);
  }

  // v0.5.213 — Defensive auto-set: if we're on run-meeting.html?id=X and
  // localStorage doesn't have an entry for this meeting (e.g. run-meeting.html's
  // JS hasn't fired yet, or the user just opened the URL directly), seed it
  // from the URL params so the pill is set the moment they navigate elsewhere.
  function autoSetFromMeetingPage() {
    const path = window.location.pathname;
    if (!path.endsWith('run-meeting.html')) return;
    const params = new URLSearchParams(window.location.search);
    const id = params.get('id');
    if (!id) return;
    const existing = read();
    if (existing && existing.id === id) return;  // already set
    let orgId = null;
    try { orgId = localStorage.getItem('coach4u_active_org_id'); } catch (_) {}
    write({ id, label: '', org_id: orgId || null, started_at: new Date().toISOString() });
  }

  function render() {
    // Always remove the existing pill before re-rendering
    const existing = document.getElementById(PILL_ID);
    if (existing) existing.remove();

    autoSetFromMeetingPage();

    const data = read();
    if (!isStillActive(data)) {
      if (data) clearKey();
      return;
    }
    if (!matchesActiveOrg(data)) return;

    // Don't render the pill if we're already on the matching meeting workspace
    const path = window.location.pathname;
    const search = window.location.search || '';
    if (path.endsWith('run-meeting.html') && search.indexOf('id=' + data.id) !== -1) return;

    const url = 'run-meeting.html?id=' + encodeURIComponent(data.id);
    const href = path.indexOf('/learn/') !== -1 ? '../' + url : url;
    const label = data.label || 'this week\'s meeting';

    const a = document.createElement('a');
    a.id = PILL_ID;
    a.className = 'active-meeting-pill';
    a.href = href;
    a.setAttribute('aria-label', 'Return to ' + label);
    a.innerHTML =
      '<span class="amp-dot" aria-hidden="true"></span>' +
      '<span class="amp-icon" aria-hidden="true">🗓️</span>' +
      '<span class="amp-label">Meeting in progress &mdash; ' + escapeText(label) + '</span>' +
      '<span class="amp-arrow" aria-hidden="true">→</span>';
    document.body.appendChild(a);
  }

  function escapeText(s) {
    const d = document.createElement('div');
    d.textContent = String(s == null ? '' : s);
    return d.innerHTML;
  }

  function init() {
    injectStyle();
    render();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // Cross-tab updates
  window.addEventListener('storage', (e) => {
    if (e.key === KEY || e.key === 'coach4u_active_org_id') render();
  });

  // Public API used by run-meeting.html
  window.activeMeeting = {
    set(id, label, orgId) {
      write({ id, label: label || '', org_id: orgId || null, started_at: new Date().toISOString() });
      render();
    },
    clear() {
      clearKey();
      render();
    }
  };
})();
