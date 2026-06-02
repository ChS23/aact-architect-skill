#!/usr/bin/env bash
# Fast deterministic acceptance gate for the aact-architect skill.
# It complements live nested-agent smoke tests from evals/acceptance.json.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v node >/dev/null 2>&1; then
  echo "Error: node not found. Install Node.js >= 22." >&2
  exit 2
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "Error: npx not found. Install Node.js >= 22." >&2
  exit 2
fi

echo "== JSON fixtures =="
node <<'NODE'
const fs = require("node:fs");

JSON.parse(fs.readFileSync("evals/evals.json", "utf8"));
const acceptance = JSON.parse(fs.readFileSync("evals/acceptance.json", "utf8"));

const expected = [
  "uc1-empty-guided-bootstrap",
  "uc2-empty-vibecoder-interview",
  "uc3-existing-project-review",
  "uc4-autofix-explicit-only",
  "uc5-explain-only-no-bootstrap",
  "uc6-adr-only",
  "uc7-custom-rule-current-api",
  "uc8-analyze-generate-cli",
  "uc9-near-miss-no-trigger",
];

if (!Array.isArray(acceptance.cases)) {
  throw new Error("evals/acceptance.json must contain a cases[] array");
}

const ids = new Set(acceptance.cases.map((item) => item.id));
const missing = expected.filter((id) => !ids.has(id));

if (missing.length) {
  throw new Error(`missing acceptance cases: ${missing.join(", ")}`);
}

if (acceptance.cases.length < expected.length) {
  throw new Error("acceptance case count is lower than the expected baseline");
}

console.log(`ok: ${acceptance.cases.length} acceptance cases`);
NODE

echo "== Instruction invariants =="
node <<'NODE'
const fs = require("node:fs");

const files = [
  "SKILL.md",
  "README.md",
  "references/Target Architecture.md",
  "references/Writing custom rules.md",
  "references/CLI output.md",
  "scripts/verify.sh",
  "assets/architecture-stub.puml",
];

const text = Object.fromEntries(files.map((file) => [
  file,
  fs.readFileSync(file, "utf8"),
]));

const mustInclude = [
  ["SKILL.md", "## Fast path"],
  ["SKILL.md", "Guided bootstrap for empty projects"],
  ["SKILL.md", "Existing project mode"],
  ["SKILL.md", "Explanation-only / ADR-only mode"],
  ["SKILL.md", "npx --yes aact@beta init"],
  ["SKILL.md", "HTTPS via API Gateway"],
  ["SKILL.md", "ask before installing"],
  ["assets/architecture-stub.puml", "HTTPS via API Gateway"],
  ["references/Target Architecture.md", "readonly elements"],
  ["references/Target Architecture.md", "schemaVersion: 1"],
  ["scripts/verify.sh", "npx --yes aact@beta check"],
];

for (const [file, needle] of mustInclude) {
  if (!text[file].includes(needle)) {
    throw new Error(`${file} missing required text: ${needle}`);
  }
}

for (const [file, body] of Object.entries(text)) {
  if (/\bnpx aact@beta\b/.test(body)) {
    throw new Error(`${file} still uses interactive npx aact@beta`);
  }

  if (body.includes("Model.containers")) {
    throw new Error(`${file} still mentions stale Model.containers API`);
  }

  if (body.includes('schemaVersion: "aact.cli.v1"')) {
    throw new Error(`${file} still has stale CLI schemaVersion text`);
  }
}

console.log("ok: instruction invariants");
NODE

echo "== verify wrapper =="
bash scripts/verify.sh --help >/dev/null
echo "ok: verify help"

echo "== bundled PlantUML stub =="
TMPDIR="$(mktemp -d /tmp/aact-skill-static.XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

(
  cd "$TMPDIR"
  npx --yes aact@beta init >/dev/null
  cp "$ROOT/assets/architecture-stub.puml" architecture.puml

  set +e
  npx --yes aact@beta check --json > result.json
  CHECK_STATUS=$?
  set -e

  AACT_STATUS="$CHECK_STATUS" node <<'NODE'
const fs = require("node:fs");

const status = Number(process.env.AACT_STATUS);
const result = JSON.parse(fs.readFileSync("result.json", "utf8"));

if (status !== 0 || result.ok !== true) {
  const violations = result.data?.violations ?? result.error ?? result;
  throw new Error(JSON.stringify(violations, null, 2));
}

console.log(`ok: aact ${result.meta?.aactVersion ?? "unknown"} found no violations`);
NODE
)

echo "acceptance-static ok"
