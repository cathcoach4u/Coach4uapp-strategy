---
name: version-bump
description: Bump the project version. Use BEFORE pushing any change to main. Updates the 7 files that must stay in sync and prepends a CHANGELOG entry.
---

# Version bump (the 7-file dance)

Every change to this repo bumps the patch number (`0.5.x`). Seven files must
stay in sync, or the visible footer drifts and users see a stale version
number on whichever page was missed.

## Files (in update order)

1. `VERSION` — just the number, e.g. `0.5.220`
2. `sw.js` — `CACHE_VERSION = 'coach4u-vX.Y.Z'`
3. `business.html` — footer `<p>vX.Y.Z</p>`
4. `index.html` — footer `<p>vX.Y.Z</p>`
5. `account-users.html` — footer `<p>vX.Y.Z</p>`
6. `account-setup.html` — footer `<p>vX.Y.Z</p>`
7. `CLAUDE.md` — `## Current Version` line
8. `CHANGELOG.md` — prepend a new entry; duplicate the most recent 1–2
   entries under `## Latest` in `CLAUDE.md` as a pointer.

(That's 7 files in sync + CHANGELOG.md as the historical record.)

## Procedure

1. Read `VERSION` to get the current number. Compute next patch.
2. Edit each of the 7 files with the new number.
3. Prepend a new `## vX.Y.Z` block to `CHANGELOG.md` describing the change.
4. Update `## Latest` in `CLAUDE.md` to point at the new entry (keep the
   previous one as the second bullet so context survives compaction).
5. Stage + commit + push directly to `main`. The commit message is the
   one-line summary of what changed — no version number prefix needed
   since the diff carries it.

## Gotchas

- **Don't edit just the footer of one page** and assume the rest will
  follow. The skill's whole reason for existing is that the user reported
  drift twice (v0.5.143 and v0.5.158).
- **CACHE_VERSION in sw.js must change** or the service worker keeps
  serving stale HTML. Bumping it is what triggers the new cache fetch
  on the next page load.
- **Never skip the CHANGELOG entry**. The Latest pointer in CLAUDE.md
  is what survives context compaction; without it, the next session has
  no idea what just shipped.
