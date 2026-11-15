#!/usr/bin/env bash
# Thin wrapper around `npx --yes aact@latest check` with helpful messages when prerequisites
# are missing. Forwards extra flags to `aact@latest check` so callers can use --fix,
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
  echo "Run \`npx --yes aact@latest init\` first — it scaffolds aact.config.ts plus a starter architecture.puml." >&2
  exit 2
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "Error: npx not found. Install Node.js >= 22: https://nodejs.org" >&2
  exit 2
fi

# Track the `latest` dist-tag (the stable v3 line): `@latest` makes npx
# re-resolve the tag instead of reusing an older cached aact.
exec npx --yes aact@latest check "$@"
