#!/usr/bin/env bash
# Sync the bundled ADRs and patterns catalog from upstream Byndyusoft/aact.
# Run this whenever upstream adds or updates an ADR or pattern, so the skill's
# references/ stays current.
#
# Usage:
#   bash scripts/sync-from-aact.sh                 # sync from main branch
#   bash scripts/sync-from-aact.sh <ref>           # sync from a specific tag/branch/sha
#   bash scripts/sync-from-aact.sh --help
#
# Exit codes:
#   0 — sync succeeded, references/ updated
#   1 — sync failed (network error, upstream not reachable, …)
#   2 — pre-flight failure (git not installed, wrong cwd)

set -eu

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

REF="${1:-main}"
UPSTREAM="https://github.com/Byndyusoft/aact.git"

# Resolve the skill root from the script location, so the script works
# regardless of cwd.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(dirname "$SCRIPT_DIR")"
REFS_DIR="$SKILL_ROOT/references"

if [ ! -d "$REFS_DIR" ]; then
  echo "Error: references/ not found at $REFS_DIR." >&2
  echo "Are you running this from a corrupt skill checkout?" >&2
  exit 2
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git not found. Install git first." >&2
  exit 2
fi

TMP_DIR="$(mktemp -d -t aact-sync.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Cloning $UPSTREAM at $REF into $TMP_DIR ..."
git clone --depth 1 --branch "$REF" "$UPSTREAM" "$TMP_DIR" 2>&1 | tail -2

echo ""
echo "Updating references/ ..."
# Copy every ADR (verbatim filenames, including spaces).
for adr in "$TMP_DIR/ADRs/"*.md; do
  base="$(basename "$adr")"
  case "$base" in
    "ADR template.md")
      cp "$adr" "$REFS_DIR/adr-template.md"
      echo "  ↻ adr-template.md (renamed from \"ADR template.md\")"
      ;;
    *)
      cp "$adr" "$REFS_DIR/$base"
      echo "  ↻ $base"
      ;;
  esac
done

# Patterns catalog lives at repo root.
if [ -f "$TMP_DIR/patterns.md" ]; then
  cp "$TMP_DIR/patterns.md" "$REFS_DIR/patterns-catalog.md"
  echo "  ↻ patterns-catalog.md"
fi

echo ""
echo "Sync complete. Diff the references/ directory to review changes:"
echo "  git -C \"$SKILL_ROOT\" diff references/   # if the skill is in a git repo"
