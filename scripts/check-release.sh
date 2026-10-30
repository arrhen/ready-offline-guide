#!/usr/bin/env bash
# Fails unless this is safe to submit: the model cannot reach outside the app, and the guides bundled in
# the app are exactly the cleared ones. A build with no cleared guides passes: it is a files-only app.
#
# Before a release build run:  python3 -I scripts/build-pack.py --cleared-only
# (That rewrites the bundled pack. Restore it afterwards with: git checkout -- Packages/ReadyCore/Sources/ReadyCore/Resources)
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/check-containment.sh

PACK=Packages/ReadyCore/Sources/ReadyCore/Resources/core.sqlite
[[ -f "$PACK" ]] || { echo "No bundled pack at $PACK" >&2; exit 1; }

# 1. Nothing uncleared may be inside the app.
uncleared=$(sqlite3 "$PACK" "SELECT id FROM guides WHERE clearance != 'cleared';")
if [[ -n "$uncleared" ]]; then
  echo "The bundled pack contains guides that are not cleared:" >&2
  echo "$uncleared" | sed 's/^/  /' >&2
  echo "Run: python3 -I scripts/build-pack.py --cleared-only" >&2
  exit 1
fi

# 2. The bundled pack must match the cleared guides in Guides/, so what was reviewed is what ships.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
python3 -I scripts/build-pack.py --cleared-only Guides "$TMP/core.sqlite" >/dev/null
dump() { sqlite3 "$1" "SELECT * FROM guides ORDER BY id; SELECT guide_id, position, heading, body FROM sections ORDER BY guide_id, position;"; }
if ! diff -q <(dump "$PACK") <(dump "$TMP/core.sqlite") >/dev/null; then
  echo "The bundled pack does not match the cleared guides in Guides/. Run: python3 -I scripts/build-pack.py --cleared-only" >&2
  exit 1
fi

n=$(sqlite3 "$PACK" "SELECT COUNT(*) FROM guides;")
if [[ "$n" == "0" ]]; then
  echo "Release checks passed: no guides bundled (a files-only build)."
else
  echo "Release checks passed: $n cleared guide(s) bundled."
fi
