# CLI output

Load this reference only when the user needs machine-readable output
details, SARIF integration, or the exact per-command JSON envelope.

## Output modes

- **Text** (default) — human-readable, OSC 8 hyperlinks on
  `file:line:col` anchors so editors in the integrated terminal
  jump to source on click. Paths render relative to cwd.
- **`--json`** — stable `CliEnvelope<TData>` envelope, frozen at
  `schemaVersion: 1` through v3 GA. Use this whenever you need to
  reason about the output programmatically (CI gates, agent loops,
  diffing two runs). The envelope is the same shape for every command;
  only `data` and the diagnostic kinds change.

```ts
// src/cli/output/types.ts — public contract
interface CliEnvelope<TData> {
  schemaVersion: 1;
  command: string; // "check" | "analyze" | "model" | "diff" | …
  ok: boolean; // exitCode === 0
  exitCode: 0 | 1 | 2; // 0 clean, 1 violations, 2 tool error
  data: TData;
  diagnostics: readonly Diagnostic[];
  meta: {
    aactVersion: string;
    durationMs: number;
    configPath: string | null;
    source: string | null;
  };
}
```

## Per-command data

- `aact check` → `CheckData` — `violations[]` (each with `rule`,
  `target`, `targetKind`, `message`, `severity`, optional
  `sourceLocation` + `relatedLocations[]`), `suggestedFixes[]`,
  `summary`, `rules[]`, optional `fixesApplied` when `--fix` was used.
- `aact analyze` → `AnalyzeData` — `elementsByKind`,
  `relationsByStyle`, per-boundary cohesion/coupling numbers,
  `couplingRelations[]`, `fanIn`, `fanOut`, and cycles.
- `aact model` → `ModelData` — the full normalised graph (`elements`,
  `boundaries`, `rootBoundaryNames`, optional `workspace`) plus loader
  `issues[]`.
- `aact diff` → `DiffData` — `summary`, sorted structural `changes[]`,
  baseline/current provenance, optional RFC 6902 `patch`.
- `aact rule list` → `RuleListData` — built-in and custom rules with
  `source`, `enabled`, `hasFix`, and optional `helpUri`.
- `aact rule explain <name>` → `RuleExplainData` — metadata plus
  rationale, examples, and ADR path.
- `aact generate` → `GenerateData` — `formatName`, `outputSink`,
  `outputPath`, and generated files with sizes.
- `aact init` → `InitData` — created / skipped file paths.
- `aact skill install` → `SkillData` — install plans per target with
  action and final skill directory.

Exit codes are part of the contract: `0` clean, `1` domain-unhappy
(violations exist, structural diff has changes in strict mode), `2`
tool error (config invalid, source missing, parse failed). Agents must
branch on these; do not collapse them.

## SARIF and annotations

- `--sarif` on `check` / `model` emits SARIF v2.1.0 with the canonical
  `$schema` URL and `tool.driver.name: "aact"`.
- GitHub Actions annotations on `check` auto-enable when
  `GITHUB_ACTIONS=true` is set. The `::error file=...,line=...,col=...`
  lines anchor to the violation's `sourceLocation`, so the runner can
  surface them as inline PR comments.
