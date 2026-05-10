#!/usr/bin/env bash
# Thin wrapper around `npx aact check` with helpful messages when prerequisites
# are missing. Forwards extra flags to `aact check` so callers can use --fix,
# --dry-run, --format, --config, etc.
#
# Usage:
#   bash scripts/verify.sh              # plain check
#   bash scripts/verify.sh --fix        # apply auto-fixes
#   bash scripts/verify.sh --dry-run    # preview fixes without writing
#   bash scripts/verify.sh --help       # show this help
#
# Exit codes:
#   0 — no violations (or fixes applied successfully)
#   1 — violations remain, or aact reported an error
#   2 — pre-flight failure (missing config, npx not installed)

set -u

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

if [ ! -f aact.config.ts ] && [ ! -f aact.config.js ] && [ ! -f aact.config.mjs ]; then
  echo "Error: aact.config.ts not found in $(pwd)." >&2
  echo "Run \`npx aact init\` first — it scaffolds aact.config.ts plus a starter architecture.puml." >&2
  exit 2
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "Error: npx not found. Install Node.js >= 20: https://nodejs.org" >&2
  exit 2
fi

# Pin to a known-good aact major+minor. Patch updates are picked up
# automatically; major bumps are not, since they may rename rules or
# change the auto-fix surface that this skill's instructions assume.
exec npx aact@^2.1.5 check "$@"
