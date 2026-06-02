# Acceptance Run 2026-06-02

Scope: manual nested-Codex smoke tests plus deterministic local gates for the
current `aact-architect` skill edits.

## Live Smoke Results

Command shape used for nested-agent runs:

```bash
codex exec --dangerously-bypass-approvals-and-sandbox \
  --ephemeral \
  --skip-git-repo-check \
  "<prompt>"
```

| Case | Status | Notes |
| --- | --- | --- |
| `uc1-empty-guided-bootstrap` | Pass | In an empty directory, the agent ran `npx --yes aact@beta init`, created `aact.config.ts` / `architecture.puml`, edited the model, ran `aact check`, and reached a clean check. This path is token-heavy, so keep it as a release smoke rather than a per-edit gate. |
| `uc2-empty-vibecoder-interview` | Pass | In an empty directory, the agent used guided bootstrap, created the aact files, wrote a plain-language Orders C4 draft, used `HTTPS via API Gateway` for external ACL calls, ran `aact check`, and asked for real system details as the next step. |
| `uc3-existing-project-review` | Pass | In an existing project with a deliberate CRUD violation, the agent used existing files, ran `npx --yes aact@beta check --json`, explained `crud` / `dbPerService`, and did not apply `--fix`. |
| `uc4-autofix-explicit-only` | Pass | In an existing project with the starter CRUD violation, the agent ran `npx --yes aact@beta check`, applied `npx --yes aact@beta check --fix`, showed the diff, cleaned stale comments, and re-ran `aact check` to a clean result. |
| `uc5-explain-only-no-bootstrap` | Pass | In an empty directory, the agent answered the conceptual CRUD / repo-service question without creating `aact.config.ts` or `architecture.puml`. |
| `uc6-adr-only` | Pass | In an empty directory, the agent stayed in ADR-only mode, did not run `init`, created `ADRs/Anti-corruption Layer before Legacy CRM.md`, included `Status`, `Context`, `Decision`, `Consequences`, and mapped enforcement to the `acl` rule. |
| `uc7-custom-rule-current-api` | Pass | After the ask-before-install change, the agent detected that local `aact` and `package.json` were missing, did not install anything, did not switch `aact.config.ts` to runtime imports, and asked for permission to run `npm i -D aact@beta` before adding/registering the custom rule. |
| `uc8-analyze-generate-cli` | Pass | In an existing project, the agent did not rerun `init`, ran `npx --yes aact@beta analyze --json`, generated Kubernetes scaffold with `npx --yes aact@beta generate --format kubernetes --output ./k8s`, inspected generated files, and stated that they are scaffold output, not production manifests. |
| `uc9-near-miss-no-trigger` | Pass | In an empty directory, the agent treated the prompt as ordinary Docker work, created only `Dockerfile` and `.dockerignore`, did not run `npx --yes aact@beta init`, and did not create architecture files. |

## Deterministic Gates

| Gate | Status | Notes |
| --- | --- | --- |
| `bash scripts/acceptance-static.sh` | Pass | Validated JSON fixtures, instruction invariants, verify wrapper, and bundled PlantUML stub against `aact@beta`. |
| `skills-ref validate` | Pass | Official agentskills validator reported `Valid skill`. |
| `git diff --check` | Pass | No whitespace errors. |

## Remaining Before Release

No acceptance cases remain unrun for this baseline. Before release, repeat
`uc1`, `uc3`, `uc5`, `uc7`, and `uc9` as a compact regression set because
they cover the highest-risk boundaries: empty-project bootstrap, existing
project safety, explanation-only behavior, custom-rule API drift, and
near-miss non-trigger behavior.
