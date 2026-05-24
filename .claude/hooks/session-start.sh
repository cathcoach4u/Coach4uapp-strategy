#!/bin/bash
# SessionStart hook: print the current version + the last 2 CHANGELOG entries
# so a fresh Claude session knows exactly where production stands.

set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

VERSION=$(cat "$ROOT/VERSION" 2>/dev/null || echo "(no VERSION file)")
echo "📦 Current version: v$VERSION"
echo ""

if [ -f "$ROOT/CHANGELOG.md" ]; then
  echo "📋 Last 2 entries in CHANGELOG.md:"
  echo ""
  awk '
    /^## v[0-9]/ {
      count++
      if (count > 2) exit
    }
    count >= 1 && count <= 2 { print }
  ' "$ROOT/CHANGELOG.md" | head -60
fi
