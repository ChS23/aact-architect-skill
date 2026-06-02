# Acceptance Workflow

Use `evals/evals.json` for trigger-rate tuning and `evals/acceptance.json`
for output-quality behavior after the skill has triggered.

## Fast Gate

Run this after ordinary edits:

```bash
bash scripts/acceptance-static.sh
```

This checks JSON fixtures, key instruction invariants, the verify wrapper,
and that the bundled PlantUML stub passes `npx --yes aact@beta check`.

## Live Smoke Gate

Run nested-agent smoke tests only for behavior changes to `SKILL.md`.
UC1 is intentionally expensive because it validates the empty-project guided
bootstrap path end to end.

Suggested minimal smoke set:

- `uc1-empty-guided-bootstrap` — empty project creates `aact.config.ts`,
  edits `architecture.puml`, uses API Gateway as relation technology, and
  runs or attempts `aact check`.
- `uc3-existing-project-review` — existing project is reviewed without
  rerunning `init` or applying `--fix`.
- `uc5-explain-only-no-bootstrap` — conceptual answers do not create files.

Use a disposable directory and full permissions for the inner agent, for
example:

```bash
codex exec --dangerously-bypass-approvals-and-sandbox \
  --ephemeral \
  --skip-git-repo-check \
  "<prompt from evals/acceptance.json>"
```

## Release Gate

Before a release, run all cases in `evals/acceptance.json` and keep notes on
pass/fail, commands issued, files created, and whether the final response met
the `must` / `must_not` clauses. See `acceptance-run-2026-06-02.md` for the
current baseline run notes.
