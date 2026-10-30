#!/usr/bin/env bash
# Fails if any guide is not cleared, or if the shipped pack differs from the Markdown in Guides/.
# Run before every App Store build.
set -euo pipefail
cd "$(dirname "$0")/.."

bad=$(grep -L '^clearance: cleared$' Guides/*.md || true)
if [[ -n "$bad" ]]; then
  echo "Guides not cleared for release:" >&2
  echo "$bad" | sed 's/^/  /' >&2
  echo "See docs/CONTENT_SOURCES.md for what clearing a guide means." >&2
  exit 1
fi

PACK=Packages/ReadyCore/Sources/ReadyCore/Resources/core.sqlite
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
python3 -I scripts/build-pack.py Guides "$TMP/core.sqlite" >/dev/null
dump() { sqlite3 "$1" "SELECT * FROM guides ORDER BY id; SELECT guide_id, position, heading, body FROM sections ORDER BY guide_id, position;"; }
if ! diff -q <(dump "$PACK") <(dump "$TMP/core.sqlite") >/dev/null; then
  echo "The shipped pack does not match Guides/. Run: python3 -I scripts/build-pack.py" >&2
  exit 1
fi
echo "All guides cleared and the shipped pack matches them."
